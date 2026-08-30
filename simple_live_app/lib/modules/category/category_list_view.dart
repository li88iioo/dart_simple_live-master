import 'package:flutter/material.dart';
import 'package:flutter_easyrefresh/easy_refresh.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/category/category_list_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_core/simple_live_core.dart';

class CategoryListView extends StatelessWidget {
  const CategoryListView(this.tag, {super.key});

  final String tag;

  CategoryListController get controller =>
      Get.find<CategoryListController>(tag: tag);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.orientation == Orientation.portrait
        ? mediaQuery.viewPadding.bottom +
            SliveLayout.bottomDockHeight +
            SliveLayout.bottomDockGap +
            24
        : 24.0;

    return KeepAliveWrapper(
      child: ColoredBox(
        color: Colors.transparent,
        child: Obx(
          () => EasyRefresh(
            firstRefresh: true,
            controller: controller.easyRefreshController,
            onRefresh: controller.refreshData,
            header: MaterialHeader(
              completeDuration: const Duration(milliseconds: 400),
            ),
            child: ListView.builder(
              controller: controller.scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                SliveLayout.pageHorizontal,
                12,
                SliveLayout.pageHorizontal,
                bottomPadding,
              ),
              itemCount: controller.list.length,
              itemBuilder: (context, index) {
                final category = controller.list[index];
                return Obx(
                  () => _CategorySectionCard(
                    key: ValueKey('${controller.site.id}-${category.id}'),
                    category: category,
                    siteId: controller.site.id,
                    expanded: category.showAll.value,
                    onSubCategoryTap: (subCategory) {
                      AppNavigator.toCategoryDetail(
                        site: controller.site,
                        category: subCategory,
                      );
                    },
                    onToggleExpanded: category.toggleExpanded,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CategorySectionCard extends StatelessWidget {
  const _CategorySectionCard({
    super.key,
    required this.category,
    required this.siteId,
    required this.expanded,
    required this.onSubCategoryTap,
    required this.onToggleExpanded,
  });

  final AppLiveCategory category;
  final String siteId;
  final bool expanded;
  final ValueChanged<LiveSubCategory> onSubCategoryTap;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = colors.platform(siteId);
    final visibleChildren = category.visibleChildren;
    final cardColor = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.075 : 0.045),
      colors.glassBase,
    );

    return SliveGlassSurface(
      variant: SliveGlassVariant.panel,
      radius: SliveRadii.panel,
      enableBackdropBlur: false,
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CategorySectionHeader(
            title: category.name,
            count: category.children.length,
            accent: accent,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columnCount = _resolveColumnCount(
                context,
                constraints.maxWidth,
              );
              const spacing = 8.0;
              final tileWidth =
                  (constraints.maxWidth - spacing * (columnCount - 1)) /
                      columnCount;

              return Wrap(
                spacing: spacing,
                runSpacing: 12,
                children: visibleChildren
                    .map(
                      (subCategory) => SizedBox(
                        width: tileWidth,
                        child: _SubCategoryTile(
                          key: ValueKey(subCategory.id),
                          category: subCategory,
                          accent: accent,
                          onTap: () => onSubCategoryTap(subCategory),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          if (category.canExpand) ...[
            const SizedBox(height: 14),
            _ExpandCategoryButton(
              expanded: expanded,
              remainingCount: category.remainingCount,
              accent: accent,
              onTap: onToggleExpanded,
            ),
          ],
        ],
      ),
    );
  }

  int _resolveColumnCount(BuildContext context, double availableWidth) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final needsAccessibleLayout = textScale > 1.15;
    final canFitFiveIcons = availableWidth >= 282;

    if (needsAccessibleLayout || !canFitFiveIcons) {
      return 4;
    }
    if (availableWidth >= 900) {
      return 10;
    }
    if (availableWidth >= 720) {
      return 8;
    }
    if (availableWidth >= 560) {
      return 6;
    }
    return 5;
  }
}

class _CategorySectionHeader extends StatelessWidget {
  const _CategorySectionHeader({
    required this.title,
    required this.count,
    required this.accent,
  });

  final String title;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 6,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SliveRadii.pill),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: 0.96),
                accent.withValues(alpha: 0.58),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: colors.glassStrong.withValues(
              alpha: isDark ? 0.34 : 0.58,
            ),
            borderRadius: BorderRadius.circular(SliveRadii.pill),
            border: Border.all(
              color: colors.glassBorder.withValues(
                alpha: isDark ? 0.12 : 0.48,
              ),
            ),
          ),
          child: Text(
            '$count 项',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _SubCategoryTile extends StatelessWidget {
  const _SubCategoryTile({
    super.key,
    required this.category,
    required this.accent,
    required this.onTap,
  });

  final LiveSubCategory category;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconFill = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.10 : 0.065),
      colors.glassStrong.withValues(alpha: isDark ? 0.74 : 0.88),
    );

    return Semantics(
      button: true,
      label: '${category.name}分类',
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(SliveRadii.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SliveRadii.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: iconFill,
                    borderRadius: BorderRadius.circular(SliveRadii.control),
                    border: Border.all(
                      color: colors.glassBorder.withValues(
                        alpha: isDark ? 0.13 : 0.52,
                      ),
                    ),
                  ),
                  child: NetImage(
                    category.pic ?? '',
                    width: 44,
                    height: 44,
                    borderRadius: 13,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                        height: 1.16,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandCategoryButton extends StatelessWidget {
  const _ExpandCategoryButton({
    required this.expanded,
    required this.remainingCount,
    required this.accent,
    required this.onTap,
  });

  final bool expanded;
  final int remainingCount;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final label = expanded ? '收起' : '显示全部';

    return Semantics(
      button: true,
      expanded: expanded,
      label: expanded ? '收起${remainingCount + 15}个分类' : '显示全部分类',
      child: SizedBox(
        width: double.infinity,
        height: SliveLayout.minimumTouchTarget,
        child: CustomPaint(
          foregroundPainter: _DashedPillBorderPainter(
            color: Color.lerp(
              colors.textTertiary,
              accent,
              isDark ? 0.36 : 0.24,
            )!
                .withValues(alpha: isDark ? 0.52 : 0.60),
          ),
          child: Material(
            color: colors.glassStrong.withValues(
              alpha: isDark ? 0.18 : 0.34,
            ),
            borderRadius: BorderRadius.circular(SliveRadii.pill),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(SliveRadii.pill),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (!expanded) ...[
                    const SizedBox(width: 5),
                    Text(
                      '+$remainingCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: accent.withValues(
                              alpha: isDark ? 0.90 : 0.82,
                            ),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration:
                        reduceMotion ? Duration.zero : SliveMotion.selection,
                    curve: SliveMotion.standard,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: colors.textTertiary,
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

class _DashedPillBorderPainter extends CustomPainter {
  const _DashedPillBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashLength = 5.0;
    const gapLength = 4.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          Radius.circular(size.height / 2),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final dashEnd = distance + dashLength < metric.length
            ? distance + dashLength
            : metric.length;
        canvas.drawPath(metric.extractPath(distance, dashEnd), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPillBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
