import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';

class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.text,
    this.selected = false,
    this.onTap,
    this.indicatorColor,
    this.pulseIndicator = false,
  });

  final bool selected;
  final String text;
  final VoidCallback? onTap;
  final Color? indicatorColor;
  final bool pulseIndicator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.sliveColors;
    final materials = context.sliveMaterials;
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : SliveMotion.selection;
    final selectedFill = Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.055),
      colors.glassStrong.withValues(alpha: isDark ? 0.72 : 0.94),
    );
    final selectedBorder = colors.glassBorder.withValues(
      alpha: materials.borderOpacity * (isDark ? 0.68 : 0.90),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: text,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(SliveRadii.pill),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(SliveRadii.pill),
            child: AnimatedContainer(
              duration: duration,
              curve: SliveMotion.standard,
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? selectedFill : Colors.transparent,
                borderRadius: BorderRadius.circular(SliveRadii.pill),
                border: Border.all(
                  color: selected ? selectedBorder : Colors.transparent,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF8E7E6E).withValues(
                            alpha: isDark ? 0.10 : 0.075,
                          ),
                          blurRadius: 14,
                          spreadRadius: -6,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : const [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (indicatorColor != null) ...[
                    _FilterStatusDot(
                      color: indicatorColor!,
                      animate: pulseIndicator,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    text,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color:
                          selected ? colors.textPrimary : colors.textSecondary,
                      fontSize: 13,
                      height: 1,
                      letterSpacing: 0.02,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

class _FilterStatusDot extends StatefulWidget {
  const _FilterStatusDot({
    required this.color,
    required this.animate,
  });

  final Color color;
  final bool animate;

  @override
  State<_FilterStatusDot> createState() => _FilterStatusDotState();
}

class _FilterStatusDotState extends State<_FilterStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    lowerBound: 0,
    upperBound: 1,
  );
  bool _isAnimating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _FilterStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final shouldAnimate = widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (_isAnimating == shouldAnimate) return;
    _isAnimating = shouldAnimate;
    if (shouldAnimate) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.88),
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(dimension: 6),
    );

    if (!_isAnimating) {
      return SizedBox.square(
        dimension: 10,
        child: Center(child: dot),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      child: dot,
      builder: (context, child) {
        final progress = Curves.easeInOut.transform(_controller.value);
        return SizedBox.square(
          dimension: 10,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.18 * (1 - progress),
                child: Transform.scale(
                  scale: 0.8 + (progress * 0.75),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 10),
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.94 + (progress * 0.08),
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}
