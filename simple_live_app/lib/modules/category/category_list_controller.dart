import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_core/simple_live_core.dart';

class CategoryListController extends BasePageController<AppLiveCategory> {
  CategoryListController(this.site);

  final Site site;
  bool _initialLoadRequested = false;

  Future<void> ensureInitialLoad() async {
    if (_initialLoadRequested || list.isNotEmpty || loadding) return;
    _initialLoadRequested = true;
    await refreshData();
    if (list.isEmpty && pageError.value) {
      _initialLoadRequested = false;
    }
  }

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
    visibleCount.value =
        children.length < previewCount ? children.length : previewCount;
  }

  static const int previewCount = 15;
  static const int expansionBatchSize = 15;

  final RxInt visibleCount = 0.obs;

  bool get canExpand => children.length > previewCount;

  bool get isExpanded => !canExpand || visibleCount.value > previewCount;

  bool get hasMore => visibleCount.value < children.length;

  int get remainingCount {
    final count = children.length - visibleCount.value;
    return count > 0 ? count : 0;
  }

  List<LiveSubCategory> get visibleChildren =>
      children.take(visibleCount.value).toList(growable: false);

  void toggleExpanded() {
    if (!canExpand) return;
    if (!hasMore) {
      visibleCount.value = previewCount;
      return;
    }

    final nextCount = visibleCount.value + expansionBatchSize;
    visibleCount.value =
        nextCount < children.length ? nextCount : children.length;
  }

  factory AppLiveCategory.fromLiveCategory(LiveCategory item) {
    return AppLiveCategory(
      children: item.children,
      id: item.id,
      name: item.name,
    );
  }
}
