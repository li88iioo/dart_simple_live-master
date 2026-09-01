import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/services/history_service.dart';

class _FakeHistoryClock implements HistorySessionClock {
  Duration value = Duration.zero;
  bool running = false;

  void advance(Duration duration) {
    if (running) value += duration;
  }

  @override
  Duration get elapsed => value;

  @override
  void reset() => value = Duration.zero;

  @override
  void start() => running = true;

  @override
  void stop() => running = false;
}

History _history(
  String id, {
  String watchDuration = '00:00:00',
  int syncDuration = 0,
}) {
  return History(
    id: id,
    roomId: id,
    siteId: 'huya',
    userName: '主播$id',
    face: '',
    updateTime: DateTime(2026, 9, 2),
    watchDuration: watchDuration,
    syncDuration: syncDuration,
  );
}

void main() {
  test('stop waits for the final serialized history snapshot', () async {
    final clock = _FakeHistoryClock();
    final writes = <History>[];
    var activeWrites = 0;
    var maxActiveWrites = 0;
    final service = HistoryService(
      clock: clock,
      historyReader: (_) => _history(
        'room-a',
        watchDuration: '00:00:10',
        syncDuration: 7,
      ),
      historyWriter: (history) async {
        activeWrites++;
        maxActiveWrites =
            maxActiveWrites < activeWrites ? activeWrites : maxActiveWrites;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        writes.add(history.copyWith());
        activeWrites--;
      },
    );

    service.start(_history('room-a'));
    clock.advance(const Duration(seconds: 5));
    await service.stop(expectedRoomId: 'room-a');

    expect(maxActiveWrites, 1);
    expect(writes, hasLength(1));
    expect(writes.single.watchDuration, '0:00:15');
    expect(writes.single.syncDuration, 12);
    expect(service.curLiveRoomHistory, isNull);
  });

  test('switching rooms persists independent immutable snapshots', () async {
    final clock = _FakeHistoryClock();
    final writes = <History>[];
    final service = HistoryService(
      clock: clock,
      historyReader: (_) => null,
      historyWriter: (history) async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        writes.add(history.copyWith());
      },
    );

    service.start(_history('room-a'));
    clock.advance(const Duration(seconds: 3));
    service.start(_history('room-b'));
    clock.advance(const Duration(seconds: 2));
    await service.stop(expectedRoomId: 'room-b');

    final roomAFinal = writes.lastWhere((item) => item.id == 'room-a');
    final roomBFinal = writes.lastWhere((item) => item.id == 'room-b');
    expect(roomAFinal.watchDuration, '0:00:03');
    expect(roomAFinal.syncDuration, 3);
    expect(roomBFinal.watchDuration, '0:00:02');
    expect(roomBFinal.syncDuration, 2);
  });

  test('flush retries the latest cumulative snapshot after a write failure',
      () async {
    final clock = _FakeHistoryClock();
    final writes = <History>[];
    var attempts = 0;
    final service = HistoryService(
      clock: clock,
      historyReader: (_) => _history('room-a'),
      historyWriter: (history) async {
        attempts++;
        if (attempts == 1) throw StateError('disk temporarily unavailable');
        writes.add(history.copyWith());
      },
    );

    service.start(_history('room-a'));
    clock.advance(const Duration(seconds: 4));
    await service.stop(expectedRoomId: 'room-a');

    expect(attempts, 2);
    expect(writes.single.watchDuration, '0:00:04');
    expect(writes.single.syncDuration, 4);
  });
}
