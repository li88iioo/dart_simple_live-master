import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';

abstract final class SettingsTileStyle {
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(16, 9, 10, 9);

  static RoundedRectangleBorder shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(SliveRadii.control),
  );

  static TextStyle? title(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: context.sliveColors.textPrimary,
          fontWeight: FontWeight.w600,
          height: 1.2,
        );
  }

  static TextStyle? subtitle(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.sliveColors.textTertiary,
          height: 1.25,
        );
  }

  static Widget trailing(
    BuildContext context, {
    String? value,
    Widget? leading,
    double maxWidth = 168,
  }) {
    final colors = context.sliveColors;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading,
            const SizedBox(width: 6),
          ],
          if (value != null)
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          if (value != null || leading != null) const SizedBox(width: 5),
          Icon(
            Icons.chevron_right_rounded,
            color: colors.textTertiary.withValues(alpha: 0.82),
            size: 21,
          ),
        ],
      ),
    );
  }
}
