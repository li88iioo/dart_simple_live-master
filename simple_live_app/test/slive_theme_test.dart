import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/settings/appstyle_settings/appstyle_setting_contorller.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('浅色主题固定暖瓷中性色并保留动态强调色', () {
    const accent = Color(0xFF4E7FD8);
    final theme = AppStyle.light(
      colorScheme: ColorScheme.fromSeed(seedColor: accent),
      glassMode: SliveGlassMode.clear,
    );
    final colors = theme.extension<SliveColorTokens>()!;
    final materials = theme.extension<SliveMaterialTokens>()!;

    expect(colors.backgroundBase, const Color(0xFFF6F3ED));
    expect(colors.textPrimary, const Color(0xFF2B2623));
    expect(colors.huya, const Color(0xFFF5A623));
    expect(colors.ambientAccent, theme.colorScheme.primary);
    expect(theme.scaffoldBackgroundColor, colors.backgroundBase);
    expect(materials.mode, SliveGlassMode.clear);
    expect(materials.backdropBlur, greaterThan(30));
  });

  test('柔和材质比通透材质遮罩更高且模糊更低', () {
    final clear = SliveMaterialTokens.resolve(
      SliveGlassMode.clear,
      Brightness.light,
    );
    final soft = SliveMaterialTokens.resolve(
      SliveGlassMode.soft,
      Brightness.light,
    );

    expect(soft.cardOpacity, greaterThan(clear.cardOpacity));
    expect(soft.backdropBlur, lessThan(clear.backdropBlur));
    expect(soft.shadowOpacity, lessThan(clear.shadowOpacity));
  });

  group('玻璃材质设置持久化', () {
    late Directory tempDirectory;
    late LocalStorageService storage;

    setUpAll(() async {
      Get.testMode = true;
      tempDirectory = await Directory.systemTemp.createTemp(
        'simple_live_glass_mode_test_',
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

    test('默认使用柔和模式并能恢复通透模式', () async {
      var controller = AppStyleSettingController();
      controller.loadAppearancePreferences();
      expect(controller.glassMode.value, SliveGlassMode.soft);

      controller.setGlassMode(SliveGlassMode.clear);
      await storage.flush();

      controller = AppStyleSettingController();
      controller.loadAppearancePreferences();
      expect(controller.glassMode.value, SliveGlassMode.clear);
    });
  });
}
