import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/chat/danmaku_shield_matcher.dart';

void main() {
  test('同时支持普通关键词和正则规则', () {
    final matcher = DanmakuShieldMatcher();
    final rules = ['广告', r'/\d{4}-\d{4}/'];

    expect(matcher.match('这是广告内容', rules), '广告');
    expect(matcher.match('联系方式 1234-5678', rules), r'/\d{4}-\d{4}/');
    expect(matcher.match('正常弹幕', rules), isNull);
  });

  test('非法正则只编译时报告一次并安全忽略', () {
    final matcher = DanmakuShieldMatcher();
    final invalidRules = <String>[];
    final rules = ['/[/'];

    expect(
      matcher.match(
        '第一条',
        rules,
        onInvalidRegex: invalidRules.add,
      ),
      isNull,
    );
    expect(
      matcher.match(
        '第二条',
        rules,
        onInvalidRegex: invalidRules.add,
      ),
      isNull,
    );
    expect(invalidRules, ['/[/']);
  });

  test('规则列表变化后重新编译', () {
    final matcher = DanmakuShieldMatcher();

    expect(matcher.match('虎牙', ['斗鱼']), isNull);
    expect(matcher.match('虎牙', ['虎牙']), '虎牙');
  });
}
