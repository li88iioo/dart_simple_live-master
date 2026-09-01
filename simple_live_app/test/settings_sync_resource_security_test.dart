import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/resources/settings_sync_resource.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  test('saveLocal 等待全部设置写入并始终写入 int 数据库版本', () async {
    final storage = _GatedStorage();
    Get.put<LocalStorageService>(storage);
    final resource = SettingsSyncResource();
    var completed = false;

    final future = resource.saveLocal({
      Platform.operatingSystem: {
        LocalStorageService.kThemeMode: 1,
        LocalStorageService.kBilibiliCookie: 'must-not-write',
      },
      LocalStorageService.kHiveDbVer: 10816,
    }).then((_) => completed = true);

    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    storage.releaseWrites();
    await future;

    expect(storage.writes[LocalStorageService.kThemeMode], 1);
    expect(storage.writes.containsKey(LocalStorageService.kBilibiliCookie),
        isFalse);
    expect(storage.writes[LocalStorageService.kHiveDbVer], 10816);
    expect(storage.writes[LocalStorageService.kHiveDbVer], isA<int>());
  });

  test('缺少远端数据库版本时使用 int 类型兼容版本', () async {
    final storage = _GatedStorage()..releaseWrites();
    Get.put<LocalStorageService>(storage);

    await SettingsSyncResource().saveLocal({
      Platform.operatingSystem: <String, dynamic>{},
    });

    expect(storage.writes[LocalStorageService.kHiveDbVer], 10805);
    expect(storage.writes[LocalStorageService.kHiveDbVer], isA<int>());
  });

  test('远端数据库版本类型错误时失败而不是吞掉异常', () async {
    final storage = _GatedStorage()..releaseWrites();
    Get.put<LocalStorageService>(storage);

    await expectLater(
      SettingsSyncResource().saveLocal({
        Platform.operatingSystem: <String, dynamic>{},
        LocalStorageService.kHiveDbVer: '10816',
      }),
      throwsFormatException,
    );
  });

  test('解析远端设置时过滤凭据并校验已知字段类型', () {
    final resource = SettingsSyncResource();
    final validArchive = _settingsArchive({
      LocalStorageService.kHiveDbVer: 10816,
      Platform.operatingSystem: {
        LocalStorageService.kThemeMode: 2,
        LocalStorageService.kBilibiliCookie: 'remote-cookie',
      },
    });

    final data = resource.loadRemote(validArchive)!;
    final platform = data[Platform.operatingSystem] as Map<String, dynamic>;
    expect(platform, equals({LocalStorageService.kThemeMode: 2}));

    final invalidArchive = _settingsArchive({
      LocalStorageService.kHiveDbVer: 10816,
      Platform.operatingSystem: {
        LocalStorageService.kThemeMode: '2',
      },
    });
    expect(() => resource.loadRemote(invalidArchive), throwsFormatException);
  });
}

Archive _settingsArchive(Map<String, dynamic> data) {
  final bytes = utf8.encode(jsonEncode({'data': data}));
  return Archive()
    ..addFile(ArchiveFile('SimpleLive_Settings.json', bytes.length, bytes));
}

class _GatedStorage extends LocalStorageService {
  final Completer<void> _gate = Completer<void>();
  final Map<dynamic, dynamic> writes = <dynamic, dynamic>{};

  void releaseWrites() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<void> setValue<T>(dynamic key, T value) async {
    await _gate.future;
    writes[key] = value;
  }
}
