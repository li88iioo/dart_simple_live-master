import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late LocalStorageService storage;
  late AppSettingsController settings;

  setUpAll(() async {
    Get.testMode = true;
    tempDirectory = await Directory.systemTemp.createTemp(
      'simple_live_shield_storage_test_',
    );
    Hive.init(tempDirectory.path);
    storage = Get.put(LocalStorageService());
    await storage.init();
    settings = AppSettingsController();
  });

  setUp(() async {
    await storage.shieldBox.clear();
    settings.shieldList.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    Get.reset();
    await tempDirectory.delete(recursive: true);
  });

  test('非覆盖合并会保留旧值并迁移历史数字键', () async {
    await storage.shieldBox.add('旧关键词');

    await settings.mergeShieldList(['新关键词'], overlay: false);

    expect(storage.shieldBox.values.toSet(), {'旧关键词', '新关键词'});
    expect(storage.shieldBox.keys.toSet(), {'旧关键词', '新关键词'});
    expect(settings.shieldList, {'旧关键词', '新关键词'});
  });

  test('删除关键词会同时移除历史数字键残留', () async {
    await storage.shieldBox.add('待删除');
    settings.shieldList.add('待删除');

    await settings.removeShieldList('待删除');

    expect(storage.shieldBox.values, isEmpty);
    expect(settings.shieldList, isEmpty);
  });
}
