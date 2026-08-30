import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/home/home_list_controller.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/live_room_card.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';

class HomeListView extends StatelessWidget {
  final String tag;
  const HomeListView(this.tag, {super.key});
  HomeListController get controller => Get.find<HomeListController>(tag: tag);
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.orientation == Orientation.portrait
        ? mediaQuery.viewPadding.bottom +
            SliveLayout.bottomDockHeight +
            SliveLayout.bottomDockGap +
            20
        : 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        var columnCount = constraints.maxWidth ~/ 200;
        if (columnCount < 2) columnCount = 2;
        if (columnCount > 6) columnCount = 6;
        const horizontalPadding = 24.0;
        const gap = 12.0;
        final gridWidth =
            constraints.maxWidth - horizontalPadding - gap * (columnCount - 1);
        final cardWidth = gridWidth / columnCount;
        final textScale = mediaQuery.textScaler.scale(1).clamp(1.0, 1.5);
        final mainAxisExtent =
            ((cardWidth - 10) * 2 / 3) + 59 + ((textScale - 1) * 30);

        return KeepAliveWrapper(
          child: PageGridView(
            pageController: controller,
            padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
            firstRefresh: false,
            showPageLoadding: true,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            crossAxisCount: columnCount,
            mainAxisExtent: mainAxisExtent,
            cacheExtent: 420,
            itemBuilder: (_, i) {
              final item = controller.list[i];
              return LiveRoomCard(
                controller.site,
                item,
                key: ValueKey('${controller.site.id}-${item.roomId}'),
              );
            },
          ),
        );
      },
    );
  }
}
