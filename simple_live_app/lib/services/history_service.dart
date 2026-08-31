import 'dart:async';

import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils/duration_2_str_utils.dart';
import 'package:simple_live_app/models/db/history.dart';

import 'db_service.dart';

class HistoryService extends GetxService {
  HistoryService({
    Duration saveInterval = const Duration(minutes: 2),
  }) : _saveInterval = saveInterval;

  static HistoryService get instance => Get.find<HistoryService>();

  final Stopwatch _stopwatch = Stopwatch();
  final Duration _saveInterval;
  Duration _elapsed = Duration.zero;
  Duration _oldWatchedDuration = Duration.zero;
  Duration _lastSavedElapsed = Duration.zero;
  History? curLiveRoomHistory;
  Timer? _timer;

  /// 开始或恢复当前房间计时。重复刷新同一房间时复用唯一会话和 Timer。
  void start(History history) {
    _timer?.cancel();

    if (curLiveRoomHistory?.id != history.id) {
      if (curLiveRoomHistory != null) {
        _stopwatch.stop();
        _updateHistory();
      }
      _stopwatch.reset();
      _lastSavedElapsed = Duration.zero;
      _loadHistory(history);
    }

    _stopwatch.start();
    _timer = Timer.periodic(_saveInterval, (_) => _updateHistory());
  }

  /// 切换房间时先提交旧房间数据，再等待新房间详情调用 [start]。
  void reset(String roomId) {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    _updateHistory();
    _stopwatch.reset();
    _elapsed = Duration.zero;
    _lastSavedElapsed = Duration.zero;
    curLiveRoomHistory = null;
  }

  /// 停止计时并提交本次会话最后一段观看时长。
  void stop({String? expectedRoomId}) {
    if (expectedRoomId != null && curLiveRoomHistory?.id != expectedRoomId) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    _updateHistory();
    final sessionElapsed = _stopwatch.elapsed;
    _stopwatch.reset();
    _elapsed = Duration.zero;
    _lastSavedElapsed = Duration.zero;
    curLiveRoomHistory = null;
    Log.i("本次观看时长：$sessionElapsed");
  }

  void _loadHistory(History history) {
    curLiveRoomHistory = DBService.instance.getHistory(history.id);
    if (curLiveRoomHistory == null) {
      curLiveRoomHistory = history;
      unawaited(DBService.instance.addOrUpdateHistory(history));
    }
    _oldWatchedDuration = curLiveRoomHistory!.duration;
  }

  void _updateHistory() {
    final history = curLiveRoomHistory;
    if (history == null) return;

    _elapsed = _stopwatch.elapsed;
    final delta = _elapsed - _lastSavedElapsed;
    if (delta <= Duration.zero) return;

    final currentDuration = _oldWatchedDuration + _elapsed;
    Log.i(
      "已观看时间：${_oldWatchedDuration.toHMSString()}_增加时间：${_elapsed.toHMSString()}",
    );
    history.watchDuration = currentDuration.toHMSString();
    // 只累加上次保存后的增量，避免周期保存把整段会话重复计入同步时长。
    history.syncDuration += delta.inSeconds;
    history.updateTime = DateTime.now();
    _lastSavedElapsed = _elapsed;
    unawaited(DBService.instance.addOrUpdateHistory(history));
    EventBus.instance.emit(Constant.kUpdateFollow, history);
  }

  String getHistoryDuration({required String followUserId}) {
    var historyWatchDuration = "00:00:00";
    History? history = DBService.instance.getHistory(followUserId);
    historyWatchDuration = history?.watchDuration ?? "00:00:00";
    return historyWatchDuration;
  }

  History? getHistory(String id) {
    return DBService.instance.getHistory(id);
  }

  Future<void> addOrUpdateHistory(History history) async {
    await DBService.instance.addOrUpdateHistory(history);
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
}
