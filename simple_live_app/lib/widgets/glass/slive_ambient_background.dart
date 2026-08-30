import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';

class SliveAmbientScope extends InheritedWidget {
  const SliveAmbientScope({
    super.key,
    required super.child,
  });

  static bool maybeHasAmbient(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SliveAmbientScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(SliveAmbientScope oldWidget) => false;
}

class SliveAmbientBackground extends StatelessWidget {
  const SliveAmbientBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliveAmbientScope(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 环境层单独缓存；滚动内容重绘时不再连带重绘大面积光晕。
          RepaintBoundary(
            child: _AmbientLayer(
              colors: colors,
              isDark: isDark,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AmbientLayer extends StatelessWidget {
  const _AmbientLayer({
    required this.colors,
    required this.isDark,
  });

  final SliveColorTokens colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.backgroundStart,
                colors.backgroundBase,
                colors.backgroundEnd,
              ],
              stops: const [0, 0.52, 1],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final shortest = math.min(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final blobSize =
                math.max(280.0, math.min(shortest * 0.92, 680)).toDouble();
            final opacityScale = isDark ? 0.42 : 1.0;

            return IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -blobSize * 0.44,
                    left: -blobSize * 0.30,
                    child: _AmbientBlob(
                      size: blobSize,
                      color: colors.ambientPink.withValues(
                        alpha: 0.18 * opacityScale,
                      ),
                    ),
                  ),
                  Positioned(
                    top: blobSize * 0.06,
                    right: -blobSize * 0.42,
                    child: _AmbientBlob(
                      size: blobSize * 0.96,
                      color: colors.ambientBlue.withValues(
                        alpha: 0.16 * opacityScale,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -blobSize * 0.48,
                    left: blobSize * 0.06,
                    child: _AmbientBlob(
                      size: blobSize * 1.08,
                      color: Color.lerp(
                        colors.ambientOrange,
                        colors.ambientAccent,
                        0.18,
                      )!
                          .withValues(alpha: 0.16 * opacityScale),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  const _AmbientBlob({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: color.a * 0.34),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.46, 1],
          ),
        ),
      ),
    );
  }
}
