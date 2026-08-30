import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/mine/account/bilibili/qr_login_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('二维码轮询保持单定时器并在后台暂停', () {
    final controller = BiliBiliQRLoginController()
      ..qrcodeKey = 'test-key'
      ..qrStatus.value = QRStatus.unscanned;
    addTearDown(controller.onClose);

    controller.startPoll();
    final firstTimer = controller.timer;
    controller.startPoll();

    expect(firstTimer, isNotNull);
    expect(firstTimer?.isActive, isTrue);
    expect(identical(controller.timer, firstTimer), isTrue);

    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(firstTimer?.isActive, isFalse);
    expect(controller.timer, isNull);

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(controller.timer?.isActive, isTrue);
  });

  test('失效二维码恢复前台时不会重新启动轮询', () {
    final controller = BiliBiliQRLoginController()
      ..qrcodeKey = 'expired-key'
      ..qrStatus.value = QRStatus.expired;
    addTearDown(controller.onClose);

    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(controller.timer, isNull);
  });

  test('登录 Cookie 解析会过滤空值和无效响应头', () {
    expect(BiliBiliQRLoginController.extractLoginCookies(null), isEmpty);
    expect(
      BiliBiliQRLoginController.extractLoginCookies([
        '',
        'invalid-cookie',
        'SESSDATA=test-value; Path=/; HttpOnly',
        ' bili_jct=csrf-value; Path=/',
      ]),
      ['SESSDATA=test-value', 'bili_jct=csrf-value'],
    );
  });
}
