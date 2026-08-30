import 'package:flutter/material.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';

class SettingsCard extends StatelessWidget {
  final Widget child;

  const SettingsCard({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return SliveGlassSurface(
      variant: SliveGlassVariant.panel,
      child: child,
    );
  }
}
