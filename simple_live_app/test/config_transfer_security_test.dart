import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:simple_live_app/modules/settings/other/other_settings_controller.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

void main() {
  group('配置传输安全', () {
    late Directory tempDirectory;
    late LocalStorageService storage;

    setUpAll(() async {
      Get.testMode = true;
      tempDirectory = await Directory.systemTemp.createTemp(
        'simple_live_config_security_test_',
      );
      Hive.init(tempDirectory.path);
      storage = Get.put(LocalStorageService());
      await storage.init();
    });

    setUp(() async {
      await storage.settingsBox.clear();
      await storage.shieldBox.clear();
    });

    tearDownAll(() async {
      await Hive.close();
      Get.reset();
      await tempDirectory.delete(recursive: true);
    });

    test('导出只包含允许设置，不包含凭据、迁移版本和未知字段', () {
      final document = ConfigTransferCodec.createDocument(
        platform: 'android',
        time: 1,
        settings: {
          LocalStorageService.kThemeMode: 1,
          LocalStorageService.kBilibiliCookie: 'cookie-secret',
          LocalStorageService.kWebDAVUri: 'https://user:pass@example.test',
          LocalStorageService.kWebDAVPassword: 'password-secret',
          LocalStorageService.kHiveDbVer: 10816,
          LocalStorageService.kFollowSnapshot: {'private': true},
          'UnknownInternalKey': 'internal',
        },
        shield: {'旧键': '关键词'},
      );

      final config = document['config'] as Map<String, dynamic>;
      expect(config, equals({LocalStorageService.kThemeMode: 1}));
      expect(document['shield'], equals({'关键词': '关键词'}));
      expect(document.toString(), isNot(contains('cookie-secret')));
      expect(document.toString(), isNot(contains('password-secret')));
    });

    test('导入过滤旧版文件中的凭据和内部迁移版本', () {
      final payload = ConfigTransferCodec.decode({
        'type': 'simple_live',
        'platform': 'android',
        'version': 1,
        'time': 1,
        'config': {
          LocalStorageService.kThemeMode: 2,
          LocalStorageService.kBilibiliCookie: 'remote-cookie',
          LocalStorageService.kWebDAVPassword: 'remote-password',
          LocalStorageService.kHiveDbVer: 1,
        },
        'shield': <String, String>{},
      });

      expect(payload.config, equals({LocalStorageService.kThemeMode: 2}));
    });

    test('应用导入配置时保留凭据、迁移版本和未知内部字段', () async {
      await storage.settingsBox.putAll({
        LocalStorageService.kThemeMode: 0,
        LocalStorageService.kDanmuEnable: true,
        LocalStorageService.kBilibiliCookie: 'local-cookie',
        LocalStorageService.kWebDAVPassword: 'local-password',
        LocalStorageService.kHiveDbVer: 10816,
        'FutureInternalKey': 'keep',
      });
      await storage.shieldBox.putAll({'old': 'old'});

      await ConfigTransferCodec.apply(
        storage,
        const ConfigTransferPayload(
          platform: 'android',
          config: {LocalStorageService.kThemeMode: 2},
          shield: {'new': 'new'},
        ),
      );

      expect(storage.settingsBox.get(LocalStorageService.kThemeMode), 2);
      expect(storage.settingsBox.containsKey(LocalStorageService.kDanmuEnable),
          isFalse);
      expect(
        storage.settingsBox.get(LocalStorageService.kBilibiliCookie),
        'local-cookie',
      );
      expect(
        storage.settingsBox.get(LocalStorageService.kWebDAVPassword),
        'local-password',
      );
      expect(storage.settingsBox.get(LocalStorageService.kHiveDbVer), 10816);
      expect(storage.settingsBox.get('FutureInternalKey'), 'keep');
      expect(storage.shieldBox.toMap(), equals({'new': 'new'}));
    });

    test('导入拒绝已知设置项的错误类型', () {
      expect(
        () => ConfigTransferCodec.decode({
          'type': 'simple_live',
          'platform': 'android',
          'version': ConfigTransferCodec.currentVersion,
          'time': 1,
          'config': {LocalStorageService.kThemeMode: '2'},
          'shield': <String, String>{},
        }),
        throwsFormatException,
      );
    });
  });

  group('LocalStorage 日志脱敏', () {
    test('敏感键不返回原始值', () {
      expect(
        LocalStorageService.logValue(
          LocalStorageService.kBilibiliCookie,
          'cookie-secret',
        ),
        '<redacted>',
      );
      expect(
        LocalStorageService.logValue('accessToken', 'token-secret'),
        '<redacted>',
      );
    });

    test('普通长值会截断且换行被转义', () {
      final logged = LocalStorageService.logValue(
        LocalStorageService.kSiteSort,
        'prefix\n${List.filled(300, 'a').join()}',
      );

      expect(logged, contains(r'\n'));
      expect(logged, isNot(contains('\n')));
      expect(logged.length, lessThan(220));
      expect(logged, contains('chars)'));
    });
  });
}
