import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';

class AppEmptyWidget extends StatelessWidget {
  const AppEmptyWidget({this.onRefresh, super.key});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight =
            constraints.hasBoundedHeight ? constraints.maxHeight : null;
        final compact = availableHeight != null && availableHeight < 360;
        final outerPadding = compact ? 8.0 : 20.0;
        final visualExtent = availableHeight == null
            ? 168.0
            : (availableHeight * 0.36).clamp(72.0, 168.0).toDouble();
        final minContentHeight = availableHeight == null
            ? 0.0
            : (availableHeight - outerPadding * 2).clamp(0.0, double.infinity);

        return SingleChildScrollView(
          primary: false,
          padding: EdgeInsets.all(outerPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minContentHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: SliveGlassSurface(
                  variant: SliveGlassVariant.panel,
                  enableBackdropBlur: false,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    compact ? 8 : 12,
                    20,
                    compact ? 12 : 18,
                  ),
                  onTap: onRefresh,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LottieBuilder.asset(
                        'assets/lotties/empty.json',
                        width: 168,
                        height: visualExtent,
                        fit: BoxFit.contain,
                        repeat: false,
                        animate: !reduceMotion,
                      ),
                      Text(
                        '这里什么都没有',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (onRefresh != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          '轻触重新加载',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.textTertiary,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
