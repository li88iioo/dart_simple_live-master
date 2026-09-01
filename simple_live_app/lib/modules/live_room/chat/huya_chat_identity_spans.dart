import 'package:flutter/material.dart';
import 'package:simple_live_app/modules/live_room/chat/huya_chat_badge_style.dart';
import 'package:simple_live_app/modules/live_room/chat/huya_fans_badge.dart';
import 'package:simple_live_app/modules/live_room/chat/huya_noble_badge.dart';
import 'package:simple_live_core/simple_live_core.dart';

/// 构建普通聊天行的身份前缀，固定顺序为：粉丝牌 → 爵位 → 用户名。
List<InlineSpan> buildHuyaChatIdentitySpans({
  required LiveMessage message,
  required double fontSize,
}) {
  final fansBadge = HuyaFansBadge.fromMessage(message);
  final nobleBadge = HuyaNobleBadge.fromMessage(message);
  return <InlineSpan>[
    if (fansBadge != null) ...[
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: HuyaFansBadgeChip(
          badge: fansBadge,
          fontSize: fontSize,
        ),
      ),
      WidgetSpan(
        child: SizedBox(
          width: nobleBadge == null
              ? HuyaChatBadgeStyle.badgeToTextGap
              : HuyaChatBadgeStyle.badgeToBadgeGap,
        ),
      ),
    ],
    if (nobleBadge != null) ...[
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: HuyaNobleBadgeChip(
          badge: nobleBadge,
          fontSize: fontSize,
        ),
      ),
      const WidgetSpan(
        child: SizedBox(width: HuyaChatBadgeStyle.badgeToTextGap),
      ),
    ],
  ];
}
