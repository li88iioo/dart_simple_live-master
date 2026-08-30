import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/category/detail/category_detail_controller.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_icon_button.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/live_room_card.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';

class CategoryDetailPage extends GetView<CategoryDetailController> {
  const CategoryDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 24;

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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.subCategory.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.28,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              '${controller.site.name} · 分类直播',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SliveGlassIconButton(
              icon: Icons.refresh_rounded,
              tooltip: '刷新',
              onPressed: controller.refreshData,
            ),
          ),
        ],
      ),
      body: KeepAliveWrapper(
        child: LayoutBuilder(
          builder: (context, constraints) {
            var columnCount = (constraints.maxWidth / 200).floor();
            if (columnCount < 2) columnCount = 2;
            if (columnCount > 6) columnCount = 6;

            return PageGridView(
              pageController: controller,
              padding: EdgeInsets.fromLTRB(
                SliveLayout.pageHorizontal,
                8,
                SliveLayout.pageHorizontal,
                bottomPadding,
              ),
              firstRefresh: true,
              showPageLoadding: true,
              showPCRefreshButton: false,
              mainAxisSpacing: SliveLayout.gridGap,
              crossAxisSpacing: SliveLayout.gridGap,
              crossAxisCount: columnCount,
              itemBuilder: (_, index) {
                final item = controller.list[index];
                return LiveRoomCard(controller.site, item);
              },
            );
          },
        ),
      ),
    );
  }
}
