import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_sync_time.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';

class LocalSyncDataMerger {
  const LocalSyncDataMerger._();

  static Map<String, FollowUser> follows({
    required Iterable<FollowUser> existing,
    required Iterable<FollowUser> incoming,
    required bool overlay,
  }) {
    if (overlay) {
      return {for (final item in incoming) item.id: item};
    }

    final result = {for (final item in existing) item.id: item};
    for (final item in incoming) {
      final current = result[item.id];
      result[item.id] = current == null ? item : _mergeFollow(current, item);
    }
    return result;
  }

  static Map<String, FollowUserTag> tags({
    required Iterable<FollowUserTag> existing,
    required Iterable<FollowUserTag> incoming,
    required bool overlay,
  }) {
    final result = overlay
        ? <String, FollowUserTag>{}
        : {for (final item in existing) item.id: item};
    for (final item in incoming) {
      result.putIfAbsent(item.id, () => item);
    }
    return result;
  }

  static Map<String, History> histories({
    required Iterable<History> existing,
    required Iterable<History> incoming,
    required bool overlay,
  }) {
    final result = overlay
        ? <String, History>{}
        : {for (final item in existing) item.id: item};
    for (final item in incoming) {
      final current = result[item.id];
      if (current == null || !current.updateTime.isAfter(item.updateTime)) {
        result[item.id] = item;
      }
    }
    return result;
  }

  static FollowUser _mergeFollow(
    FollowUser current,
    FollowUser incoming,
  ) {
    if (current.deleted && incoming.deleted) {
      return incoming.deletionTimeMillis >= current.deletionTimeMillis
          ? incoming
          : current;
    }

    if (current.deleted) {
      return current.deletionTimeMillis >= incoming.followTimeMillis
          ? current
          : incoming;
    }

    if (incoming.deleted) {
      return incoming.deletionTimeMillis >= current.followTimeMillis
          ? incoming
          : current;
    }

    // “不覆盖”模式只补充缺失记录；同 ID 的本地正常关注保持不变。
    return current;
  }
}
