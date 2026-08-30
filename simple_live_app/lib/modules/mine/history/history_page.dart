import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/mine/history/history_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_icon_button.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';

class HistoryPage extends GetView<HistoryController> {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    var columnCount = mediaQuery.size.width ~/ 500;
    if (columnCount < 1) columnCount = 1;
    if (columnCount > 4) columnCount = 4;

    return SlivePageScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 68,
        leadingWidth: 68,
        leading: Align(
          child: SliveGlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: '返回',
            onPressed: () => Get.back(),
          ),
        ),
        titleSpacing: 0,
        title: Text(
          '观看记录',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: context.sliveColors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.28,
              ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SliveGlassIconButton(
              icon: Icons.delete_sweep_outlined,
              tooltip: '清空观看记录',
              onPressed: controller.clean,
            ),
          ),
        ],
      ),
      body: PageGridView(
        padding: EdgeInsets.fromLTRB(
          SliveLayout.pageHorizontal,
          8,
          SliveLayout.pageHorizontal,
          mediaQuery.viewPadding.bottom + 24,
        ),
        mainAxisSpacing: 10,
        crossAxisSpacing: SliveLayout.gridGap,
        crossAxisCount: columnCount,
        pageController: controller,
        firstRefresh: true,
        showPageLoadding: true,
        showPCRefreshButton: false,
        itemBuilder: (_, index) {
          final item = controller.list[index];
          final site = Sites.allSites[item.siteId]!;
          return Dismissible(
            key: ValueKey(item.id),
            direction: DismissDirection.endToStart,
            background: _DismissBackground(
              label: '删除',
              color: context.sliveColors.danger,
            ),
            confirmDismiss: (_) => Utils.showAlertDialog(
              '确定要删除此记录吗?',
              title: '删除记录',
            ),
            onDismissed: (_) => controller.removeItem(item),
            child: _HistoryCard(
              item: item,
              site: site,
              onTap: () => AppNavigator.toLiveRoomDetail(
                site: site,
                roomId: item.roomId,
              ),
              onLongPress: () async {
                final result = await Utils.showAlertDialog(
                  '确定要删除此记录吗?',
                  title: '删除记录',
                );
                if (result) controller.removeItem(item);
              },
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.site,
    required this.onTap,
    required this.onLongPress,
  });

  final History item;
  final Site site;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final platformColor = colors.platform(site.id);

    return SliveGlassSurface(
      variant: SliveGlassVariant.card,
      radius: SliveRadii.card,
      enableBackdropBlur: false,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: platformColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: platformColor.withValues(alpha: 0.14),
                ),
              ),
              child: NetImage(
                item.face,
                width: 50,
                height: 50,
                borderRadius: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.18,
                        ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _PlatformBadge(site: site, color: platformColor),
                      Text(
                        Utils.parseTime(item.updateTime),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textTertiary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textTertiary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge({required this.site, required this.color});

  final Site site;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(SliveRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            site.logo,
            width: 15,
            height: 15,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 5),
          Text(
            site.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Color.lerp(color, context.sliveColors.textPrimary, .3),
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(SliveRadii.card),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_outline_rounded, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
