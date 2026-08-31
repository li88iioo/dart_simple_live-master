import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';

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

/// 移动端悬浮导航 Dock。
class LiquidGlassBottomBar extends StatelessWidget {
  const LiquidGlassBottomBar({
    super.key,
    required this.destinations,
    required this.selectedValue,
    required this.onDestinationSelected,
  });

  static const Duration transitionDuration = Duration(milliseconds: 110);

  final List<LiquidGlassBottomBarDestination> destinations;
  final int selectedValue;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SafeArea(
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
            child: _LiquidNavigationSurface(
              radius: SliveRadii.dock,
              child: Row(
                children: destinations
                    .map(
                      (destination) => Expanded(
                        child: _LiquidGlassNavigationItem(
                          key: ValueKey<int>(destination.value),
                          destination: destination,
                          selected: selectedValue == destination.value,
                          onTap: () => onDestinationSelected(destination.value),
                          axis: Axis.horizontal,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// PC 端主界面四项导航。
///
/// 与移动 Dock 一样只通过图标和文字颜色表达选中态，不再叠加移动色块。
class LiquidGlassSideRail extends StatelessWidget {
  const LiquidGlassSideRail({
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
    return RepaintBoundary(
      child: SizedBox(
        width: 88,
        child: _LiquidNavigationSurface(
          radius: 0,
          clipBehavior: Clip.hardEdge,
          child: SafeArea(
            right: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: destinations
                  .map(
                    (destination) => SizedBox(
                      height: 68,
                      width: double.infinity,
                      child: _LiquidGlassNavigationItem(
                        key: ValueKey<int>(destination.value),
                        destination: destination,
                        selected: selectedValue == destination.value,
                        onTap: () => onDestinationSelected(destination.value),
                        axis: Axis.vertical,
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

/// 导航容器只保留中性玻璃底色和轻边界。
///
/// 强调色不会进入 Dock/侧栏本体，避免更换强调色后整个导航被染色。
class _LiquidNavigationSurface extends StatelessWidget {
  const _LiquidNavigationSurface({
    required this.child,
    required this.radius,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final double radius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.sliveColors;
    final materials = context.sliveMaterials;
    final isDark = theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);
    final topOpacity = materials.panelOpacity;
    final bottomOpacity = materials.panelOpacity - (isDark ? 0.035 : 0.055);

    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.glassStrong.withValues(alpha: topOpacity),
              colors.glassBase.withValues(alpha: bottomOpacity),
            ],
          ),
          border: Border.all(
            color: colors.glassBorder.withValues(
              alpha: materials.borderOpacity * (isDark ? 0.58 : 0.76),
            ),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      ),
    );
  }
}

/// 选中态不绘制任何背景实体。Dock 本身已经承担玻璃层级，额外色块会在
/// 浅色与动态强调色下显得突兀；仅保留短促的图标/文字色彩过渡。
class _LiquidGlassNavigationItem extends StatefulWidget {
  const _LiquidGlassNavigationItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.axis,
  });

  final LiquidGlassBottomBarDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final Axis axis;

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
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final selectionDuration =
        reduceMotion ? Duration.zero : LiquidGlassBottomBar.transitionDuration;
    final pressDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 80);
    final inactiveColor = colors.textSecondary.withValues(
      alpha: isDark ? 0.80 : 0.74,
    );
    final activeColor = theme.colorScheme.primary;
    final selectedIconColor = Color.lerp(
      colors.textPrimary,
      activeColor,
      isDark ? 0.78 : 0.72,
    )!;
    final selectedLabelColor = selectedIconColor;
    final isVertical = widget.axis == Axis.vertical;
    final visualWidth = isVertical ? 62.0 : 68.0;

    return Semantics(
      container: true,
      button: true,
      selected: widget.selected,
      label: widget.destination.label,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: Center(
            child: AnimatedScale(
              scale: _pressed ? 0.98 : 1,
              duration: pressDuration,
              curve: SliveMotion.standard,
              child: SizedBox(
                width: visualWidth,
                height: 52,
                child: TweenAnimationBuilder<double>(
                  duration: selectionDuration,
                  curve: SliveMotion.standard,
                  tween: Tween<double>(
                    begin: widget.selected ? 1 : 0,
                    end: widget.selected ? 1 : 0,
                  ),
                  builder: (context, selectionProgress, child) {
                    final iconColor = Color.lerp(
                      inactiveColor,
                      selectedIconColor,
                      selectionProgress,
                    )!;
                    final labelColor = Color.lerp(
                      inactiveColor,
                      selectedLabelColor,
                      selectionProgress,
                    )!;

                    return Center(
                      child: SizedBox(
                        height: 48,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.destination.icon,
                              size: isVertical ? 22.5 : 22,
                              color: iconColor,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.destination.label,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: labelColor,
                                fontSize: 10.5,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.06,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
