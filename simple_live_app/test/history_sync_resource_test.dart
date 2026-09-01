import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/resources/history_sync_resource.dart';

History history({
  required String duration,
  required int syncDuration,
  required DateTime updateTime,
}) {
  return History(
    id: 'huya_1',
    roomId: '1',
    siteId: 'huya',
    userName: '主播',
    face: '',
    updateTime: updateTime,
    watchDuration: duration,
    syncDuration: syncDuration,
  );
}

void main() {
  final resource = HistorySyncResource();

  test('远端首次缺失时折叠本地增量且不修改原对象', () {
    final local = history(
      duration: '0:00:30',
      syncDuration: 30,
      updateTime: DateTime(2026, 9, 2),
    );

    final prepared = resource.prepareInitialBidirectional([local]);

    expect(prepared.single.watchDuration, '0:00:30');
    expect(prepared.single.syncDuration, 0);
    expect(local.syncDuration, 30);
  });

  test('相同累计时长会清理残留增量而不会重复累加', () {
    final timestamp = DateTime(2026, 9, 2, 1);
    final local = history(
      duration: '0:01:40',
      syncDuration: 10,
      updateTime: timestamp,
    );
    final remote = history(
      duration: '0:01:40',
      syncDuration: 0,
      updateTime: timestamp,
    );

    final merged = resource.merge([local], [remote]);

    expect(merged.single.watchDuration, '0:01:40');
    expect(merged.single.syncDuration, 0);
  });

  test('远端基础时长只叠加一次本地未同步增量', () {
    final local = history(
      duration: '0:01:40',
      syncDuration: 10,
      updateTime: DateTime(2026, 9, 2, 2),
    );
    final remote = history(
      duration: '0:01:30',
      syncDuration: 0,
      updateTime: DateTime(2026, 9, 2, 1),
    );

    final first = resource.merge([local], [remote]);
    final second = resource.merge(first, first);

    expect(first.single.watchDuration, '0:01:40');
    expect(first.single.syncDuration, 0);
    expect(second.single.watchDuration, '0:01:40');
    expect(second.single.syncDuration, 0);
  });
}
