import 'package:flutter/material.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';

class SlivePlatformTabBar extends StatelessWidget {
  const SlivePlatformTabBar({
    super.key,
    required this.controller,
    required this.sites,
  });

  final TabController controller;
  final List<Site> sites;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.sliveColors;
    final materials = context.sliveMaterials;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final selectedIndex = controller.index.clamp(0, sites.length - 1);
        final activeColor = colors.platform(sites[selectedIndex].id);
        return SizedBox(
          height: 44,
          child: SliveGlassSurface(
            variant: SliveGlassVariant.pill,
            enableBackdropBlur: true,
            radius: SliveRadii.pill,
            child: TabBar(
              controller: controller,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.all(4),
              labelPadding: const EdgeInsets.symmetric(horizontal: 11),
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: colors.glassStrong.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.18
                      : 0.86,
                ),
                borderRadius: BorderRadius.circular(SliveRadii.pill),
                border: Border.all(
                  color: colors.glassBorder.withValues(
                    alpha: materials.borderOpacity * 0.78,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.12),
                    blurRadius: 14,
                    spreadRadius: -5,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              dividerColor: Colors.transparent,
              splashBorderRadius: BorderRadius.circular(SliveRadii.pill),
              overlayColor: WidgetStatePropertyAll(
                activeColor.withValues(alpha: 0.06),
              ),
              labelColor: Color.lerp(
                activeColor,
                colors.textPrimary,
                0.16,
              ),
              unselectedLabelColor: colors.textSecondary,
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              tabs: sites
                  .map(
                    (site) => Tab(
                      height: 34,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            site.logo,
                            width: 18,
                            height: 18,
                            filterQuality: FilterQuality.medium,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            site.name,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        );
      },
    );
  }
}
