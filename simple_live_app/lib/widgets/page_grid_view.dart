import 'dart:io';

import 'package:flutter/foundation.dart' show AsyncCallback;
import 'package:flutter/material.dart';
import 'package:flutter_easyrefresh/easy_refresh.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/widgets/status/app_empty_widget.dart';
import 'package:simple_live_app/widgets/status/app_error_widget.dart';
import 'package:simple_live_app/widgets/status/app_loadding_widget.dart';

/// Slive 高频列表统一使用的平台原生滚动物理。
///
/// iOS/macOS 保留系统弹性，其它平台使用直接的边界减速；始终允许内容不足
/// 一屏时下拉刷新。
ScrollPhysics get slivePlatformScrollPhysics =>
    Platform.isIOS || Platform.isMacOS
        ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
        : const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

/// 首页、关注、分类共用的原生刷新容器。
///
/// 加载更多仅在纵向 fling 完全结束后触发，避免滚动过程中网络回调、列表追加
/// 和图片解码同时抢占帧预算。没有 [onLoad] 时只提供原生下拉刷新。
class SliveNativeRefreshView extends StatefulWidget {
  const SliveNativeRefreshView({
    required this.onRefresh,
    required this.child,
    this.onLoad,
    this.canLoadMore,
    this.isLoading,
    this.firstRefresh = false,
    this.loadTriggerExtent = 560,
    super.key,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final AsyncCallback? onLoad;
  final bool Function()? canLoadMore;
  final bool Function()? isLoading;
  final bool firstRefresh;
  final double loadTriggerExtent;

  @override
  State<SliveNativeRefreshView> createState() => _SliveNativeRefreshViewState();
}

class _SliveNativeRefreshViewState extends State<SliveNativeRefreshView> {
  bool _initialRefreshRequested = false;

  @override
  void initState() {
    super.initState();
    _scheduleInitialRefresh();
  }

  @override
  void didUpdateWidget(covariant SliveNativeRefreshView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.firstRefresh && widget.firstRefresh) {
      _scheduleInitialRefresh();
    }
  }

  void _scheduleInitialRefresh() {
    if (!widget.firstRefresh || _initialRefreshRequested) return;
    _initialRefreshRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onRefresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final load = widget.onLoad;
        final metrics = notification.metrics;
        if (load != null &&
            notification is ScrollEndNotification &&
            metrics.axis == Axis.vertical &&
            metrics.extentAfter < widget.loadTriggerExtent &&
            metrics.pixels > 0 &&
            (widget.canLoadMore?.call() ?? true) &&
            !(widget.isLoading?.call() ?? false)) {
          load();
        }
        return false;
      },
      child: RefreshIndicator.adaptive(
        onRefresh: widget.onRefresh,
        child: widget.child,
      ),
    );
  }
}

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
    return SliveNativeRefreshView(
      onRefresh: () async {
        await pageController.refreshData();
      },
      onLoad: () async {
        await pageController.loadData();
      },
      canLoadMore: () => pageController.canLoadMore.value,
      isLoading: () => pageController.loadding,
      firstRefresh: firstRefresh,
      child: _buildGrid(
        controller: pageController.scrollController,
        physics: slivePlatformScrollPhysics,
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
