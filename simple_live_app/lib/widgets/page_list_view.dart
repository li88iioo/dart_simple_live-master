import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyrefresh/easy_refresh.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/widgets/status/app_empty_widget.dart';
import 'package:simple_live_app/widgets/status/app_error_widget.dart';
import 'package:simple_live_app/widgets/status/app_loadding_widget.dart';

typedef IndexedWidgetBuilder = Widget Function(BuildContext context, int index);

class PageListView extends StatelessWidget {
  const PageListView({
    required this.itemBuilder,
    required this.pageController,
    this.padding,
    this.firstRefresh = false,
    this.showPageLoadding = false,
    this.showPCRefreshButton = true,
    this.separatorBuilder,
    this.onLoginSuccess,
    this.cacheExtent = 360,
    super.key,
  });

  final BasePageController pageController;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final EdgeInsets? padding;
  final bool firstRefresh;
  final Function()? onLoginSuccess;
  final bool showPageLoadding;
  final bool showPCRefreshButton;
  final double cacheExtent;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    // EasyRefresh 需要直接拿到 ListView，不能让响应式 Box 隔在中间，
    // 否则会退化成嵌套 viewport，并在移动端表现为空白列表。
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
            child: ListView.separated(
              padding: padding,
              cacheExtent: cacheExtent,
              itemCount: pageController.list.length,
              itemBuilder: itemBuilder,
              separatorBuilder:
                  separatorBuilder ?? (context, index) => const SizedBox(),
            ),
          ),
          ..._buildStatusLayer(),
        ],
      ),
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
