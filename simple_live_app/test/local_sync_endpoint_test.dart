import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/local_sync_endpoint.dart';

void main() {
  group('LocalSyncEndpoint', () {
    test('接受常见局域网 IPv4 地址和自定义端口', () {
      const validInputs = <String, String>{
        '10.0.0.8': '10.0.0.8:23234',
        '172.16.0.8:24000': '172.16.0.8:24000',
        '172.31.255.254': '172.31.255.254:23234',
        '192.168.1.8': '192.168.1.8:23234',
        '169.254.10.8': '169.254.10.8:23234',
        '100.64.0.8': '100.64.0.8:23234',
        '127.0.0.1': '127.0.0.1:23234',
      };

      for (final entry in validInputs.entries) {
        final endpoint = LocalSyncEndpoint.parse(entry.key);
        expect('${endpoint.address}:${endpoint.port}', entry.value);
      }
    });

    test('规范解析无路径的 HTTP 地址', () {
      final endpoint = LocalSyncEndpoint.parse(
        'http://192.168.1.8:24000/',
      );

      expect(endpoint.address, '192.168.1.8');
      expect(endpoint.port, 24000);
      expect(
        endpoint.uriFor('/sync/follow').toString(),
        'http://192.168.1.8:24000/sync/follow',
      );
    });

    test('拒绝公网、主机名、注入式地址和非法端口', () {
      const invalidInputs = [
        '8.8.8.8',
        'example.com',
        'https://192.168.1.8:23234',
        '127.0.0.1@evil.example',
        'http://127.0.0.1@8.8.8.8:23234',
        '192.168.1.8/path',
        '192.168.1.8?next=8.8.8.8',
        '192.168.1.8#fragment',
        '192.168.1.8:0',
        '192.168.1.8:65536',
        '[fd00::1]:23234',
      ];

      for (final input in invalidInputs) {
        expect(
          () => LocalSyncEndpoint.parse(input),
          throwsA(isA<FormatException>()),
          reason: input,
        );
      }
    });
  });

  group('LocalSyncConnectionInput', () {
    test('解析二维码中的多个地址、端口和配对码', () {
      final value = Uri(
        scheme: 'simplelive',
        host: 'sync',
        queryParameters: const {
          'addresses': '192.168.1.8;10.0.0.8;192.168.1.8',
          'port': '24000',
          'code': '12345678',
        },
      ).toString();

      final parsed = LocalSyncConnectionInput.parse(value);

      expect(parsed.pairingCode, '12345678');
      expect(parsed.endpoints, hasLength(2));
      expect(
        parsed.endpoints.map((item) => item.displayAddress),
        ['192.168.1.8:24000', '10.0.0.8:24000'],
      );
    });

    test('地址自身端口优先于二维码默认端口', () {
      final value = Uri(
        scheme: 'simplelive',
        host: 'sync',
        queryParameters: const {
          'addresses': '192.168.1.8:25000;10.0.0.8',
          'port': '24000',
          'code': '12345678',
        },
      ).toString();

      final parsed = LocalSyncConnectionInput.parse(value);

      expect(parsed.endpoints[0].port, 25000);
      expect(parsed.endpoints[1].port, 24000);
    });

    test('拒绝二维码中的公网地址、非法配对码和非法端口', () {
      final invalidValues = [
        Uri(
          scheme: 'simplelive',
          host: 'sync',
          queryParameters: const {
            'addresses': '8.8.8.8',
            'code': '12345678',
          },
        ).toString(),
        Uri(
          scheme: 'simplelive',
          host: 'sync',
          queryParameters: const {
            'addresses': '192.168.1.8',
            'code': '1234',
          },
        ).toString(),
        Uri(
          scheme: 'simplelive',
          host: 'sync',
          queryParameters: const {
            'addresses': '192.168.1.8',
            'port': '65536',
            'code': '12345678',
          },
        ).toString(),
      ];

      for (final value in invalidValues) {
        expect(
          () => LocalSyncConnectionInput.parse(value),
          throwsA(isA<FormatException>()),
        );
      }
    });
  });
}
