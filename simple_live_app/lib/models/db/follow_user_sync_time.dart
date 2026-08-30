import 'package:simple_live_app/models/db/follow_user.dart';

extension FollowUserSyncTime on FollowUser {
  int get followTimeMillis => addTime.millisecondsSinceEpoch;

  int get deletionTimeMillis => normalizeFollowTimestamp(updateTime);
}

/// 兼容旧版秒级墓碑时间戳，新写入统一使用毫秒。
int normalizeFollowTimestamp(int value) {
  if (value <= 0) return 0;
  return value < 1000000000000 ? value * 1000 : value;
}
