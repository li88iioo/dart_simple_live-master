import 'package:flutter/material.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';

/// 首页、分类与搜索页共用的平台切换栏。
///
/// 所有平台共享同一个选中胶囊，胶囊直接跟随 [TabController.animation]
/// 在相邻项之间连续移动。各项使用统一宽度模型，避免移动端与桌面端因为
/// 文本测量或窗口宽度变化产生错位；空间不足时仍可横向滚动。
class SlivePlatformTabBar extends StatefulWidget {
  const SlivePlatformTabBar({
    super.key,
    required this.controller,
    required this.sites,
    this.trailing,
    this.animationDuration = transitionDuration,
  });

  static const Duration transitionDuration = Duration(milliseconds: 180);

  final TabController controller;
  final List<Site> sites;
  final Widget? trailing;
  final Duration animationDuration;

  @override
  State<SlivePlatformTabBar> createState() => _SlivePlatformTabBarState();
}

class _SlivePlatformTabBarState extends State<SlivePlatformTabBar> {
  static const double _barHeight = 44;
  static const double _capsuleHeight = 36;
  static const double _contentPadding = 4;
  static const double _itemGap = 2;
  static const double _minimumItemExtent = 92;
  static const double _maximumItemExtent = 112;

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
      curve: Curves.easeOutQuart,
    );
  }

  double _indicatorPosition({required bool reduceMotion}) {
    if (reduceMotion) return _selectedIndex.toDouble();
    final value = widget.controller.animation?.value;
    return (value ?? _selectedIndex.toDouble())
        .clamp(0.0, widget.sites.length - 1.0)
        .toDouble();
  }

  Color _platformFill({
    required BuildContext context,
    required int index,
  }) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final platformColor = colors.platform(widget.sites[index].id);

    return Color.alphaBlend(
      platformColor.withValues(alpha: isDark ? 0.17 : 0.105),
      colors.glassStrong.withValues(alpha: isDark ? 0.82 : 0.96),
    );
  }

  Color _indicatorFill(BuildContext context, double position) {
    final lowerIndex = position.floor().clamp(0, widget.sites.length - 1);
    final upperIndex = position.ceil().clamp(0, widget.sites.length - 1);
    if (lowerIndex == upperIndex) {
      return _platformFill(context: context, index: lowerIndex);
    }

    return Color.lerp(
      _platformFill(context: context, index: lowerIndex),
      _platformFill(context: context, index: upperIndex),
      position - lowerIndex,
    )!;
  }

  double _resolveItemExtent(double viewportWidth) {
    final gapWidth = _itemGap * (widget.sites.length - 1);
    final usableWidth = viewportWidth - (_contentPadding * 2) - gapWidth;
    final fittedExtent = usableWidth / widget.sites.length;

    // 手机宽度优先完整填满，避免分类页没有 trailing 时右侧出现大片空白；
    // 桌面宽屏限制单项宽度，并由外层将整组平台项居中。
    if (viewportWidth <= 600 && fittedExtent >= _minimumItemExtent) {
      return fittedExtent;
    }
    return fittedExtent
        .clamp(_minimumItemExtent, _maximumItemExtent)
        .toDouble();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sites.isEmpty) return const SizedBox.shrink();

    final bar = SizedBox(
      height: _barHeight,
      child: SliveGlassSurface(
        variant: SliveGlassVariant.pill,
        enableBackdropBlur: false,
        showShadow: false,
        shadowColor: Colors.transparent,
        radius: SliveRadii.pill,
        clipBehavior: Clip.hardEdge,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : (_maximumItemExtent * widget.sites.length) +
                    (_itemGap * (widget.sites.length - 1)) +
                    (_contentPadding * 2);
            final itemExtent = _resolveItemExtent(viewportWidth);
            final contentWidth = (itemExtent * widget.sites.length) +
                (_itemGap * (widget.sites.length - 1));
            final reduceMotion = MediaQuery.disableAnimationsOf(context);
            final animation = widget.controller.animation ?? widget.controller;

            final availableContentWidth =
                (viewportWidth - (_contentPadding * 2))
                    .clamp(0.0, double.infinity)
                    .toDouble();
            final trackWidth = contentWidth < availableContentWidth
                ? availableContentWidth
                : contentWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(_contentPadding),
              child: SizedBox(
                width: trackWidth,
                height: _capsuleHeight,
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: contentWidth,
                    height: _capsuleHeight,
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        final position = _indicatorPosition(
                          reduceMotion: reduceMotion,
                        );
                        final stride = itemExtent + _itemGap;
                        final indicatorFill = _indicatorFill(context, position);

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: RepaintBoundary(
                                child: Transform.translate(
                                  offset: Offset(position * stride, 0),
                                  child: _SharedSelectionCapsule(
                                    key: const ValueKey<String>(
                                      'slive-platform-shared-selection',
                                    ),
                                    width: itemExtent,
                                    height: _capsuleHeight,
                                    color: indicatorFill,
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: List<Widget>.generate(
                                widget.sites.length,
                                (index) {
                                  final site = widget.sites[index];
                                  final selectionProgress =
                                      (1 - (position - index).abs())
                                          .clamp(0.0, 1.0)
                                          .toDouble();

                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: index == widget.sites.length - 1
                                          ? 0
                                          : _itemGap,
                                    ),
                                    child: SizedBox(
                                      width: itemExtent,
                                      height: _capsuleHeight,
                                      child: _PlatformTabButton(
                                        key: ValueKey<String>(site.id),
                                        site: site,
                                        selected: index == _selectedIndex,
                                        selectionProgress: selectionProgress,
                                        activeColor:
                                            context.sliveColors.platform(
                                          site.id,
                                        ),
                                        onTap: () => _select(index),
                                      ),
                                    ),
                                  );
                                },
                                growable: false,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
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

class _SharedSelectionCapsule extends StatelessWidget {
  const _SharedSelectionCapsule({
    super.key,
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SliveRadii.pill),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                Colors.white.withValues(alpha: isDark ? 0.035 : 0.18),
                color,
              ),
              color,
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformTabButton extends StatefulWidget {
  const _PlatformTabButton({
    super.key,
    required this.site,
    required this.selected,
    required this.selectionProgress,
    required this.activeColor,
    required this.onTap,
  });

  final Site site;
  final bool selected;
  final double selectionProgress;
  final Color activeColor;
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
    final selectedForeground = Color.lerp(
      widget.activeColor,
      colors.textPrimary,
      0.24,
    )!;
    final foreground = Color.lerp(
      colors.textSecondary,
      selectedForeground,
      widget.selectionProgress,
    )!;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.site.name,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: _setPressed,
            borderRadius: BorderRadius.circular(SliveRadii.pill),
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: AnimatedScale(
              scale: _pressed ? 0.985 : 1,
              duration: reduceMotion ? Duration.zero : SliveMotion.press,
              curve: SliveMotion.standard,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      widget.site.logo,
                      width: 18,
                      height: 18,
                      filterQuality: FilterQuality.low,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.site.name,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
