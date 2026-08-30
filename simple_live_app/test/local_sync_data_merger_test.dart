import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/services/local_sync_data_merger.dart';

void main() {
  group('关注墓碑合并', () {
    test('较新的远端取消关注会覆盖本地旧关注', () {
      final current = _follow(
        id: 'huya_1',
        addTime: DateTime.utc(2026, 8, 30, 10),
      );
      final tombstone = _follow(
        id: 'huya_1',
        addTime: current.addTime,
        deleted: true,
        updateTime: DateTime.utc(2026, 8, 30, 11).millisecondsSinceEpoch,
      );

      final result = LocalSyncDataMerger.follows(
        existing: [current],
        incoming: [tombstone],
        overlay: false,
      );

      expect(result['huya_1']?.deleted, isTrue);
      expect(result['huya_1']?.updateTime, tombstone.updateTime);
    });

    test('本地重新关注时间晚于远端墓碑时不会被再次删除', () {
      final current = _follow(
        id: 'huya_1',
        addTime: DateTime.utc(2026, 8, 30, 12),
      );
      final staleTombstone = _follow(
        id: 'huya_1',
        addTime: DateTime.utc(2026, 8, 30, 9),
        deleted: true,
        updateTime: DateTime.utc(2026, 8, 30, 11).millisecondsSinceEpoch,
      );

      final result = LocalSyncDataMerger.follows(
        existing: [current],
        incoming: [staleTombstone],
        overlay: false,
      );

      expect(result['huya_1']?.deleted, isFalse);
      expect(result['huya_1']?.addTime, current.addTime);
    });

    test('远端重新关注时间晚于本地墓碑时会恢复关注', () {
      final tombstone = _follow(
        id: 'huya_1',
        addTime: DateTime.utc(2026, 8, 30, 9),
        deleted: true,
        updateTime: DateTime.utc(2026, 8, 30, 11).millisecondsSinceEpoch,
      );
      final refollow = _follow(
        id: 'huya_1',
        addTime: DateTime.utc(2026, 8, 30, 12),
      );

      final result = LocalSyncDataMerger.follows(
        existing: [tombstone],
        incoming: [refollow],
        overlay: false,
      );

      expect(result['huya_1']?.deleted, isFalse);
      expect(result['huya_1']?.addTime, refollow.addTime);
    });

    test('兼容旧版秒级墓碑并允许同秒内更晚的毫秒级重新关注', () {
      final legacyTombstone = _follow(
        id: 'huya_1',
        deleted: true,
        updateTime: 1788076800,
      );
      final refollow = _follow(
        id: 'huya_1',
        addTime: DateTime.fromMillisecondsSinceEpoch(1788076800500),
      );

      final result = LocalSyncDataMerger.follows(
        existing: [legacyTombstone],
        incoming: [refollow],
        overlay: false,
      );

      expect(result['huya_1']?.deleted, isFalse);
    });

    test('不覆盖模式保留同 ID 的本地正常关注元数据', () {
      final current = _follow(id: 'huya_1', remark: '本地备注');
      final incoming = _follow(id: 'huya_1', remark: '远端备注');

      final result = LocalSyncDataMerger.follows(
        existing: [current],
        incoming: [incoming],
        overlay: false,
      );

      expect(result['huya_1']?.remark, '本地备注');
    });

    test('覆盖模式只保留传入记录并包含墓碑', () {
      final result = LocalSyncDataMerger.follows(
        existing: [_follow(id: 'old')],
        incoming: [
          _follow(
            id: 'deleted',
            deleted: true,
            updateTime: DateTime.utc(2026, 8, 30).millisecondsSinceEpoch,
          ),
        ],
        overlay: true,
      );

      expect(result.keys, ['deleted']);
      expect(result['deleted']?.deleted, isTrue);
    });
  });

  test('历史记录非覆盖合并保留更新时间较新的版本', () {
    final existing = _history('huya_1', DateTime.utc(2026, 8, 30, 10));
    final stale = _history('huya_1', DateTime.utc(2026, 8, 30, 9));
    final fresh = _history('douyu_1', DateTime.utc(2026, 8, 30, 11));

    final result = LocalSyncDataMerger.histories(
      existing: [existing],
      incoming: [stale, fresh],
      overlay: false,
    );

    expect(result['huya_1']?.updateTime, existing.updateTime);
    expect(result['douyu_1']?.updateTime, fresh.updateTime);
  });

  test('标签在不覆盖模式保留同 ID 本地值，覆盖模式使用传入值', () {
    final oldTag = FollowUserTag(id: 'a', tag: '本地标签', userId: const []);
    final incomingSameId = FollowUserTag(
      id: 'a',
      tag: '远端标签',
      userId: const [],
    );
    final newTag = FollowUserTag(id: 'b', tag: '新标签', userId: const []);

    final mergedTags = LocalSyncDataMerger.tags(
      existing: [oldTag],
      incoming: [incomingSameId, newTag],
      overlay: false,
    );
    final overlaidTags = LocalSyncDataMerger.tags(
      existing: [oldTag],
      incoming: [incomingSameId, newTag],
      overlay: true,
    );

    expect(mergedTags['a']?.tag, '本地标签');
    expect(mergedTags.keys, containsAll(['a', 'b']));
    expect(overlaidTags['a']?.tag, '远端标签');
  });
}

FollowUser _follow({
  required String id,
  DateTime? addTime,
  bool deleted = false,
  int updateTime = 0,
  String remark = '',
}) {
  return FollowUser(
    id: id,
    roomId: id,
    siteId: 'huya',
    userName: id,
    face: '',
    addTime: addTime ?? DateTime.utc(2026, 8, 30, 8),
    deleted: deleted,
    updateTime: updateTime,
    remark: remark,
  );
}

History _history(String id, DateTime updateTime) {
  return History(
    id: id,
    roomId: id,
    siteId: 'huya',
    userName: id,
    face: '',
    updateTime: updateTime,
  );
}
