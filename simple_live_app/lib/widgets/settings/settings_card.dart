import 'package:flutter/material.dart';
import 'package:simple_live_app/app/app_style.dart';

class SettingsCard extends StatelessWidget {
  final Widget child;
  const SettingsCard({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.withAlpha(25) : Colors.white,
        borderRadius: AppStyle.radius12,
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppStyle.radius12,
        child: child,
      ),
    );
  }
}
