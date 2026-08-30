import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/models/sync_client_info_model.dart';
import 'package:simple_live_app/services/local_sync_protocol.dart';

void main() {
  test('解析当前协议设备信息并保留能力列表', () {
    final info = SyncClientInfoModel.fromJson(const {
      'type': 'android',
      'name': '测试设备',
      'version': '1.8.14',
      'address': '192.168.1.8',
      'port': 23234,
      'protocolVersion': 2,
      'minimumProtocolVersion': 2,
      'authRequired': true,
      'capabilities': [
        'pairing-code',
        'bounded-payload',
        'follow-tag-bundle',
        'follow-tombstones',
      ],
    });

    expect(info.protocolVersion, 2);
    expect(info.minimumProtocolVersion, 2);
    expect(info.authRequired, isTrue);
    expect(info.capabilities, contains('pairing-code'));
    expect(
      () => LocalSyncProtocol.ensureCompatible(
        peerVersion: info.protocolVersion,
        peerMinimumVersion: info.minimumProtocolVersion,
        authRequired: info.authRequired,
        capabilities: info.capabilities,
      ),
      returnsNormally,
    );
  });

  test('缺少协议字段的旧设备按协议 1 处理并被明确拒绝', () {
    final info = SyncClientInfoModel.fromJson(const {
      'type': 'android',
      'name': '旧设备',
      'version': '1.7.0',
      'address': '192.168.1.9',
      'port': 23234,
    });

    expect(info.protocolVersion, 1);
    expect(
      () => LocalSyncProtocol.ensureCompatible(
        peerVersion: info.protocolVersion,
        peerMinimumVersion: info.minimumProtocolVersion,
        authRequired: info.authRequired,
        capabilities: info.capabilities,
      ),
      throwsA(
        isA<LocalSyncProtocolException>().having(
          (error) => error.message,
          'message',
          contains('对方设备'),
        ),
      ),
    );
  });

  test('拒绝要求更高协议版本的设备', () {
    expect(
      () => LocalSyncProtocol.ensureCompatible(
        peerVersion: 3,
        peerMinimumVersion: 3,
        authRequired: true,
        capabilities: LocalSyncProtocol.requiredCapabilities,
      ),
      throwsA(
        isA<LocalSyncProtocolException>().having(
          (error) => error.message,
          'message',
          contains('当前设备'),
        ),
      ),
    );
  });

  test('拒绝未启用安全配对的设备', () {
    expect(
      () => LocalSyncProtocol.ensureCompatible(
        peerVersion: 2,
        peerMinimumVersion: 2,
        authRequired: false,
        capabilities: LocalSyncProtocol.requiredCapabilities,
      ),
      throwsA(
        isA<LocalSyncProtocolException>().having(
          (error) => error.message,
          'message',
          contains('安全配对'),
        ),
      ),
    );
  });

  test('拒绝缺少必要能力声明的协议 2 设备', () {
    expect(
      () => LocalSyncProtocol.ensureCompatible(
        peerVersion: 2,
        peerMinimumVersion: 2,
        authRequired: true,
        capabilities: const ['pairing-code'],
      ),
      throwsA(
        isA<LocalSyncProtocolException>().having(
          (error) => error.message,
          'message',
          contains('缺少必要'),
        ),
      ),
    );
  });

  test('设备信息缺少必需字段时给出格式错误', () {
    expect(
      () => SyncClientInfoModel.fromJson(const {
        'type': 'android',
        'name': '缺少地址',
        'version': '1.8.14',
        'port': 23234,
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
