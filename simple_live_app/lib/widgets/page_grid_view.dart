import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyrefresh/easy_refresh.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/widgets/status/app_empty_widget.dart';
import 'package:simple_live_app/widgets/status/app_error_widget.dart';
import 'package:simple_live_app/widgets/status/app_loadding_widget.dart';

class PageGridView extends StatelessWidget {
  const PageGridView({
    required this.itemBuilder,
    required this.pageController,
    required this.crossAxisCount,
    this.padding,
    this.firstRefresh = false,
    this.showPageLoadding = false,
    this.onLoginSuccess,
    this.crossAxisSpacing = 0.0,
    this.mainAxisSpacing = 0.0,
    this.showPCRefreshButton = true,
    this.mainAxisExtent,
    this.cacheExtent = 360,
    super.key,
  });

  final BasePageController pageController;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets? padding;
  final bool firstRefresh;
  final Function()? onLoginSuccess;
  final bool showPageLoadding;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final int crossAxisCount;
  final bool showPCRefreshButton;
  final double? mainAxisExtent;
  final double cacheExtent;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    // EasyRefresh 必须直接接收 ScrollView。若在 GridView 外再包一层 Obx，
    // EasyRefresh 会把它当作普通 Box 放进 SliverToBoxAdapter，最终形成
    // “纵向 viewport 高度无界”的嵌套视口，接口已有数据也无法渲染。
    return Obx(
      () => Stack(
        children: [
          EasyRefresh(
            header: MaterialHeader(
              completeDuration: const Duration(milliseconds: 400),
            ),
            footer: MaterialFooter(
              completeDuration: const Duration(milliseconds: 400),
            ),
            scrollController: pageController.scrollController,
            controller: pageController.easyRefreshController,
            firstRefresh: firstRefresh,
            onLoad: pageController.loadData,
            onRefresh: pageController.refreshData,
            child: _buildGrid(),
          ),
          ..._buildStatusLayer(),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final itemCount = pageController.list.length;
    if (mainAxisExtent case final extent?) {
      return GridView.builder(
        padding: padding,
        cacheExtent: cacheExtent,
        itemCount: itemCount,
        addAutomaticKeepAlives: false,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          mainAxisExtent: extent,
        ),
        itemBuilder: itemBuilder,
      );
    }

    return MasonryGridView.count(
      padding: padding,
      cacheExtent: cacheExtent,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
    );
  }

  List<Widget> _buildStatusLayer() {
    final hasItems = pageController.list.isNotEmpty;
    final canUseDesktopActions = _isDesktop &&
        hasItems &&
        pageController.canLoadMore.value &&
        !pageController.pageLoadding.value &&
        !pageController.pageEmpty.value;

    return [
      if (canUseDesktopActions)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Center(
            child: TextButton(
              onPressed: pageController.loadData,
              child: const Text('加载更多'),
            ),
          ),
        ),
      if (canUseDesktopActions && showPCRefreshButton)
        Positioned(
          bottom: 12,
          right: 12,
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Get.theme.cardColor.withAlpha(200),
              elevation: 0,
            ),
            onPressed: pageController.refreshData,
            icon: const Icon(Icons.refresh),
          ),
        ),
      if (!hasItems && pageController.pageEmpty.value)
        Positioned.fill(
          child: AppEmptyWidget(onRefresh: pageController.refreshData),
        ),
      if (!hasItems && showPageLoadding && pageController.pageLoadding.value)
        const Positioned.fill(child: AppLoaddingWidget()),
      if (!hasItems && pageController.pageError.value)
        Positioned.fill(
          child: AppErrorWidget(
            errorMsg: pageController.errorMsg.value,
            onRefresh: pageController.refreshData,
          ),
        ),
    ];
  }
}
