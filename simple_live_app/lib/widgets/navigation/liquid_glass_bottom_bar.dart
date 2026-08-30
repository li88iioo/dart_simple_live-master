import 'dart:ui';

import 'package:flutter/material.dart';

class LiquidGlassBottomBarDestination {
  const LiquidGlassBottomBarDestination({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;
}

class LiquidGlassBottomBar extends StatelessWidget {
  const LiquidGlassBottomBar({
    super.key,
    required this.destinations,
    required this.selectedValue,
    required this.onDestinationSelected,
  });

  final List<LiquidGlassBottomBarDestination> destinations;
  final int selectedValue;
  final ValueChanged<int> onDestinationSelected;

  static const double _height = 68;
  static const BorderRadius _borderRadius = BorderRadius.all(
    Radius.circular(_height / 2),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final glassStart = colorScheme.surface.withValues(
      alpha: isDark ? 0.68 : 0.82,
    );
    final glassEnd = colorScheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.50 : 0.64,
    );
    final outlineColor = Colors.white.withValues(
      alpha: isDark ? 0.18 : 0.72,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: _height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: _borderRadius,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.10 : 0.08,
                  ),
                  blurRadius: 24,
                  spreadRadius: -8,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.24 : 0.09,
                  ),
                  blurRadius: 18,
                  spreadRadius: -10,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: _borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _borderRadius,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [glassStart, glassEnd],
                    ),
                    border: Border.all(color: outlineColor, width: 0.8),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        top: 1,
                        left: 20,
                        right: 20,
                        height: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(
                                  alpha: isDark ? 0.30 : 0.82,
                                ),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: destinations
                            .map(
                              (destination) => Expanded(
                                child: _LiquidGlassNavigationItem(
                                  key: ValueKey(destination.value),
                                  destination: destination,
                                  selected: selectedValue == destination.value,
                                  onTap: () => onDestinationSelected(
                                    destination.value,
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
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

class _LiquidGlassNavigationItem extends StatefulWidget {
  const _LiquidGlassNavigationItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final LiquidGlassBottomBarDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_LiquidGlassNavigationItem> createState() =>
      _LiquidGlassNavigationItemState();
}

class _LiquidGlassNavigationItemState
    extends State<_LiquidGlassNavigationItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = colorScheme.onSurfaceVariant.withValues(
      alpha: isDark ? 0.72 : 0.66,
    );
    final activeColor = Color.lerp(
      colorScheme.primary,
      colorScheme.onSurface,
      isDark ? 0.12 : 0.06,
    )!;

    return Semantics(
      container: true,
      button: true,
      selected: widget.selected,
      label: widget.destination.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(
              begin: widget.selected ? 1 : 0,
              end: widget.selected ? 1 : 0,
            ),
            builder: (context, selectionProgress, child) {
              final foregroundColor = Color.lerp(
                inactiveColor,
                activeColor,
                selectionProgress,
              )!;

              return AnimatedScale(
                scale: _pressed ? 0.965 : 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IgnorePointer(
                      child: Opacity(
                        opacity: selectionProgress,
                        child: Transform.scale(
                          scale: 0.88 + (0.12 * selectionProgress),
                          child: FractionallySizedBox(
                            widthFactor: 0.82,
                            heightFactor: 0.76,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                gradient: RadialGradient(
                                  center: const Alignment(-0.35, -0.85),
                                  radius: 1.25,
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: isDark ? 0.22 : 0.76,
                                    ),
                                    colorScheme.primary.withValues(
                                      alpha: isDark ? 0.24 : 0.17,
                                    ),
                                    colorScheme.primary.withValues(
                                      alpha: isDark ? 0.10 : 0.07,
                                    ),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: isDark ? 0.16 : 0.58,
                                  ),
                                  width: 0.7,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(
                                      alpha: isDark ? 0.16 : 0.11,
                                    ),
                                    blurRadius: 14,
                                    spreadRadius: -5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, -selectionProgress),
                      child: Transform.scale(
                        scale: 0.98 + (0.04 * selectionProgress),
                        child: SizedBox(
                          height: 52,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.destination.icon,
                                size: 23,
                                color: foregroundColor,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.destination.label,
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: foregroundColor,
                                  fontSize: 10.5,
                                  height: 1.15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
