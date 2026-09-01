import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/chat/huya_noble_badge.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_core/simple_live_core.dart';

LiveMessage _entryMessage({bool withNoble = true}) {
  return LiveMessage(
    type: LiveMessageType.vipEnter,
    userName: '测试用户',
    message: '测试用户 进入直播间',
    data: withNoble
        ? const {
            'nobleName': '剑士',
            'nobleLevel': 1,
          }
        : const {'kind': 'vipEnter'},
    color: LiveMessageColor.white,
  );
}

Widget _testApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 360, child: child),
      ),
    ),
  );
}

void main() {
  test('只从服务端真实爵位字段创建徽标', () {
    final badge = HuyaNobleBadge.fromMessage(_entryMessage());
    expect(badge?.name, '剑士');
    expect(badge?.level, 1);

    expect(
      HuyaNobleBadge.fromMessage(_entryMessage(withNoble: false)),
      isNull,
    );
  });

  testWidgets('关闭气泡时进场消息是普通聊天行且不显示通用图标', (tester) async {
    await tester.pumpWidget(
      _testApp(
        HuyaVipEnterMessage(
          message: _entryMessage(),
          fontSize: 14,
          bubbleStyle: false,
        ),
      ),
    );

    expect(
        find.byKey(const ValueKey('huya-vip-enter-content')), findsOneWidget);
    final badgeFinder = find.byKey(
      const ValueKey('huya-noble-badge-chip'),
    );
    expect(badgeFinder, findsOneWidget);
    expect(find.byKey(const ValueKey('huya-noble-badge-mark')), findsOneWidget);
    expect(find.text('剑士'), findsOneWidget);
    expect(tester.getSize(badgeFinder).width, lessThanOrEqualTo(48));
    expect(tester.getSize(badgeFinder).height, lessThanOrEqualTo(20));
    expect(find.byType(SliveGlassSurface), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('无真实爵位时只显示进场文字不伪造皇冠或徽标', (tester) async {
    await tester.pumpWidget(
      _testApp(
        HuyaVipEnterMessage(
          message: _entryMessage(withNoble: false),
          fontSize: 14,
          bubbleStyle: false,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('huya-noble-badge-chip')), findsNothing);
    expect(find.byType(Icon), findsNothing);
    expect(find.textContaining('测试用户'), findsOneWidget);
  });

  testWidgets('开启聊天气泡后进场消息使用同一气泡容器', (tester) async {
    await tester.pumpWidget(
      _testApp(
        HuyaVipEnterMessage(
          message: _entryMessage(),
          fontSize: 14,
          bubbleStyle: true,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('huya-vip-enter-bubble')), findsOneWidget);
    expect(find.byType(SliveGlassSurface), findsOneWidget);
  });
}
