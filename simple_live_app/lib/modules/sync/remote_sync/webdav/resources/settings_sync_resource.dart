import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/interface/sync_resource.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

class SettingsSyncResource implements SyncResource<Map<String, dynamic>> {
  static const int _legacyFallbackDbVersion = 10805;

  @override
  String get fileName => 'SimpleLive_Settings.json';

  @override
  Future<Map<String, dynamic>> loadLocal() async {
    final settings = LocalStorageService.filterTransferableConfig(
      LocalStorageService.instance.settingsBox.toMap(),
    );
    return {
      LocalStorageService.kHiveDbVer: AppSettingsController.instance.dbVer,
      Platform.operatingSystem: settings,
    };
  }

  @override
  Map<String, dynamic>? loadRemote(Archive archive) {
    final file = archive.findFile(fileName);
    if (file == null) return null;

    final root = jsonDecode(utf8.decode(file.content));
    if (root is! Map || root['data'] is! Map) {
      throw const FormatException('远端设置备份结构无效');
    }

    final rawData = root['data'] as Map;
    final result = <String, dynamic>{};
    for (final entry in rawData.entries) {
      final key = entry.key;
      if (key is! String || key.isEmpty || key.length > 64) {
        throw const FormatException('远端设置备份包含非法字段');
      }
      if (key == LocalStorageService.kHiveDbVer) {
        result[key] = _parseDbVersion(entry.value);
        continue;
      }
      if (entry.value is! Map) {
        throw FormatException('远端平台设置结构无效：$key');
      }
      result[key] = LocalStorageService.filterTransferableConfig(
        entry.value as Map,
        strict: true,
      );
    }
    return result;
  }

  @override
  Future<void> saveLocal(Map<String, dynamic> data) async {
    try {
      final platform = Platform.operatingSystem;
      final rawPlatformSettings = data[platform];
      if (rawPlatformSettings != null) {
        if (rawPlatformSettings is! Map) {
          throw FormatException('远端平台设置结构无效：$platform');
        }
        final settings = LocalStorageService.filterTransferableConfig(
          rawPlatformSettings,
          strict: true,
        );
        for (final entry in settings.entries) {
          await LocalStorageService.instance.setValue(entry.key, entry.value);
        }
      } else {
        Log.i('缺少$platform对应平台用户设置备份');
      }

      final dbVersion = data.containsKey(LocalStorageService.kHiveDbVer)
          ? _parseDbVersion(data[LocalStorageService.kHiveDbVer])
          : _legacyFallbackDbVersion;
      await LocalStorageService.instance.setValue(
        LocalStorageService.kHiveDbVer,
        dbVersion,
      );
    } catch (error, stackTrace) {
      Log.e('同步用户设置失败：$error', stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  void saveRemote(Archive archive, Map<String, dynamic> data) {
    final bytes = utf8.encode(jsonEncode({'data': data}));
    archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
  }

  @override
  Map<String, dynamic> merge(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    return {...local, ...remote};
  }

  static int _parseDbVersion(Object? value) {
    if (value is int && value > 0) return value;
    throw const FormatException('远端数据库版本无效');
  }
}
