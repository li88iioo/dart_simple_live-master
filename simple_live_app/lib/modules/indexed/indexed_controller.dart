import 'package:flutter/widgets.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/category/category_controller.dart';
import 'package:simple_live_app/modules/category/category_page.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_page.dart';
import 'package:simple_live_app/modules/home/home_controller.dart';
import 'package:simple_live_app/modules/home/home_page.dart';
import 'package:simple_live_app/modules/mine/mine_page.dart';

class IndexedController extends GetxController {
  final RxList<HomePageItem> items = RxList<HomePageItem>([]);
  final RxInt index = 0.obs;

  /// 页面实例只在首次访问时创建，随后始终复用同一 Widget 实例。
  ///
  /// 这里刻意不使用 RxList：首次挂载页面后紧接着更新 [index]，单一响应源即可
  /// 驱动界面刷新，避免一次点击连续触发两次主内容树重建。
  final List<Widget> pages = <Widget>[
    const SizedBox(),
    const SizedBox(),
    const SizedBox(),
    const SizedBox(),
  ];

  void setIndex(int nextIndex) {
    if (nextIndex < 0 ||
        nextIndex >= pages.length ||
        nextIndex >= items.length) {
      return;
    }

    final pageMounted = pages[nextIndex] is! SizedBox;
    final isReselect = index.value == nextIndex && pageMounted;

    if (!pageMounted) {
      _mountPage(nextIndex);
    }

    if (isReselect) {
      EventBus.instance.emit<int>(
        EventBus.kBottomNavigationBarClicked,
        items[nextIndex].index,
      );
      return;
    }

    // 不再延后一帧：导航反馈、页面显示和 150ms 合成动画在同一帧开始。
    // 页面列表本身不响应式，因此首次挂载也只触发这一次索引刷新。
    if (index.value != nextIndex) {
      index.value = nextIndex;
    }
  }

  void _mountPage(int pageIndex) {
    switch (items[pageIndex].index) {
      case 0:
        if (!Get.isRegistered<HomeController>()) {
          Get.put(HomeController());
        }
        pages[pageIndex] = const HomePage();
        break;
      case 1:
        if (!Get.isRegistered<FollowUserController>()) {
          Get.put(FollowUserController());
        }
        pages[pageIndex] = const FollowUserPage();
        break;
      case 2:
        if (!Get.isRegistered<CategoryController>()) {
          Get.put(CategoryController());
        }
        pages[pageIndex] = const CategoryPage();
        break;
      case 3:
        pages[pageIndex] = const MinePage();
        break;
      default:
        pages[pageIndex] = const SizedBox.shrink();
    }
  }

  @override
  void onInit() {
    Future<void>.delayed(Duration.zero, showFirstRun);
    items.value = AppSettingsController.instance.homeSort
        .map((key) => Constant.allHomePages[key]!)
        .toList(growable: false);
    setIndex(0);
    super.onInit();
  }

  Future<void> showFirstRun() async {
    final settingsController = Get.find<AppSettingsController>();
    if (settingsController.firstRun) {
      settingsController.setNoFirstRun();
      await Utils.showStatement();
      Utils.checkUpdate();
    }
  }
}
