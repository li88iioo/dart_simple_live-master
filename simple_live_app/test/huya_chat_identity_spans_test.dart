import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/chat/huya_chat_badge_style.dart';
import 'package:simple_live_app/modules/live_room/chat/huya_chat_identity_spans.dart';
import 'package:simple_live_app/modules/live_room/chat/huya_fans_badge.dart';
import 'package:simple_live_app/modules/live_room/chat/huya_noble_badge.dart';
import 'package:simple_live_core/simple_live_core.dart';

LiveMessage _chatMessage(Map<String, dynamic> data) {
  return LiveMessage(
    type: LiveMessageType.chat,
    userName: '测试用户',
    message: '测试弹幕',
    data: data,
    color: LiveMessageColor.white,
  );
}

void main() {
  test('普通聊天身份顺序固定为粉丝牌、爵位、用户名间距', () {
    final spans = buildHuyaChatIdentitySpans(
      message: _chatMessage({
        'fanBadge': {'name': '明星团', 'level': 28},
        'nobleName': '公爵',
        'nobleLevel': 4,
      }),
      fontSize: 14,
    );

    expect(spans, hasLength(4));
    expect((spans[0] as WidgetSpan).child, isA<HuyaFansBadgeChip>());
    expect(
      ((spans[1] as WidgetSpan).child as SizedBox).width,
      HuyaChatBadgeStyle.badgeToBadgeGap,
    );
    expect((spans[2] as WidgetSpan).child, isA<HuyaNobleBadgeChip>());
    expect(
      ((spans[3] as WidgetSpan).child as SizedBox).width,
      HuyaChatBadgeStyle.badgeToTextGap,
    );
  });

  test('缺少任一身份牌时不保留空白占位', () {
    final noBadge = buildHuyaChatIdentitySpans(
      message: _chatMessage(const {}),
      fontSize: 14,
    );
    expect(noBadge, isEmpty);

    final nobleOnly = buildHuyaChatIdentitySpans(
      message: _chatMessage(const {
        'nobleName': '领主',
        'nobleLevel': 3,
      }),
      fontSize: 14,
    );
    expect(nobleOnly, hasLength(2));
    expect((nobleOnly.first as WidgetSpan).child, isA<HuyaNobleBadgeChip>());
  });
}
