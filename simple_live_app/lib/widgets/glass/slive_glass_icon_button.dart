import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';

class SliveGlassIconButton extends StatelessWidget {
  const SliveGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = SliveLayout.minimumTouchTarget,
    this.iconSize = 21,
    this.enableBackdropBlur = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool enableBackdropBlur;

  @override
  Widget build(BuildContext context) {
    Widget button = SliveGlassSurface(
      variant: SliveGlassVariant.pill,
      enableBackdropBlur: enableBackdropBlur,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      onTap: onPressed,
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: onPressed == null
              ? context.sliveColors.textTertiary
              : context.sliveColors.textPrimary,
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
