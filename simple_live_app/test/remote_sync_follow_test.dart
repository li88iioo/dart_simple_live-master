import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/resources/follow_sync_resource.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

void main() {
  late Directory tempDirectory;
  late LocalStorageService storage;

  setUpAll(() async {
    Get.testMode = true;
    tempDirectory = await Directory.systemTemp.createTemp(
      'simple_live_remote_sync_test_',
    );
    Hive.init(tempDirectory.path);
    storage = Get.put(LocalStorageService());
    await storage.init();
  });

  setUp(() async {
    await storage.settingsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    Get.reset();
    await tempDirectory.delete(recursive: true);
  });

  test('首次同步使用 Unix epoch，不遗漏 2026 年以前的关注记录', () {
    final resource = FollowSyncResource();
    final oldFollow = _follow(
      id: 'huya_1',
      addTime: DateTime.utc(2025, 1, 1),
    );

    final result = resource.merge(
      FollowBundle(follows: [oldFollow]),
      FollowBundle(),
    );

    expect(result.follows.map((item) => item.id), contains(oldFollow.id));
  });

  test('已有恢复时间时仍会过滤同步点之前的单边记录', () async {
    await storage.settingsBox.put(
      LocalStorageService.kWebDAVLastRecoverTime,
      DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
    );
    final resource = FollowSyncResource();
    final staleFollow = _follow(
      id: 'huya_stale',
      addTime: DateTime.utc(2025, 12, 31),
    );

    final result = resource.merge(
      FollowBundle(follows: [staleFollow]),
      FollowBundle(),
    );

    expect(result.follows, isEmpty);
  });
}

FollowUser _follow({
  required String id,
  required DateTime addTime,
}) {
  return FollowUser(
    id: id,
    roomId: id,
    siteId: 'huya',
    userName: id,
    face: '',
    addTime: addTime,
  );
}
