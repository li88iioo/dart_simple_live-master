import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/home/home_list_controller.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/live_room_card.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';

class HomeListView extends StatefulWidget {
  const HomeListView(this.tag, {super.key});

  final String tag;

  /// 首页仅预构建视口前方约 1.5～2 行卡片。
  ///
  /// 相比固定预热前 28 张封面，这个范围跟随设备高度且有明确上限：既能给
  /// 120Hz 快速 fling 留出余量，又不会在启动后批量抢占图片解码和纹理上传。
  @visibleForTesting
  static double resolveCacheExtent(double viewportHeight) {
    if (!viewportHeight.isFinite || viewportHeight <= 0) return 320;
    return (viewportHeight * 0.4).clamp(300.0, 420.0).toDouble();
  }

  @override
  State<HomeListView> createState() => _HomeListViewState();
}

class _HomeListViewState extends State<HomeListView> {
  HomeListController get controller =>
      Get.find<HomeListController>(tag: widget.tag);

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
        final mainAxisExtent = LiveRoomCard.resolveMainAxisExtent(
          cardWidth: cardWidth,
          textScaler: mediaQuery.textScaler.clamp(
            minScaleFactor: 1,
            maxScaleFactor: 1.5,
          ),
        );

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
            cacheExtent: HomeListView.resolveCacheExtent(constraints.maxHeight),
            useNativeScrollPhysics: true,
            itemBuilder: (_, i) {
              final item = controller.list[i];
              return LiveRoomCard(
                controller.site,
                item,
                key: ValueKey('${controller.site.id}-${item.roomId}'),
                coverMaxDecodeDensity: 2.5,
              );
            },
          ),
        );
      },
    );
  }
}
