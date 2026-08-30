import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';

class DesktopRefreshButton extends StatelessWidget {
  const DesktopRefreshButton({
    required this.refreshing,
    this.onPressed,
    super.key,
  });

  final bool refreshing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: !refreshing && onPressed != null,
      label: refreshing ? '正在刷新' : '刷新',
      child: SliveGlassSurface(
        variant: SliveGlassVariant.pill,
        radius: SliveRadii.pill,
        enableBackdropBlur: false,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        onTap: refreshing ? null : onPressed,
        child: Center(
          child: AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : SliveMotion.selection,
            child: refreshing
                ? const SizedBox.square(
                    key: ValueKey('loading'),
                    dimension: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    key: const ValueKey('refresh'),
                    size: 21,
                    color: context.sliveColors.textPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}
