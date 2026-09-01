import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:path/path.dart' as p;
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/services/firebase_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

class OtherSettingsController extends BaseController {
  RxList<LogFileModel> logFiles = <LogFileModel>[].obs;

  var videoOutputDrivers = {
    "gpu": "gpu",
    "gpu-next": "gpu-next",
    "xv": "xv (X11 only)",
    "x11": "x11 (X11 only)",
    "vdpau": "vdpau (X11 only)",
    "direct3d": "direct3d (Windows only)",
    "sdl": "sdl",
    "dmabuf-wayland": "dmabuf-wayland",
    "vaapi": "vaapi",
    "null": "null",
    "libmpv": "libmpv",
    "mediacodec_embed": "mediacodec_embed (Android only)",
  };

  var audioOutputDrivers = {
    "null": "null (No audio output)",
    "pulse": "pulse (Linux, uses PulseAudio)",
    "pipewire": "pipewire (Linux, via Pulse compatibility or native)",
    "alsa": "alsa (Linux only)",
    "oss": "oss (Linux only)",
    "jack": "jack (Linux/macOS, low-latency audio)",
    "directsound": "directsound (Windows only)",
    "wasapi": "wasapi (Windows only)",
    "winmm": "winmm (Windows only, legacy API)",
    "audiounit": "audiounit (iOS only)",
    "coreaudio": "coreaudio (macOS only)",
    "opensles": "opensles (Android only)",
    "audiotrack": "audiotrack (Android only)",
    "aaudio": "aaudio (Android only)",
    "pcm": "pcm (Cross-platform)",
    "sdl": "sdl (Cross-platform, via SDL library)",
    "openal": "openal (Cross-platform, OpenAL backend)",
    "libao": "libao (Cross-platform, uses libao library)",
    "auto": "auto (Not available)"
  };

  var hardwareDecoder = {
    "no": "no",
    "auto": "auto",
    "auto-safe": "auto-safe",
    "yes": "yes",
    "auto-copy": "auto-copy",
    "d3d11va": "d3d11va",
    "d3d11va-copy": "d3d11va-copy",
    "videotoolbox": "videotoolbox",
    "videotoolbox-copy": "videotoolbox-copy",
    "vaapi": "vaapi",
    "vaapi-copy": "vaapi-copy",
    "nvdec": "nvdec",
    "nvdec-copy": "nvdec-copy",
    "drm": "drm",
    "drm-copy": "drm-copy",
    "vulkan": "vulkan",
    "vulkan-copy": "vulkan-copy",
    "dxva2": "dxva2",
    "dxva2-copy": "dxva2-copy",
    "vdpau": "vdpau",
    "vdpau-copy": "vdpau-copy",
    "mediacodec": "mediacodec",
    "mediacodec-copy": "mediacodec-copy",
    "cuda": "cuda",
    "cuda-copy": "cuda-copy",
    "crystalhd": "crystalhd",
    "rkmpp": "rkmpp"
  };

  @override
  void onInit() {
    loadLogFiles();
    super.onInit();
  }

  void setFirebaseEnable(bool e) {
    AppSettingsController.instance.setFirebaseEnable(e);
    FirebaseService.setCrashlytics(e);
  }

  void setLogEnable(bool e) {
    AppSettingsController.instance.setLogEnable(e);
    if (e) {
      Log.initWriter();
      Future.delayed(const Duration(milliseconds: 100), () {
        loadLogFiles();
      });
    } else {
      Log.disposeWriter();
    }
  }

  void loadLogFiles() async {
    var supportDir = await getApplicationSupportDirectory();
    var logDir = Directory("${supportDir.path}/log");
    if (!await logDir.exists()) {
      await logDir.create();
    }
    logFiles.clear();
    await logDir.list().forEach((element) {
      var file = element as File;
      var name = p.basename(file.path);
      var time = file.lastModifiedSync();
      var size = file.lengthSync();
      logFiles.add(LogFileModel(name, file.path, time, size));
    });
    //logFiles 名称倒序
    logFiles.sort((a, b) => b.time.compareTo(a.time));
  }

  void cleanLog() async {
    if (AppSettingsController.instance.logEnable.value) {
      SmartDialog.showToast("请先关闭日志记录");
      return;
    }

    var supportDir = await getApplicationSupportDirectory();
    var logDir = Directory("${supportDir.path}/log");
    if (await logDir.exists()) {
      await logDir.delete(recursive: true);
    }
    loadLogFiles();
  }

  void shareLogFile(LogFileModel item) {
    SharePlus.instance.share(ShareParams(files: [XFile(item.path)]));
  }

  void saveLogFile(LogFileModel item) async {
    var filePath = await FilePicker.platform.saveFile(
      allowedExtensions: ['log'],
      type: FileType.custom,
      fileName: item.name,
    );
    if (filePath != null) {
      var file = File(item.path);
      await file.copy(filePath);
      SmartDialog.showToast("保存成功");
    }
  }

  void exportConfig() async {
    try {
      final data = ConfigTransferCodec.createDocument(
        platform: Platform.operatingSystem,
        time: DateTime.now().millisecondsSinceEpoch,
        settings: LocalStorageService.instance.settingsBox.toMap(),
        shield: LocalStorageService.instance.shieldBox.toMap(),
      );
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));

      final inlineSave = Platform.isAndroid || Platform.isIOS || kIsWeb;
      final path = await FilePicker.platform.saveFile(
        allowedExtensions: ['json'],
        type: FileType.custom,
        fileName: "simple_live_config.json",
        bytes: inlineSave ? bytes : null,
      );

      if (path == null && !kIsWeb) {
        SmartDialog.showToast("保存取消");
        return;
      }
      if (!inlineSave && path != null) {
        await File(path).writeAsBytes(bytes);
      }
      SmartDialog.showToast("保存成功");
    } catch (e, s) {
      Log.e("导出配置失败：$e", s);
      SmartDialog.showToast("导出失败:$e");
    }
  }

  void importConfig() async {
    try {
      final file = await FilePicker.platform.pickFiles(
        allowedExtensions: ['json'],
        type: FileType.custom,
      );
      if (file == null) return;

      final filePath = file.files.single.path;
      if (filePath == null) {
        throw const FormatException("无法读取配置文件路径");
      }
      final configFile = File(filePath);
      if (await configFile.length() > ConfigTransferCodec.maxDocumentBytes) {
        throw const FormatException("配置文件过大");
      }
      final rawText = await configFile.readAsString();
      final payload = ConfigTransferCodec.decode(jsonDecode(rawText));

      if (payload.platform != Platform.operatingSystem &&
          !await Utils.showAlertDialog(
            "导入配置文件平台不匹配,是否继续导入?",
            title: "平台不匹配",
          )) {
        return;
      }

      await ConfigTransferCodec.apply(
        LocalStorageService.instance,
        payload,
      );
      SmartDialog.showToast("导入成功,已忽略账号凭据和内部状态,重启生效");
    } catch (e, s) {
      Log.e("导入配置失败：$e", s);
      SmartDialog.showToast("导入失败:$e");
    }
  }

  Future<void> resetDefaultConfig() async {
    final confirmed = await Utils.showAlertDialog("是否重置所有配置为默认值?");
    if (!confirmed) return;

    await LocalStorageService.instance.synchronizedWrite(() async {
      await LocalStorageService.instance.settingsBox.clear();
      await LocalStorageService.instance.shieldBox.clear();
    });
    SmartDialog.showToast("重置成功,重启生效");
  }
}

class ConfigTransferPayload {
  const ConfigTransferPayload({
    required this.platform,
    required this.config,
    required this.shield,
  });

  final String platform;
  final Map<String, dynamic> config;
  final Map<String, String> shield;
}

class ConfigTransferCodec {
  static const int currentVersion = 2;
  static const int maxDocumentBytes = 2 * 1024 * 1024;
  static const int maxConfigEntries = 256;
  static const int maxShieldEntries = 5000;
  static const int maxShieldTextLength = 4096;

  static Map<String, dynamic> createDocument({
    required String platform,
    required int time,
    required Map<dynamic, dynamic> settings,
    required Map<dynamic, dynamic> shield,
  }) {
    return {
      'type': 'simple_live',
      'platform': _validatePlatform(platform),
      'version': currentVersion,
      'time': time,
      'config': LocalStorageService.filterTransferableConfig(settings),
      'shield': _normalizeShield(shield),
    };
  }

  static ConfigTransferPayload decode(Object? document) {
    if (document is! Map) {
      throw const FormatException('配置文件根节点必须是对象');
    }
    if (document['type'] != 'simple_live') {
      throw const FormatException('不支持的配置文件');
    }

    final version = document['version'];
    if (version is! int || version < 1 || version > currentVersion) {
      throw const FormatException('配置文件版本不受支持');
    }
    final time = document['time'];
    if (time is! int || time < 0) {
      throw const FormatException('配置文件时间字段无效');
    }

    final rawConfig = document['config'];
    final rawShield = document['shield'];
    if (rawConfig is! Map || rawShield is! Map) {
      throw const FormatException('配置文件数据结构无效');
    }
    if (rawConfig.length > maxConfigEntries) {
      throw const FormatException('配置项数量过多');
    }

    return ConfigTransferPayload(
      platform: _validatePlatform(document['platform']),
      config: LocalStorageService.filterTransferableConfig(
        rawConfig,
        strict: true,
      ),
      shield: _normalizeShield(rawShield, strict: true),
    );
  }

  static Future<void> apply(
    LocalStorageService storage,
    ConfigTransferPayload payload,
  ) {
    return storage.synchronizedWrite(() async {
      final settingsBox = storage.settingsBox;
      final shieldBox = storage.shieldBox;

      if (payload.config.isNotEmpty) {
        await settingsBox.putAll(payload.config);
      }
      if (payload.shield.isNotEmpty) {
        await shieldBox.putAll(payload.shield);
      }

      final staleShieldKeys = shieldBox.keys
          .where((key) => !payload.shield.containsKey(key))
          .toList();
      if (staleShieldKeys.isNotEmpty) {
        await shieldBox.deleteAll(staleShieldKeys);
      }

      // 只清理可迁移的用户设置。账号凭据、WebDAV 状态、数据库版本及
      // 未知的未来字段均保持原值，避免配置导入越权覆盖内部状态。
      final staleSettingKeys = LocalStorageService.transferableConfigSchema.keys
          .where(
            (key) =>
                settingsBox.containsKey(key) &&
                !payload.config.containsKey(key),
          )
          .toList();
      if (staleSettingKeys.isNotEmpty) {
        await settingsBox.deleteAll(staleSettingKeys);
      }
    });
  }

  static String _validatePlatform(Object? platform) {
    if (platform is! String || platform.isEmpty || platform.length > 64) {
      throw const FormatException('配置文件平台字段无效');
    }
    return platform;
  }

  static Map<String, String> _normalizeShield(
    Map<dynamic, dynamic> source, {
    bool strict = false,
  }) {
    if (source.length > maxShieldEntries) {
      throw const FormatException('屏蔽词数量过多');
    }

    final result = <String, String>{};
    for (final value in source.values) {
      if (value is! String ||
          value.isEmpty ||
          value.length > maxShieldTextLength) {
        if (strict) {
          throw const FormatException('屏蔽词配置格式无效');
        }
        continue;
      }
      result[value] = value;
    }
    return result;
  }
}

class LogFileModel {
  late String name;
  late String path;
  late DateTime time;
  late int size;
  LogFileModel(this.name, this.path, this.time, this.size);
}
