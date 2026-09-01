import 'package:flutter/material.dart';
import 'package:simple_live_core/simple_live_core.dart';

@immutable
class HuyaFansBadge {
  const HuyaFansBadge({
    required this.name,
    required this.level,
  });

  final String name;
  final int level;

  static HuyaFansBadge? fromMessage(LiveMessage message) {
    final data = message.data;
    if (data is! Map) return null;
    final rawBadge = data['fanBadge'];
    if (rawBadge is! Map) return null;
    final name = rawBadge['name']?.toString().trim() ?? '';
    final level = switch (rawBadge['level']) {
      final int value => value,
      final num value => value.toInt(),
      final Object value => int.tryParse(value.toString()) ?? 0,
      null => 0,
    };
    if (name.isEmpty || level <= 0) return null;
    return HuyaFansBadge(name: name, level: level);
  }
}

/// 虎牙风格的紧凑粉丝牌。
///
/// 聊天消息只携带牌名与等级，官方定制底图需要额外资源请求。因此这里保留
/// 虎牙牌面的核心识别结构：左侧独立等级块、右侧牌名块、低圆角分段底板，
/// 同时避免普通胶囊和大面积玻璃背景挤压弹幕正文。
class HuyaFansBadgeChip extends StatelessWidget {
  const HuyaFansBadgeChip({
    super.key,
    required this.badge,
    required this.fontSize,
  });

  final HuyaFansBadge badge;
  final double fontSize;

  _HuyaFansBadgePalette _paletteForLevel() {
    if (badge.level >= 26) {
      return const _HuyaFansBadgePalette(
        level: Color(0xFFB64C3D),
        nameStart: Color(0xFFD96948),
        nameEnd: Color(0xFFE58B55),
      );
    }
    if (badge.level >= 21) {
      return const _HuyaFansBadgePalette(
        level: Color(0xFF9A5A32),
        nameStart: Color(0xFFC17B3E),
        nameEnd: Color(0xFFD9A259),
      );
    }
    if (badge.level >= 16) {
      return const _HuyaFansBadgePalette(
        level: Color(0xFF9E496F),
        nameStart: Color(0xFFBE5F8A),
        nameEnd: Color(0xFFD77BA2),
      );
    }
    if (badge.level >= 11) {
      return const _HuyaFansBadgePalette(
        level: Color(0xFF6556A7),
        nameStart: Color(0xFF7B69BE),
        nameEnd: Color(0xFF9A87D2),
      );
    }
    if (badge.level >= 6) {
      return const _HuyaFansBadgePalette(
        level: Color(0xFF367F8A),
        nameStart: Color(0xFF4697A0),
        nameEnd: Color(0xFF69B2B8),
      );
    }
    return const _HuyaFansBadgePalette(
      level: Color(0xFF416E9E),
      nameStart: Color(0xFF5685B5),
      nameEnd: Color(0xFF78A1C8),
    );
  }

  double _resolveWidth(BuildContext context, double labelFontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: badge.name,
        style: TextStyle(
          fontSize: labelFontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: 58);
    final levelWidth = badge.level >= 10 ? 27.0 : 23.0;
    return (levelWidth + painter.width + 10).clamp(44.0, 92.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForLevel();
    final height = (fontSize + 4).clamp(18.0, 20.0).toDouble();
    final labelFontSize = (fontSize - 3).clamp(9.5, 11.0).toDouble();
    final levelFontSize = (labelFontSize - 0.4).clamp(9.0, 10.5).toDouble();
    final levelWidth = badge.level >= 10 ? 27.0 : 23.0;
    final width = _resolveWidth(context, labelFontSize);

    return Semantics(
      label: '粉丝牌 ${badge.name} ${badge.level}级',
      child: SizedBox(
        key: const ValueKey('huya-fans-badge-chip'),
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          clipBehavior: Clip.hardEdge,
          child: CustomPaint(
            key: const ValueKey('huya-fans-badge-paint'),
            painter: _HuyaFansBadgePainter(
              palette: palette,
              levelWidth: levelWidth,
            ),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.15,
              child: Row(
                children: [
                  SizedBox(
                    width: levelWidth,
                    child: Center(
                      child: Text(
                        '${badge.level}',
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.98),
                          fontSize: levelFontSize,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, right: 5),
                      child: Text(
                        badge.name,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontSize: labelFontSize,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class _HuyaFansBadgePalette {
  const _HuyaFansBadgePalette({
    required this.level,
    required this.nameStart,
    required this.nameEnd,
  });

  final Color level;
  final Color nameStart;
  final Color nameEnd;
}

class _HuyaFansBadgePainter extends CustomPainter {
  const _HuyaFansBadgePainter({
    required this.palette,
    required this.levelWidth,
  });

  final _HuyaFansBadgePalette palette;
  final double levelWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final radius = Radius.circular(4);
    final outer = RRect.fromRectAndRadius(bounds, radius);
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = LinearGradient(
          colors: [palette.nameStart, palette.nameEnd],
        ).createShader(bounds),
    );

    final levelPath = Path()
      ..moveTo(0, 0)
      ..lineTo(levelWidth + 3, 0)
      ..lineTo(levelWidth, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(levelPath, Paint()..color = palette.level);

    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 0.55
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bounds.deflate(0.35),
        const Radius.circular(3.7),
      ),
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant _HuyaFansBadgePainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.levelWidth != levelWidth;
  }
}
