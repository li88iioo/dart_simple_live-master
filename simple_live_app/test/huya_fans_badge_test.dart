import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/chat/huya_fans_badge.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  test('仅从真实 fanBadge 数据创建粉丝牌', () {
    final badge = HuyaFansBadge.fromMessage(
      LiveMessage(
        type: LiveMessageType.chat,
        userName: '测试用户',
        message: '测试弹幕',
        data: const {
          'fanBadge': {'name': '楚河', 'level': 13},
        },
        color: LiveMessageColor.white,
      ),
    );

    expect(badge?.name, '楚河');
    expect(badge?.level, 13);

    expect(
      HuyaFansBadge.fromMessage(
        LiveMessage(
          type: LiveMessageType.chat,
          userName: '普通用户',
          message: '普通弹幕',
          color: LiveMessageColor.white,
        ),
      ),
      isNull,
    );
  });

  testWidgets('粉丝牌使用虎牙式等级与牌名分段底板', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: HuyaFansBadgeChip(
              badge: HuyaFansBadge(name: '很长的粉丝牌名称', level: 24),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );

    final chip = find.byKey(const ValueKey('huya-fans-badge-chip'));
    expect(chip, findsOneWidget);
    expect(tester.getSize(chip).width, lessThanOrEqualTo(92));
    expect(tester.getSize(chip).height, inInclusiveRange(18, 20));
    expect(
      find.byKey(const ValueKey('huya-fans-badge-paint')),
      findsOneWidget,
    );
    expect(find.text('24'), findsOneWidget);
    expect(find.text('很长的粉丝牌名称'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('短牌名按内容收缩而不是占满最大宽度', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: HuyaFansBadgeChip(
              badge: HuyaFansBadge(name: '楚河', level: 5),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(
      find.byKey(const ValueKey('huya-fans-badge-chip')),
    );
    expect(size.width, inInclusiveRange(44, 64));
  });
}
