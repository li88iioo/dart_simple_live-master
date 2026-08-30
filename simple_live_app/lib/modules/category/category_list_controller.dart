import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_core/simple_live_core.dart';

class CategoryListController extends BasePageController<AppLiveCategory> {
  CategoryListController(this.site);

  final Site site;

  @override
  Future<List<AppLiveCategory>> getData(int page, int pageSize) async {
    final result = await site.liveSite.getCategores();
    return result.map(AppLiveCategory.fromLiveCategory).toList(growable: false);
  }
}

class AppLiveCategory extends LiveCategory {
  AppLiveCategory({
    required super.id,
    required super.name,
    required super.children,
  }) {
    showAll.value = children.length <= previewCount;
  }

  static const int previewCount = 15;

  final RxBool showAll = false.obs;

  bool get canExpand => children.length > previewCount;

  int get remainingCount => canExpand ? children.length - previewCount : 0;

  List<LiveSubCategory> get visibleChildren {
    if (showAll.value || !canExpand) {
      return children;
    }
    return children.take(previewCount).toList(growable: false);
  }

  void toggleExpanded() {
    if (!canExpand) return;
    showAll.toggle();
  }

  factory AppLiveCategory.fromLiveCategory(LiveCategory item) {
    return AppLiveCategory(
      children: item.children,
      id: item.id,
      name: item.name,
    );
  }
}
