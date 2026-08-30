import 'package:flutter/material.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';

/// 首页、分类与搜索页共用的平台切换栏。
///
/// 选中层只使用 opacity/scale 微动效，不绘制阴影，也不启用实时
/// BackdropFilter。点击时显式使用 150ms TabController 动画，避免 Flutter
/// 默认较长的页签过渡让重型列表显得拖沓。
class SlivePlatformTabBar extends StatefulWidget {
  const SlivePlatformTabBar({
    super.key,
    required this.controller,
    required this.sites,
    this.trailing,
    this.animationDuration = transitionDuration,
  });

  static const Duration transitionDuration = Duration(milliseconds: 150);

  final TabController controller;
  final List<Site> sites;
  final Widget? trailing;
  final Duration animationDuration;

  @override
  State<SlivePlatformTabBar> createState() => _SlivePlatformTabBarState();
}

class _SlivePlatformTabBarState extends State<SlivePlatformTabBar> {
  late int _selectedIndex = _resolveIndex();

  int _resolveIndex() {
    if (widget.sites.isEmpty) return 0;
    return widget.controller.index.clamp(0, widget.sites.length - 1);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant SlivePlatformTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
    }
    _selectedIndex = _resolveIndex();
  }

  void _handleControllerChange() {
    final nextIndex = _resolveIndex();
    if (!mounted || nextIndex == _selectedIndex) return;
    setState(() => _selectedIndex = nextIndex);
  }

  void _select(int index) {
    if (index == _selectedIndex || index < 0 || index >= widget.sites.length) {
      return;
    }
    widget.controller.animateTo(
      index,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : widget.animationDuration,
      curve: SliveMotion.standard,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sites.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = context.sliveColors;
    final isDark = theme.brightness == Brightness.dark;

    final bar = SizedBox(
      height: 44,
      child: SliveGlassSurface(
        variant: SliveGlassVariant.pill,
        enableBackdropBlur: false,
        showShadow: false,
        shadowColor: Colors.transparent,
        radius: SliveRadii.pill,
        clipBehavior: Clip.hardEdge,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: List<Widget>.generate(widget.sites.length, (index) {
              final site = widget.sites[index];
              final selected = index == _selectedIndex;
              final activeColor = colors.platform(site.id);

              return Padding(
                padding: EdgeInsets.only(
                  right: index == widget.sites.length - 1 ? 0 : 2,
                ),
                child: _PlatformTabButton(
                  key: ValueKey<String>(site.id),
                  site: site,
                  selected: selected,
                  activeColor: activeColor,
                  selectedFill: Color.alphaBlend(
                    activeColor.withValues(alpha: isDark ? 0.17 : 0.10),
                    colors.glassStrong.withValues(
                      alpha: isDark ? 0.76 : 0.94,
                    ),
                  ),
                  selectedBorder: activeColor.withValues(
                    alpha: isDark ? 0.34 : 0.24,
                  ),
                  duration: widget.animationDuration,
                  onTap: () => _select(index),
                ),
              );
            }, growable: false),
          ),
        ),
      ),
    );

    if (widget.trailing == null) return bar;

    return Row(
      children: [
        Expanded(child: bar),
        const SizedBox(width: 10),
        widget.trailing!,
      ],
    );
  }
}

class _PlatformTabButton extends StatefulWidget {
  const _PlatformTabButton({
    super.key,
    required this.site,
    required this.selected,
    required this.activeColor,
    required this.selectedFill,
    required this.selectedBorder,
    required this.duration,
    required this.onTap,
  });

  final Site site;
  final bool selected;
  final Color activeColor;
  final Color selectedFill;
  final Color selectedBorder;
  final Duration duration;
  final VoidCallback onTap;

  @override
  State<_PlatformTabButton> createState() => _PlatformTabButtonState();
}

class _PlatformTabButtonState extends State<_PlatformTabButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.sliveColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : widget.duration;
    final foreground = widget.selected
        ? Color.lerp(widget.activeColor, colors.textPrimary, 0.18)!
        : colors.textSecondary;

    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            widget.site.logo,
            width: 18,
            height: 18,
            filterQuality: FilterQuality.low,
          ),
          const SizedBox(width: 6),
          Text(
            widget.site.name,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.site.name,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: AnimatedScale(
            scale: _pressed ? 0.975 : 1,
            duration: reduceMotion ? Duration.zero : SliveMotion.press,
            curve: SliveMotion.standard,
            child: TweenAnimationBuilder<double>(
              duration: duration,
              curve: SliveMotion.standard,
              tween: Tween<double>(
                begin: widget.selected ? 1 : 0,
                end: widget.selected ? 1 : 0,
              ),
              child: label,
              builder: (context, progress, child) {
                return SizedBox(
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: progress,
                            child: Transform.scale(
                              scale: 0.94 + (0.06 * progress),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: widget.selectedFill,
                                  borderRadius:
                                      BorderRadius.circular(SliveRadii.pill),
                                  border: Border.all(
                                    color: widget.selectedBorder,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, -0.5 * progress),
                        child: child,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
