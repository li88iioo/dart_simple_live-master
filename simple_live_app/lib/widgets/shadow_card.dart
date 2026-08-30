import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';

class ShadowCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final Function()? onTap;
  final Function()? onLongPress;

  const ShadowCard({
    required this.child,
    this.radius = SliveRadii.card,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliveGlassSurface(
      radius: radius,
      onTap: onTap == null ? null : () => onTap?.call(),
      onLongPress: onLongPress == null ? null : () => onLongPress?.call(),
      child: child,
    );
  }
}
