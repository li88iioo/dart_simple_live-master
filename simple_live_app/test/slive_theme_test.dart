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

  test('浅色主题默认保持暖瓷背景并让强调色独立生效', () {
    const accent = Color(0xFF4E7FD8);
    final theme = AppStyle.light(
      colorScheme: ColorScheme.fromSeed(seedColor: accent),
      glassMode: SliveGlassMode.clear,
    );
    final colors = theme.extension<SliveColorTokens>()!;
    final materials = theme.extension<SliveMaterialTokens>()!;

    expect(colors.backgroundStart, const Color(0xFFFAF7F2));
    expect(colors.backgroundBase, const Color(0xFFF6F3ED));
    expect(colors.backgroundEnd, const Color(0xFFF0EBE2));
    expect(colors.textPrimary, const Color(0xFF2B2623));
    expect(colors.huya, const Color(0xFFF5A623));
    expect(colors.ambientAccent, theme.colorScheme.primary);
    expect(colors.backgroundBase, isNot(theme.colorScheme.primary));
    expect(theme.scaffoldBackgroundColor, colors.backgroundBase);
    expect(materials.mode, SliveGlassMode.clear);
    expect(materials.backdropBlur, greaterThan(30));
    expect(theme.bottomSheetTheme.showDragHandle, isTrue);
    expect(theme.bottomSheetTheme.modalElevation, 0);
    expect(theme.dialogTheme.elevation, 0);
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
  });

  test('三套内置浅色背景使用稳定 ID 和独立色板', () {
    expect(LocalStorageService.kBackgroundSource, 'BackgroundSource');
    expect(LocalStorageService.kBackgroundPresetId, 'BackgroundPresetId');
    expect(
      LocalStorageService.kCustomBackgroundColor,
      'CustomBackgroundColor',
    );
    expect(
      SliveBackgroundPreset.values.map((preset) => preset.id).toSet(),
      hasLength(3),
    );
    expect(
      SliveBackgroundPreset.values.map((preset) => preset.id),
      containsAll(<String>['warmPorcelain', 'mistBlue', 'sageMilk']),
    );
    expect(
      SliveBackgroundPreset.mistBlue.lightPalette.base,
      const Color(0xFFF1F4F6),
    );
    expect(
      SliveBackgroundPreset.sageMilk.lightPalette.base,
      const Color(0xFFF2F4EE),
    );
    final theme = AppStyle.light(
      backgroundPalette: SliveBackgroundPreset.mistBlue.lightPalette,
    );
    expect(
      theme.extension<SliveColorTokens>()!.backgroundBase,
      const Color(0xFFF1F4F6),
    );
  });

  test('系统动态背景使用 surface 中性色而不是强调色', () {
    const accent = Color(0xFFE45959);
    const dynamicSurface = Color(0xFFE9F1F5);
    const style = SliveBackgroundStyle(
      source: SliveBackgroundSource.systemDynamic,
    );
    final expected = style.resolve(
      Brightness.light,
      dynamicSurface: dynamicSurface,
    );
    final theme = AppStyle.light(
      colorScheme: ColorScheme.fromSeed(seedColor: accent),
      backgroundStyle: style,
      dynamicBackgroundSurface: dynamicSurface,
    );
    final colors = theme.extension<SliveColorTokens>()!;

    expect(colors.backgroundBase, expected.base);
    expect(colors.backgroundBase, isNot(theme.colorScheme.primary));
    expect(
      HSLColor.fromColor(colors.backgroundBase).saturation,
      lessThanOrEqualTo(0.185),
    );
  });

  test('自定义背景会被约束为高明度低饱和且深色派生保持可读', () {
    const unsafeColor = Color(0xFF00C853);
    final safeColor = SliveBackgroundStyle.normalizeLightColor(unsafeColor);
    final safeHsl = HSLColor.fromColor(safeColor);
    const style = SliveBackgroundStyle(
      source: SliveBackgroundSource.custom,
      customColor: unsafeColor,
    );
    final light = style.resolve(Brightness.light);
    final darkTheme = AppStyle.darkTheme(backgroundStyle: style);
    final dark = darkTheme.extension<SliveColorTokens>()!;

    expect(safeHsl.saturation, lessThanOrEqualTo(0.185));
    expect(safeHsl.lightness, inInclusiveRange(0.88, 0.96));
    expect(light.base, safeColor);
    expect(dark.backgroundBase.computeLuminance(), lessThan(0.04));
    expect(
      dark.textPrimary.computeLuminance(),
      greaterThan(dark.backgroundBase.computeLuminance()),
    );
  });

  test('Material 交互关闭 InkSparkle 并保留轻量强调色按压反馈', () {
    final theme = AppStyle.light();
    final pressed = theme.tabBarTheme.overlayColor!.resolve(
      const <WidgetState>{WidgetState.pressed},
    );
    final focused = theme.tabBarTheme.overlayColor!.resolve(
      const <WidgetState>{WidgetState.focused},
    );

    expect(theme.splashFactory, same(NoSplash.splashFactory));
    expect(theme.tabBarTheme.splashFactory, same(NoSplash.splashFactory));
    expect(theme.splashColor, Colors.transparent);
    expect(theme.shadowColor, Colors.transparent);
    expect(theme.highlightColor.a, greaterThan(0));
    expect(theme.highlightColor.a, lessThan(0.10));
    expect(pressed, isNotNull);
    expect(pressed!.a, greaterThan(0));
    expect(pressed.a, lessThan(0.10));
    expect(focused, isNotNull);
    expect(focused!.a, lessThan(pressed.a));
    expect(
      theme.elevatedButtonTheme.style!.elevation!.resolve(
        const <WidgetState>{},
      ),
      0,
    );
    expect(
      theme.elevatedButtonTheme.style!.shadowColor!.resolve(
        const <WidgetState>{},
      ),
      Colors.transparent,
    );
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

  group('外观设置持久化', () {
    late Directory tempDirectory;
    late LocalStorageService storage;

    setUpAll(() async {
      Get.testMode = true;
      tempDirectory = await Directory.systemTemp.createTemp(
        'simple_live_appearance_test_',
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

    test('旧配置默认恢复暖瓷背景且保留强调色语义', () async {
      await storage.setValue(LocalStorageService.kStyleColor, 0xFFEF5350);
      await storage.setValue(LocalStorageService.kIsDynamic, true);

      final controller = AppStyleSettingController();
      controller.loadAppearancePreferences();

      expect(controller.styleColor.value, 0xFFEF5350);
      expect(controller.isDynamic.value, isTrue);
      expect(controller.backgroundSource.value, SliveBackgroundSource.preset);
      expect(
        controller.backgroundPreset.value,
        SliveBackgroundPreset.warmPorcelain,
      );
      expect(
        controller.backgroundStyle.resolve(Brightness.light).base,
        const Color(0xFFF6F3ED),
      );
    });

    test('背景来源、预设和安全自定义颜色可持久化恢复', () async {
      var controller = AppStyleSettingController();
      controller.loadAppearancePreferences();
      await controller.setBackgroundSource(
        SliveBackgroundSource.systemDynamic,
      );

      controller = AppStyleSettingController();
      controller.loadAppearancePreferences();
      expect(
        controller.backgroundSource.value,
        SliveBackgroundSource.systemDynamic,
      );

      await controller.setBackgroundPreset(SliveBackgroundPreset.mistBlue);

      controller = AppStyleSettingController();
      controller.loadAppearancePreferences();
      expect(controller.backgroundSource.value, SliveBackgroundSource.preset);
      expect(
        controller.backgroundPreset.value,
        SliveBackgroundPreset.mistBlue,
      );

      await controller.setCustomBackgroundColor(const Color(0xFFFF1744));
      controller = AppStyleSettingController();
      controller.loadAppearancePreferences();
      final restored = Color(controller.customBackgroundColor.value);
      final restoredHsl = HSLColor.fromColor(restored);

      expect(controller.backgroundSource.value, SliveBackgroundSource.custom);
      expect(restoredHsl.saturation, lessThanOrEqualTo(0.185));
      expect(restoredHsl.lightness, inInclusiveRange(0.87, 0.97));
    });

    test('非法背景字符串安全回退且玻璃模式仍可恢复', () async {
      await storage.setValue(LocalStorageService.kBackgroundSource, 'future');
      await storage.setValue(
        LocalStorageService.kBackgroundPresetId,
        'missingPreset',
      );
      await storage.setValue(LocalStorageService.kGlassMode, 999);

      var controller = AppStyleSettingController();
      controller.loadAppearancePreferences();
      expect(controller.backgroundSource.value, SliveBackgroundSource.preset);
      expect(
        controller.backgroundPreset.value,
        SliveBackgroundPreset.warmPorcelain,
      );
      expect(controller.glassMode.value, SliveGlassMode.soft);

      controller.setGlassMode(SliveGlassMode.clear);
      await storage.flush();
      controller = AppStyleSettingController();
      controller.loadAppearancePreferences();
      expect(controller.glassMode.value, SliveGlassMode.clear);
    });
  });
}
