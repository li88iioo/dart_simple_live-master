import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:simple_live_app/app/log.dart';

import 'package:flutter_easyrefresh/easy_refresh.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class BaseController extends GetxController {
  /// 加载中，更新页面
  var pageLoadding = false.obs;

  /// 加载中,不会更新页面
  var loadding = false;

  /// 空白页面
  var pageEmpty = false.obs;

  /// 页面错误
  var pageError = false.obs;

  /// 未登录
  var notLogin = false.obs;

  /// 错误信息
  var errorMsg = "".obs;

  /// 显示错误
  /// * [msg] 错误信息
  /// * [showPageError] 显示页面错误
  /// * 只在第一页加载错误时showPageError=true，后续页加载错误时使用Toast弹出通知
  void handleError(Object exception, {bool showPageError = false}) {
    Log.e(exception.toString(), StackTrace.current);
    var msg = exceptionToString(exception);

    if (showPageError) {
      pageError.value = true;
      errorMsg.value = msg;
    } else {
      SmartDialog.showToast(exceptionToString(msg));
    }
  }

  String exceptionToString(Object exception) {
    return exception.toString().replaceAll("Exception:", "");
  }

  void onLogin() {}
  void onLogout() {}
}

class BasePageController<T> extends BaseController {
  final ScrollController scrollController = ScrollController();
  final EasyRefreshController easyRefreshController = EasyRefreshController();
  int currentPage = 1;
  int count = 0;
  int maxPage = 0;
  int pageSize = 24;
  var canLoadMore = false.obs;
  var list = <T>[].obs;

  Future refreshData() async {
    if (loadding) return;
    currentPage = 1;
    await loadData();
  }

  Future loadData() async {
    final requestedPage = currentPage;
    final isFirstPage = requestedPage == 1;
    try {
      if (loadding) return;
      loadding = true;
      pageError.value = false;
      pageEmpty.value = false;
      notLogin.value = false;
      // 已有数据刷新时保留旧列表，避免整页卡片销毁、闪白和重复图片解码。
      pageLoadding.value = isFirstPage && list.isEmpty;

      var result = await getData(requestedPage, pageSize);
      //是否可以加载更多
      if (result.isNotEmpty) {
        currentPage = requestedPage + 1;
        canLoadMore.value = true;
        pageEmpty.value = false;
      } else {
        canLoadMore.value = false;
        if (isFirstPage) {
          pageEmpty.value = true;
        }
      }
      // 赋值数据
      if (isFirstPage) {
        list.assignAll(result);
      } else {
        list.addAll(result);
      }
    } catch (e) {
      handleError(e, showPageError: isFirstPage && list.isEmpty);
    } finally {
      loadding = false;
      pageLoadding.value = false;
    }
  }

  Future<List<T>> getData(int page, int pageSize) async {
    return [];
  }

  void scrollToTopOrRefresh() {
    if (scrollController.hasClients && scrollController.offset > 0) {
      final distance = scrollController.offset;
      final durationMs = (220 + distance / 24).round().clamp(220, 520);
      scrollController.animateTo(
        0,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeOutCubic,
      );
    } else {
      easyRefreshController.callRefresh();
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    easyRefreshController.dispose();
    super.onClose();
  }
}
