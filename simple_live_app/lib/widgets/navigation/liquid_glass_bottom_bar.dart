import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          14,
          0,
          14,
          SliveLayout.bottomDockGap,
        ),
        child: SizedBox(
          height: SliveLayout.bottomDockHeight,
          child: SliveGlassSurface(
            variant: SliveGlassVariant.dock,
            radius: SliveRadii.dock,
            enableBackdropBlur: true,
            child: Row(
              children: destinations
                  .map(
                    (destination) => Expanded(
                      child: _LiquidGlassNavigationItem(
                        key: ValueKey(destination.value),
                        destination: destination,
                        selected: selectedValue == destination.value,
                        onTap: () => onDestinationSelected(destination.value),
                      ),
                    ),
                  )
                  .toList(growable: false),
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
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.sliveColors;
    final materials = context.sliveMaterials;
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final selectionDuration =
        reduceMotion ? Duration.zero : SliveMotion.selection;
    final pressDuration = reduceMotion ? Duration.zero : SliveMotion.press;
    final inactiveColor = colors.textSecondary.withValues(
      alpha: isDark ? 0.82 : 0.76,
    );
    final activeColor = Color.lerp(
      theme.colorScheme.primary,
      colors.textPrimary,
      isDark ? 0.12 : 0.08,
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
            duration: selectionDuration,
            curve: SliveMotion.standard,
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
                duration: pressDuration,
                curve: SliveMotion.standard,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IgnorePointer(
                      child: Opacity(
                        opacity: selectionProgress,
                        child: Transform.scale(
                          scale: 0.90 + (0.10 * selectionProgress),
                          child: FractionallySizedBox(
                            widthFactor: 0.82,
                            heightFactor: 0.74,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(SliveRadii.pill),
                                gradient: RadialGradient(
                                  center: const Alignment(-0.30, -0.85),
                                  radius: 1.3,
                                  colors: [
                                    colors.glassStrong.withValues(
                                      alpha: isDark ? 0.20 : 0.78,
                                    ),
                                    theme.colorScheme.primary.withValues(
                                      alpha: isDark ? 0.22 : 0.15,
                                    ),
                                    theme.colorScheme.primary.withValues(
                                      alpha: isDark ? 0.08 : 0.05,
                                    ),
                                  ],
                                ),
                                border: Border.all(
                                  color: colors.glassBorder.withValues(
                                    alpha: materials.borderOpacity *
                                        (isDark ? 0.66 : 0.82),
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: isDark ? 0.14 : 0.09,
                                    ),
                                    blurRadius: 16,
                                    spreadRadius: -6,
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
                        scale: 0.98 + (0.035 * selectionProgress),
                        child: SizedBox(
                          height: 52,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.destination.icon,
                                size: 22.5,
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
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.08,
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
