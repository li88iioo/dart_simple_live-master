import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
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

  static HuyaNobleBadge? fromMessage(LiveMessage message) {
    if (message.type != LiveMessageType.vipEnter || message.data is! Map) {
      return null;
    }
    final data = message.data as Map;
    final name = data['nobleName']?.toString().trim() ?? '';
    final rawLevel = data['nobleLevel'];
    final level = rawLevel is num
        ? rawLevel.toInt()
        : int.tryParse(rawLevel?.toString() ?? '') ?? 0;
    if (name.isEmpty || level <= 0) return null;
    return HuyaNobleBadge(name: name, level: level);
  }
}

class HuyaNobleBadgeChip extends StatelessWidget {
  const HuyaNobleBadgeChip({
    super.key,
    required this.badge,
    required this.fontSize,
  });

  final HuyaNobleBadge badge;
  final double fontSize;

  Color _accent() {
    return switch (badge.level) {
      <= 1 => const Color(0xFF6F839A),
      2 => const Color(0xFF4F8B82),
      3 => const Color(0xFF806EA3),
      4 => const Color(0xFFA16A78),
      5 => const Color(0xFFAA783A),
      _ => const Color(0xFFA45F3E),
    };
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = context.sliveColors;
    final accent = _accent();
    final height = (fontSize + 3).clamp(17.0, 20.0).toDouble();
    final markSize = (height - 4).clamp(12.0, 15.0).toDouble();
    final labelSize = (fontSize - 2).clamp(10.0, 12.0).toDouble();
    final textColor = Color.lerp(accent, themeColors.textSecondary, 0.18)!;

    return Semantics(
      label: '虎牙爵位 ${badge.name}',
      child: SizedBox(
        key: const ValueKey('huya-noble-badge-chip'),
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              key: const ValueKey('huya-noble-badge-mark'),
              size: Size.square(markSize),
              painter: _HuyaNobleMarkPainter(accent: accent),
            ),
            const SizedBox(width: 3.5),
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.15,
              child: Text(
                badge.name,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: textColor,
                  fontSize: labelSize,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HuyaNobleMarkPainter extends CustomPainter {
  const _HuyaNobleMarkPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final side = size.shortestSide * 0.62;
    final rect = Rect.fromCenter(center: center, width: side, height: side);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.7853981633974483);
    canvas.translate(-center.dx, -center.dy);

    final jewel = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.shortestSide * 0.14),
    );
    canvas.drawRRect(
      jewel,
      Paint()..color = accent.withValues(alpha: 0.13),
    );
    canvas.drawRRect(
      jewel,
      Paint()
        ..color = accent.withValues(alpha: 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      size.shortestSide * 0.105,
      Paint()..color = accent.withValues(alpha: 0.86),
    );
  }

  @override
  bool shouldRepaint(covariant _HuyaNobleMarkPainter oldDelegate) {
    return oldDelegate.accent != accent;
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
            const WidgetSpan(child: SizedBox(width: 6)),
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
