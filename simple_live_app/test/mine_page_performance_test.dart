import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/mine/mine_page.dart';

void main() {
  test('我的页账号大卡不启用滚动实时背景模糊', () {
    expect(MinePage.profileCardBackdropBlurEnabled, isFalse);
  });
}
