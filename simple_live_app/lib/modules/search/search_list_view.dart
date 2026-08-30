import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/search/search_list_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/live_room_card.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';
import 'package:simple_live_core/simple_live_core.dart';

class SearchListView extends StatelessWidget {
  const SearchListView(this.tag, {super.key});

  final String tag;

  SearchListController get controller =>
      Get.find<SearchListController>(tag: tag);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    var roomColumnCount = mediaQuery.size.width ~/ 200;
    if (roomColumnCount < 2) roomColumnCount = 2;
    if (roomColumnCount > 6) roomColumnCount = 6;

    var anchorColumnCount = mediaQuery.size.width ~/ 480;
    if (anchorColumnCount < 1) anchorColumnCount = 1;
    if (anchorColumnCount > 4) anchorColumnCount = 4;

    final listPadding = EdgeInsets.fromLTRB(
      SliveLayout.pageHorizontal,
      10,
      SliveLayout.pageHorizontal,
      mediaQuery.viewPadding.bottom + 24,
    );

    return KeepAliveWrapper(
      child: Obx(
        () => controller.searchMode.value == 0
            ? PageGridView(
                pageController: controller,
                padding: listPadding,
                firstRefresh: false,
                mainAxisSpacing: SliveLayout.gridGap,
                crossAxisSpacing: SliveLayout.gridGap,
                crossAxisCount: roomColumnCount,
                showPageLoadding: true,
                showPCRefreshButton: false,
                itemBuilder: (_, index) {
                  final item = controller.list[index] as LiveRoomItem;
                  return LiveRoomCard(controller.site, item);
                },
              )
            : PageGridView(
                padding: listPadding,
                mainAxisSpacing: 10,
                crossAxisSpacing: SliveLayout.gridGap,
                crossAxisCount: anchorColumnCount,
                pageController: controller,
                firstRefresh: false,
                showPageLoadding: true,
                showPCRefreshButton: false,
                itemBuilder: (_, index) {
                  final item = controller.list[index] as LiveAnchorItem;
                  return _AnchorSearchCard(
                    item: item,
                    siteName: controller.site.name,
                    onTap: () => AppNavigator.toLiveRoomDetail(
                      site: controller.site,
                      roomId: item.roomId,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _AnchorSearchCard extends StatelessWidget {
  const _AnchorSearchCard({
    required this.item,
    required this.siteName,
    required this.onTap,
  });

  final LiveAnchorItem item;
  final String siteName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final statusColor = item.liveStatus ? colors.success : colors.textTertiary;

    return SliveGlassSurface(
      variant: SliveGlassVariant.card,
      radius: SliveRadii.card,
      enableBackdropBlur: false,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                NetImage(
                  item.avatar,
                  width: 52,
                  height: 52,
                  borderRadius: 18,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.glassStrong,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ],
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
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusPill(
                        label: item.liveStatus ? '直播中' : '未开播',
                        color: statusColor,
                      ),
                      Text(
                        siteName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SliveRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
      ),
    );
  }
}
