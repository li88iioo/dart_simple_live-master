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
    this.useNativeScrollPhysics = false,
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

  /// 首页等高频滚动页面使用平台原生滚动物理，避免旧版 EasyRefresh
  /// 强制套用 iOS 弹性减速曲线而产生拖黏感。
  final bool useNativeScrollPhysics;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  ScrollPhysics get _platformScrollPhysics => Platform.isIOS || Platform.isMacOS
      ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
      : const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget build(BuildContext context) {
    // 网格和状态层分开订阅：加载/错误状态切换不再重建 EasyRefresh 与 GridView。
    // EasyRefresh 仍然直接接收 ScrollView，避免旧版本产生无界嵌套 viewport。
    return Stack(
      children: [
        Obx(
          () => useNativeScrollPhysics
              ? _buildNativeScrollable()
              : EasyRefresh(
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
        ),
        Positioned.fill(
          child: Obx(
            () => Stack(children: _buildStatusLayer()),
          ),
        ),
      ],
    );
  }

  Widget _buildNativeScrollable() {
    // 在 Android/桌面保持平台原生的直接减速，不使用 EasyRefresh 2.x 的
    // BouncingScrollSimulation。加载更多只在接近列表底部时触发。
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (notification is ScrollEndNotification &&
            metrics.axis == Axis.vertical &&
            metrics.extentAfter < 560 &&
            metrics.pixels > 0 &&
            pageController.canLoadMore.value &&
            !pageController.loadding) {
          // 快速 fling 期间不发起网络请求、不追加列表；等滚动物理过程结束后
          // 再加载下一页，避免数据通知和图片解码抢占 8.33ms 帧预算。
          pageController.loadData();
        }
        return false;
      },
      child: RefreshIndicator.adaptive(
        onRefresh: () async => pageController.refreshData(),
        child: _buildGrid(
          controller: pageController.scrollController,
          physics: _platformScrollPhysics,
        ),
      ),
    );
  }

  Widget _buildGrid({
    ScrollController? controller,
    ScrollPhysics? physics,
  }) {
    final itemCount = pageController.list.length;
    if (mainAxisExtent case final extent?) {
      return GridView.builder(
        controller: controller,
        physics: physics,
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
      controller: controller,
      physics: physics,
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
