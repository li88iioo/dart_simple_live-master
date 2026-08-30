import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';

class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({
    this.errorMsg = '',
    this.onRefresh,
    super.key,
  });

  final VoidCallback? onRefresh;
  final String errorMsg;

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
        final visualHeight = availableHeight == null
            ? 150.0
            : (availableHeight * 0.34).clamp(64.0, 150.0).toDouble();
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
                constraints: const BoxConstraints(maxWidth: 380),
                child: SliveGlassSurface(
                  variant: SliveGlassVariant.panel,
                  enableBackdropBlur: false,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    compact ? 8 : 12,
                    20,
                    compact ? 12 : 18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LottieBuilder.asset(
                        'assets/lotties/error.json',
                        width: 176,
                        height: visualHeight,
                        fit: BoxFit.contain,
                        repeat: false,
                        animate: !reduceMotion,
                      ),
                      Text(
                        errorMsg.isEmpty ? '加载失败' : errorMsg,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (onRefresh != null) ...[
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('重新加载'),
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
