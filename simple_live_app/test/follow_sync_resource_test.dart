import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/resources/follow_sync_resource.dart';

void main() {
  test('远端首次缺失时关注观看增量只折叠一次', () {
    final follow = FollowUser(
      id: 'huya_1',
      roomId: '1',
      siteId: 'huya',
      userName: '主播',
      face: '',
      addTime: DateTime(2026, 9, 2),
      watchDuration: '0:00:30',
      watchDurationSec: 30,
      syncDuration: 30,
    );
    final bundle = FollowBundle(
      follows: [follow],
      tags: [FollowUserTag(id: '0', tag: '全部', userId: const [])],
    );

    final prepared = FollowSyncResource().prepareInitialBidirectional(bundle);

    expect(prepared.follows.single.watchDuration, '0:00:30');
    expect(prepared.follows.single.syncDuration, 0);
    expect(follow.syncDuration, 30);
  });
}
