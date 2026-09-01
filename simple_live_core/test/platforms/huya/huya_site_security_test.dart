import 'package:simple_live_core/src/platforms/huya/huya_site.dart';
import 'package:test/test.dart';

void main() {
  test('Huya WUP endpoint uses TLS', () {
    expect(Uri.parse(HuyaSite.wupUrl).scheme, 'https');
  });

  test('新建 WUP 客户端会读取账号管理刚更新的 HYSDK_UA', () {
    final originalUa = HuyaSite.HYSDK_UA;
    addTearDown(() => HuyaSite.HYSDK_UA = originalUa);
    final site = HuyaSite();

    HuyaSite.HYSDK_UA = 'HYSDK(test-one)';
    final firstClient = site.tupClient;
    expect(firstClient.headers['User-Agent'], 'HYSDK(test-one)');

    HuyaSite.HYSDK_UA = 'HYSDK(test-two)';
    final secondClient = site.tupClient;
    expect(secondClient.headers['User-Agent'], 'HYSDK(test-two)');
    expect(identical(firstClient, secondClient), isFalse);
  });
}
