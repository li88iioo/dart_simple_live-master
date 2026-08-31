import 'package:flutter/scheduler.dart';
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

  /// 后台预热页面写入 [pages] 后通知主页面只重建一次。
  final RxInt pageRevision = 0.obs;

  /// 页面实例只在首次访问时创建，随后始终复用同一 Widget 实例。
  ///
  /// 这里刻意不使用 RxList：用户点击时由 [index] 驱动一次刷新；后台预热
  /// 则只递增 [pageRevision]。两条路径互斥，避免一次操作连续重建主内容树。
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
    if (pageIndex < 0 ||
        pageIndex >= pages.length ||
        pageIndex >= items.length ||
        pages[pageIndex] is! SizedBox) {
      return;
    }

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

  @override
  void onReady() {
    super.onReady();
    // 首页图片和网络请求先获得首屏时间片；随后只预热静态但首建较重的“我的”。
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!isClosed) _scheduleMinePagePrewarm();
    });
  }

  /// 在用户通常开始切换底栏前，把“我的”页作为 Offstage 页面真实构建一次。
  ///
  /// 真机 120Hz 采样显示该页首次挂载曾产生约 100ms 空档，而之后重复进入
  /// 已稳定到单帧预算附近。只预热静态设置页，避免提前加载关注/分类数据带来
  /// 额外网络、内存和待机功耗。
  void _scheduleMinePagePrewarm() {
    final minePageIndex = items.indexWhere((item) => item.index == 3);
    if (minePageIndex < 0 || pages[minePageIndex] is! SizedBox) return;

    SchedulerBinding.instance.scheduleTask<void>(
      () {
        if (isClosed || pages[minePageIndex] is! SizedBox) return;
        _mountPage(minePageIndex);
        pageRevision.value++;
      },
      Priority.idle,
      debugLabel: 'Slive.prewarmMinePage',
    );
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
