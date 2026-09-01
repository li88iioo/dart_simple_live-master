import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/live_room/chat/huya_chat_badge_style.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_core/simple_live_core.dart';

@immutable
class HuyaNobleBadge {
  const HuyaNobleBadge({
    required this.name,
    required this.level,
  });

  final String name;
  final int level;

  static const Map<int, String> _names = <int, String>{
    1: '剑士',
    2: '骑士',
    3: '领主',
    4: '公爵',
    5: '君王',
    6: '帝皇',
  };

  static HuyaNobleBadge? fromMessage(LiveMessage message) {
    if ((message.type != LiveMessageType.chat &&
            message.type != LiveMessageType.vipEnter) ||
        message.data is! Map) {
      return null;
    }
    final data = message.data as Map;
    final rawLevel = data['nobleLevel'];
    final level = rawLevel is num
        ? rawLevel.toInt()
        : int.tryParse(rawLevel?.toString() ?? '') ?? 0;
    final canonicalName = _names[level];
    if (canonicalName == null) return null;
    final serverName = data['nobleName']?.toString().trim() ?? '';
    return HuyaNobleBadge(
      name: serverName.isEmpty ? canonicalName : serverName,
      level: level,
    );
  }
}

/// 与粉丝牌共用垂直基线的 16dp 爵位方印。
///
/// 小尺寸、无描边、无阴影，只用固定爵位色和单字表达身份，避免尖底盾牌在
/// 14dp 弹幕正文中显得像额外贴入的游戏图标。
class HuyaNobleBadgeChip extends StatelessWidget {
  const HuyaNobleBadgeChip({
    super.key,
    required this.badge,
    required this.fontSize,
  });

  final HuyaNobleBadge badge;
  final double fontSize;

  String _emblemText() {
    return switch (badge.level) {
      1 => '剑',
      2 => '骑',
      3 => '领',
      4 => '公',
      5 => '君',
      6 => '帝',
      _ => '爵',
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = huyaNobleBadgePaletteForLevel(badge.level);
    final foreground = huyaNobleBadgeForegroundForLevel(badge.level);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final size = (16 * textScale.clamp(1.0, 1.08)).clamp(16.0, 17.3);
    final emblemFontSize = (fontSize - 4.8).clamp(8.8, 9.4).toDouble();

    return Semantics(
      label: '虎牙爵位 ${badge.name}',
      child: Tooltip(
        message: '虎牙爵位 · ${badge.name}',
        waitDuration: const Duration(milliseconds: 500),
        child: SizedBox.square(
          key: const ValueKey('huya-noble-badge-chip'),
          dimension: size,
          child: CustomPaint(
            key: const ValueKey('huya-noble-badge-paint'),
            painter: _HuyaNobleSealPainter(palette: palette),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.08,
              child: Center(
                child: Text(
                  _emblemText(),
                  key: const ValueKey('huya-noble-badge-glyph'),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: foreground,
                    fontSize: emblemFontSize,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HuyaNobleSealPainter extends CustomPainter {
  const _HuyaNobleSealPainter({required this.palette});

  final HuyaChatBadgePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final seal = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(3.5),
    );
    canvas.drawRRect(
      seal,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.bodyStart,
            palette.bodyEnd,
          ],
        ).createShader(bounds),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height * 0.42),
        const Radius.circular(2.6),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant _HuyaNobleSealPainter oldDelegate) {
    return oldDelegate.palette != palette;
  }
}

class HuyaVipEnterMessage extends StatelessWidget {
  const HuyaVipEnterMessage({
    super.key,
    required this.message,
    required this.fontSize,
    required this.bubbleStyle,
  });

  final LiveMessage message;
  final double fontSize;
  final bool bubbleStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final nobleBadge = HuyaNobleBadge.fromMessage(message);
    final content = Text.rich(
      key: const ValueKey('huya-vip-enter-content'),
      TextSpan(
        children: [
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
          TextSpan(
            text: message.userName,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: fontSize,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: ' 进入直播间',
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: fontSize,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (!bubbleStyle) {
      return Semantics(
        label: '${message.userName}进入直播间',
        child: content,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: SliveGlassSurface(
            key: const ValueKey('huya-vip-enter-bubble'),
            variant: SliveGlassVariant.card,
            radius: 16,
            enableBackdropBlur: false,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: content,
          ),
        ),
      ],
    );
  }
}
