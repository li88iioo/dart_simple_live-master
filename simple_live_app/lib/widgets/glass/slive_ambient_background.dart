import 'dart:math' as math;
import 'dart:ui';

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
    final materials = context.sliveMaterials;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliveAmbientScope(
      child: RepaintBoundary(
        child: Stack(
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
                    math.max(260.0, math.min(shortest * 0.82, 620)).toDouble();
                final blur =
                    materials.mode == SliveGlassMode.clear ? 58.0 : 44.0;
                final opacityScale = isDark ? 0.42 : 1.0;

                return IgnorePointer(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -blobSize * 0.42,
                        left: -blobSize * 0.28,
                        child: _AmbientBlob(
                          size: blobSize,
                          blur: blur,
                          color: colors.ambientPink.withValues(
                            alpha: 0.20 * opacityScale,
                          ),
                        ),
                      ),
                      Positioned(
                        top: blobSize * 0.08,
                        right: -blobSize * 0.40,
                        child: _AmbientBlob(
                          size: blobSize * 0.94,
                          blur: blur,
                          color: colors.ambientBlue.withValues(
                            alpha: 0.18 * opacityScale,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -blobSize * 0.46,
                        left: blobSize * 0.08,
                        child: _AmbientBlob(
                          size: blobSize * 1.06,
                          blur: blur,
                          color: Color.lerp(
                            colors.ambientOrange,
                            colors.ambientAccent,
                            0.18,
                          )!
                              .withValues(alpha: 0.18 * opacityScale),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  const _AmbientBlob({
    required this.size,
    required this.blur,
    required this.color,
  });

  final double size;
  final double blur;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
              stops: const [0, 1],
            ),
          ),
        ),
      ),
    );
  }
}
