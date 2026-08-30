import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/models/font_model.dart';
import 'package:simple_live_app/requests/http_client.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

class AppStyleSettingController extends GetxController {
  static AppStyleSettingController get instance =>
      Get.find<AppStyleSettingController>();

  /// 是否让系统动态色控制强调色。旧字段名保留以兼容 main.dart。
  var isDynamic = false.obs;

  /// 手动强调色 ARGB。旧字段名保留以兼容 main.dart 和既有配置。
  var styleColor = 0xff3498db.obs;
  var glassMode = SliveGlassMode.soft.obs;
  var backgroundSource = SliveBackgroundSource.preset.obs;
  var backgroundPreset = SliveBackgroundPreset.warmPorcelain.obs;
  var customBackgroundColor = SliveBackgroundStyle.colorToArgb(
    SliveBackgroundStyle.defaultCustomColor,
  ).obs;
  Rx<String?> curFontName = Rx<String?>(null);
  Rx<FontModel?> curFontModel = Rx<FontModel?>(null);
  final RxList<FontModel> fontList = <FontModel>[].obs;
  final RxMap<FontModel, String> fontMap = <FontModel, String>{}.obs;
  Rx<DownloadState> fontState = DownloadState.notDownloaded.obs;

  Future<void> init() async {
    loadAppearancePreferences();
    await fetchFonts();
    await userFontInit();
  }

  SliveBackgroundStyle get backgroundStyle => SliveBackgroundStyle(
        source: backgroundSource.value,
        preset: backgroundPreset.value,
        customColor: Color(customBackgroundColor.value),
      );

  void loadAppearancePreferences() {
    styleColor.value = LocalStorageService.instance
        .getValue(LocalStorageService.kStyleColor, 0xff3498db);

    isDynamic.value = LocalStorageService.instance
        .getValue(LocalStorageService.kIsDynamic, false);
    final storedGlassMode = LocalStorageService.instance.getValue(
      LocalStorageService.kGlassMode,
      SliveGlassMode.soft.index,
    );
    glassMode.value =
        storedGlassMode >= 0 && storedGlassMode < SliveGlassMode.values.length
            ? SliveGlassMode.values[storedGlassMode]
            : SliveGlassMode.soft;

    backgroundSource.value = SliveBackgroundSource.fromId(
      LocalStorageService.instance.getValue(
        LocalStorageService.kBackgroundSource,
        SliveBackgroundSource.preset.id,
      ),
    );
    backgroundPreset.value = SliveBackgroundPreset.fromId(
      LocalStorageService.instance.getValue(
        LocalStorageService.kBackgroundPresetId,
        SliveBackgroundPreset.warmPorcelain.id,
      ),
    );
    final storedCustomColor = LocalStorageService.instance.getValue(
      LocalStorageService.kCustomBackgroundColor,
      SliveBackgroundStyle.colorToArgb(
        SliveBackgroundStyle.defaultCustomColor,
      ),
    );
    customBackgroundColor.value = SliveBackgroundStyle.colorToArgb(
      SliveBackgroundStyle.normalizeLightColor(Color(storedCustomColor)),
    );
  }

  Future<void> fontDelete() async {
    var dir = await getApplicationSupportDirectory();
    final fontDir = Directory("${dir.path}/fonts/${curFontModel.value!.id}");
    try {
      // 删除整个目录（包括目录本身和所有内容）
      await fontDir.delete(recursive: true);
      await fontDir.create(recursive: true);
      var download = await fontDownloadCheck(curFontModel.value!.id);
      if (download == false) {
        fontState.value = DownloadState.notDownloaded;
      }
      SmartDialog.showToast("已删除${curFontModel.value!.name}字体");
      Log.d('目录${fontDir.path}已清空并重新创建');
    } catch (e, s) {
      Log.e('操作失败: $e', s);
    }
  }

  void fontReset() {
    if (Platform.isWindows) {
      curFontName.value = "Microsoft YaHei";
      LocalStorageService.instance
          .setValue(LocalStorageService.kCustomFont, curFontName.value);
    } else {
      curFontName.value = null;
      LocalStorageService.instance.removeValue(LocalStorageService.kCustomFont);
    }
  }

  void changeFontFamily() {
    curFontName.value = curFontModel.value?.id;
    LocalStorageService.instance
        .setValue(LocalStorageService.kCustomFont, curFontName.value);
    SmartDialog.showToast("已设置全局字体为${curFontModel.value?.name}");
  }

  Future<void> onFontSelected(FontModel fontModel) async {
    var fontName = fontModel.id;
    curFontModel.value = fontModel;
    if (await fontDownloadCheck(fontName)) {
      fontState.value = DownloadState.downloaded;
      // 存在则加载并应用
      await loadFont(fontName);
    } else {
      fontState.value = DownloadState.notDownloaded;
    }
  }

  Future<void> downloadFont() async {
    var dir = await getApplicationSupportDirectory();
    var fontName = curFontModel.value!.id;
    final fontDir = Directory("${dir.path}/fonts/$fontName");
    if (!await fontDir.exists()) {
      await fontDir.create(recursive: true);
    }
    Log.d("开始下载----$fontName");
    const baseUrl = "https://gcore.jsdelivr.net/gh/SlotSun/fonts@master/";
    fontState.value = DownloadState.downloading;
    for (var filePath in curFontModel.value!.files) {
      final fileName = filePath.split('/').last;
      final file = File("${fontDir.path}/$fileName");

      if (!await file.exists()) {
        int retryCount = 0;
        const maxRetries = 3;
        while (retryCount < maxRetries) {
          try {
            // Download if not exists
            await HttpClient.instance.download(
              "$baseUrl$filePath",
              file.path,
            );
            break; // Success
          } catch (e, s) {
            retryCount++;
            if (retryCount >= maxRetries) {
              Log.e(
                  "Failed to download font file after $maxRetries attempts: $filePath\n$e",
                  s);
              fontState.value = DownloadState.notDownloaded;
              SmartDialog.showToast("下载失败，请检查网络后重试");
              throw Exception("Failed to download $fileName: $e");
            }
            Log.w(
                "Download failed, retrying ($retryCount/$maxRetries): $fileName");
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
    }
    fontState.value = DownloadState.downloaded;
    await loadFont(fontName);
  }

  Future<void> userFontInit() async {
    var fontName = LocalStorageService.instance
        .getNullValue<String?>(LocalStorageService.kCustomFont, null);
    Log.d('获取当前字体$fontName');
    if (fontName != null && fontName != "Microsoft YaHei") {
      // 确认本地是否存在此字体
      if (await fontDownloadCheck(fontName)) {
        // 存在则加载并应用
        await loadFont(fontName);
      } else {
        // 不存在则使用默认字体
        fontName = null;
      }
    }
    curFontName.value = fontName;
    if (curFontName.value != null) {
      curFontModel.value = fontMap.keys.firstWhere(
          (element) => element.id == curFontName.value,
          orElse: () => fontMap.keys.first);
    } else {
      curFontModel.value = fontMap.keys.first;
    }
    // maybe curFontName = null
    fontState.value = await fontDownloadCheck(curFontModel.value!.id)
        ? DownloadState.downloaded
        : DownloadState.notDownloaded;

    Log.d("当前字体模型：${curFontModel.value!.id}");
  }

  Future<void> loadFont(String fontName) async {
    var dir = await getApplicationSupportDirectory();
    final fontDir = Directory("${dir.path}/fonts/$fontName");
    final loader = FontLoader(fontName);

    await for (final entity in fontDir.list()) {
      if (entity is File && entity.path.endsWith('.ttf')) {
        loader.addFont(entity.readAsBytes().then(ByteData.sublistView));
      }
    }
    await loader.load();
    Log.d('已加载$fontName 词库');
  }

  Future<bool> fontDownloadCheck(String fontName) async {
    final dir = await getApplicationSupportDirectory();
    final fontDir = Directory("${dir.path}/fonts/$fontName");
    bool fontDownload =
        await fontDir.exists() && await fontDir.list().length >= 1;
    return fontDownload;
  }

  Future<void> fetchFonts() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/fonts/fonts-manifest.json');
      final List<dynamic> list = json.decode(jsonStr);
      // 集合推导构造fontMap
      fontMap.assignAll(
        {
          for (final e in list)
            FontModel.fromJson(e): (e['name'] as String? ?? ''),
        },
      );
    } catch (e, s) {
      Log.e("Failed to fetch fonts manifest: $e", s);
    }
  }

  void setIsDynamic(bool e) {
    isDynamic.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kIsDynamic, e);
  }

  void setGlassMode(SliveGlassMode mode) {
    glassMode.value = mode;
    LocalStorageService.instance.setValue(
      LocalStorageService.kGlassMode,
      mode.index,
    );
  }

  Future<void> setBackgroundSource(SliveBackgroundSource source) async {
    backgroundSource.value = source;
    await LocalStorageService.instance.setValue(
      LocalStorageService.kBackgroundSource,
      source.id,
    );
  }

  Future<void> setBackgroundPreset(SliveBackgroundPreset preset) async {
    backgroundPreset.value = preset;
    backgroundSource.value = SliveBackgroundSource.preset;
    await LocalStorageService.instance.setValue(
      LocalStorageService.kBackgroundPresetId,
      preset.id,
    );
    await LocalStorageService.instance.setValue(
      LocalStorageService.kBackgroundSource,
      SliveBackgroundSource.preset.id,
    );
  }

  Future<void> setCustomBackgroundColor(Color color) async {
    final safeColor = SliveBackgroundStyle.normalizeLightColor(color);
    customBackgroundColor.value = SliveBackgroundStyle.colorToArgb(safeColor);
    backgroundSource.value = SliveBackgroundSource.custom;
    await LocalStorageService.instance.setValue(
      LocalStorageService.kCustomBackgroundColor,
      customBackgroundColor.value,
    );
    await LocalStorageService.instance.setValue(
      LocalStorageService.kBackgroundSource,
      SliveBackgroundSource.custom.id,
    );
  }

  void changeTheme() {
    Get.dialog(
      SimpleDialog(
        title: const Text("设置主题"),
        children: [
          RadioGroup<int>(
            groupValue: AppSettingsController.instance.themeMode.value,
            onChanged: (e) {
              Get.back();
              setTheme(e ?? 0);
            },
            child: Column(
              children: [
                RadioListTile<int>(
                  title: const Text("跟随系统"),
                  value: 0,
                ),
                RadioListTile<int>(
                  title: const Text("浅色模式"),
                  value: 1,
                ),
                RadioListTile<int>(
                  title: const Text("深色模式"),
                  value: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void setTheme(int i) {
    final safeIndex = i >= 0 && i < ThemeMode.values.length ? i : 0;
    AppSettingsController.instance.themeMode.value = safeIndex;
    final mode = ThemeMode.values[safeIndex];

    LocalStorageService.instance.setValue(
      LocalStorageService.kThemeMode,
      safeIndex,
    );
    Get.changeThemeMode(mode);
  }

  /// 兼容旧调用；语义明确为设置手动强调色。
  void setStyleColor(int e) {
    styleColor.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kStyleColor, e);
  }

  void setAccentColor(int color) => setStyleColor(color);
}
