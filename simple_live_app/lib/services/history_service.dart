import 'dart:async';

import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils/duration_2_str_utils.dart';
import 'package:simple_live_app/models/db/history.dart';

import 'db_service.dart';

typedef HistoryReader = History? Function(String id);
typedef HistoryWriter = Future<void> Function(History history);

abstract interface class HistorySessionClock {
  Duration get elapsed;

  void start();

  void stop();

  void reset();
}

class StopwatchHistorySessionClock implements HistorySessionClock {
  final Stopwatch _stopwatch = Stopwatch();

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  void reset() => _stopwatch.reset();

  @override
  void start() => _stopwatch.start();

  @override
  void stop() => _stopwatch.stop();
}

class HistoryService extends GetxService {
  HistoryService({
    Duration saveInterval = const Duration(minutes: 2),
    HistoryReader? historyReader,
    HistoryWriter? historyWriter,
    HistorySessionClock? clock,
  })  : _saveInterval = saveInterval,
        _historyReader = historyReader,
        _historyWriter = historyWriter,
        _clock = clock ?? StopwatchHistorySessionClock();

  static HistoryService get instance => Get.find<HistoryService>();

  final HistorySessionClock _clock;
  final Duration _saveInterval;
  final HistoryReader? _historyReader;
  final HistoryWriter? _historyWriter;

  Duration _oldWatchedDuration = Duration.zero;
  Duration _lastQueuedElapsed = Duration.zero;
  History? curLiveRoomHistory;
  Timer? _timer;

  Future<void> _writeQueue = Future<void>.value();
  History? _lastQueuedSnapshot;
  Object? _lastWriteError;
  StackTrace? _lastWriteStackTrace;

  History? _readHistory(String id) {
    final reader = _historyReader;
    return reader != null ? reader(id) : DBService.instance.getHistory(id);
  }

  Future<void> _writeHistory(History history) {
    final writer = _historyWriter;
    return writer != null
        ? writer(history)
        : DBService.instance.addOrUpdateHistory(history);
  }

  /// 开始或恢复当前房间计时。重复刷新同一房间时复用唯一会话和 Timer。
  void start(History history) {
    _timer?.cancel();

    if (curLiveRoomHistory?.id != history.id) {
      if (curLiveRoomHistory != null) {
        _clock.stop();
        _updateHistory();
      }
      _clock.reset();
      _lastQueuedElapsed = Duration.zero;
      _loadHistory(history);
    }

    _clock.start();
    _timer = Timer.periodic(_saveInterval, (_) => _updateHistory());
  }

  /// 切换房间时先提交旧房间数据，再等待新房间详情调用 [start]。
  Future<void> reset(String roomId) async {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    _updateHistory();
    _clearCurrentSession();
    await flushPending();
  }

  /// 停止计时并提交本次会话最后一段观看时长。
  Future<void> stop({String? expectedRoomId}) async {
    if (expectedRoomId != null && curLiveRoomHistory?.id != expectedRoomId) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    _updateHistory();
    final sessionElapsed = _clock.elapsed;
    _clearCurrentSession();
    await flushPending();
    Log.i("本次观看时长：$sessionElapsed");
  }

  void _clearCurrentSession() {
    _clock.reset();
    _oldWatchedDuration = Duration.zero;
    _lastQueuedElapsed = Duration.zero;
    curLiveRoomHistory = null;
  }

  void _loadHistory(History history) {
    final stored = _readHistory(history.id);
    curLiveRoomHistory = (stored ?? history).copyWith();
    if (stored == null) {
      _enqueueWrite(curLiveRoomHistory!.copyWith());
    }
    _oldWatchedDuration = curLiveRoomHistory!.duration;
  }

  void _updateHistory() {
    final history = curLiveRoomHistory;
    if (history == null) return;

    final elapsed = _clock.elapsed;
    final delta = elapsed - _lastQueuedElapsed;
    if (delta <= Duration.zero) return;

    final currentDuration = _oldWatchedDuration + elapsed;
    Log.i(
      "已观看时间：${_oldWatchedDuration.toHMSString()}_增加时间：${elapsed.toHMSString()}",
    );
    history.watchDuration = currentDuration.toHMSString();
    // 只累加上次排队保存后的增量。每个写任务持有独立快照，避免后续房间
    // 修改同一个 Hive 对象导致旧写入串房。
    history.syncDuration += delta.inSeconds;
    history.updateTime = DateTime.now();
    _lastQueuedElapsed = elapsed;
    _enqueueWrite(history.copyWith());
    EventBus.instance.emit(Constant.kUpdateFollow, history);
  }

  void _enqueueWrite(History snapshot) {
    _lastQueuedSnapshot = snapshot;
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _writeHistory(snapshot);
        if (identical(_lastQueuedSnapshot, snapshot)) {
          _lastWriteError = null;
          _lastWriteStackTrace = null;
        }
      } catch (error, stackTrace) {
        _lastWriteError = error;
        _lastWriteStackTrace = stackTrace;
        Log.e('保存观看历史失败：$error', stackTrace);
      }
    });
  }

  /// 等待所有历史写入完成。若最终快照写入失败，会同步重试一次并把错误
  /// 交给调用方，以便退出流程能够明确记录而不是静默丢失观看时长。
  Future<void> flushPending() async {
    await _writeQueue;
    final error = _lastWriteError;
    final snapshot = _lastQueuedSnapshot;
    if (error == null || snapshot == null) return;

    try {
      await _writeHistory(snapshot.copyWith());
      _lastWriteError = null;
      _lastWriteStackTrace = null;
    } catch (retryError, retryStackTrace) {
      Log.e('重试保存观看历史失败：$retryError', retryStackTrace);
      Error.throwWithStackTrace(
        retryError,
        retryStackTrace == StackTrace.empty
            ? (_lastWriteStackTrace ?? retryStackTrace)
            : retryStackTrace,
      );
    }
  }

  String getHistoryDuration({required String followUserId}) {
    var historyWatchDuration = "00:00:00";
    final history = _readHistory(followUserId);
    historyWatchDuration = history?.watchDuration ?? "00:00:00";
    return historyWatchDuration;
  }

  History? getHistory(String id) {
    return _readHistory(id);
  }

  Future<void> addOrUpdateHistory(History history) async {
    await _writeHistory(history);
  }

  Future<void> delHistory(String id) async {
    await DBService.instance.delHistory(id);
  }

  List<History> getHistories() {
    return DBService.instance.getHistories();
  }

  Future<void> historyClear() async {
    await DBService.instance.clearHistory();
  }

  @override
  void onClose() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    _updateHistory();
    unawaited(flushPending());
    super.onClose();
  }
}
