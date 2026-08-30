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

  setUpAll(() async {
    Get.testMode = true;
    tempDirectory = await Directory.systemTemp.createTemp(
      'simple_live_huya_gift_settings_test_',
    );
    Hive.init(tempDirectory.path);
    storage = Get.put(LocalStorageService());
    await storage.init();
  });

  setUp(() async {
    if (Get.isRegistered<AppSettingsController>()) {
      Get.delete<AppSettingsController>(force: true);
    }
    await storage.settingsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    Get.reset();
    await tempDirectory.delete(recursive: true);
  });

  test('虎牙礼物弹幕默认开启并持久化用户开关', () async {
    var settings = Get.put(AppSettingsController());
    expect(settings.huyaGiftDanmakuEnable.value, isTrue);

    settings.setHuyaGiftDanmakuEnable(false);
    await storage.flush();
    expect(
      storage.settingsBox.get(LocalStorageService.kHuyaGiftDanmakuEnable),
      isFalse,
    );

    Get.delete<AppSettingsController>(force: true);
    settings = Get.put(AppSettingsController());
    expect(settings.huyaGiftDanmakuEnable.value, isFalse);
  });
}
