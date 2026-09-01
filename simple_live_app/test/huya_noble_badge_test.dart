import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/chat/huya_chat_badge_style.dart';
import 'package:simple_live_app/modules/live_room/chat/huya_noble_badge.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_core/simple_live_core.dart';

LiveMessage _entryMessage({
  bool withNoble = true,
  LiveMessageType type = LiveMessageType.vipEnter,
  String? nobleName = '剑士',
  int nobleLevel = 1,
}) {
  return LiveMessage(
    type: type,
    userName: '测试用户',
    message: '测试用户 进入直播间',
    data: withNoble
        ? {
            if (nobleName != null) 'nobleName': nobleName,
            'nobleLevel': nobleLevel,
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

  test('普通聊天同样读取真实爵位，缺少名称时按等级补全', () {
    final chatBadge = HuyaNobleBadge.fromMessage(
      _entryMessage(
        type: LiveMessageType.chat,
        nobleName: null,
        nobleLevel: 4,
      ),
    );
    expect(chatBadge?.name, '公爵');
    expect(chatBadge?.level, 4);
  });

  test('爵位固定使用土绿蓝红紫金六级配色', () {
    expect(huyaNobleBadgePaletteForLevel(1).bodyStart, const Color(0xFF806B59));
    expect(huyaNobleBadgePaletteForLevel(2).bodyStart, const Color(0xFF417D6F));
    expect(huyaNobleBadgePaletteForLevel(3).bodyStart, const Color(0xFF46769D));
    expect(huyaNobleBadgePaletteForLevel(4).bodyStart, const Color(0xFF9C524F));
    expect(huyaNobleBadgePaletteForLevel(5).bodyStart, const Color(0xFF70598F));
    expect(huyaNobleBadgePaletteForLevel(6).bodyStart, const Color(0xFFA17D32));
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
    expect(
      find.byKey(const ValueKey('huya-noble-badge-paint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('huya-noble-badge-glyph')),
      findsOneWidget,
    );
    expect(find.text('剑'), findsOneWidget);
    expect(find.text('剑士'), findsNothing);
    expect(tester.getSize(badgeFinder).width, inInclusiveRange(16, 17.3));
    expect(tester.getSize(badgeFinder).height, inInclusiveRange(16, 17.3));
    expect(find.byType(SliveGlassSurface), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('紧凑爵位方印只显示单字且未知爵位安全回退', (tester) async {
    Future<void> pumpBadge(String name, int level) async {
      await tester.pumpWidget(
        _testApp(
          HuyaNobleBadgeChip(
            badge: HuyaNobleBadge(name: name, level: level),
            fontSize: 14,
          ),
        ),
      );
    }

    await pumpBadge('骑士', 2);
    expect(find.text('骑'), findsOneWidget);
    expect(find.text('骑士'), findsNothing);

    await pumpBadge('领主', 3);
    expect(find.text('领'), findsOneWidget);
    expect(find.text('领主'), findsNothing);

    await pumpBadge('星耀使者', 9);
    expect(find.text('爵'), findsOneWidget);
    expect(find.text('星耀使者'), findsNothing);
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
