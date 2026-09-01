import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/category/category_list_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  List<LiveSubCategory> children(int count) {
    return List.generate(
      count,
      (index) => LiveSubCategory(
        id: 'child-$index',
        name: '分类 $index',
        parentId: 'parent',
      ),
      growable: false,
    );
  }

  test('分类默认只渲染十五项并支持展开和收起', () {
    final category = AppLiveCategory(
      id: 'parent',
      name: '网游',
      children: children(18),
    );

    expect(category.canExpand, isTrue);
    expect(category.visibleCount.value, AppLiveCategory.previewCount);
    expect(category.isExpanded, isFalse);
    expect(category.hasMore, isTrue);
    expect(category.visibleChildren, hasLength(AppLiveCategory.previewCount));
    expect(category.remainingCount, 3);

    category.toggleExpanded();
    expect(category.visibleCount.value, 18);
    expect(category.isExpanded, isTrue);
    expect(category.hasMore, isFalse);
    expect(category.visibleChildren, hasLength(18));
    expect(category.remainingCount, 0);

    category.toggleExpanded();
    expect(category.visibleCount.value, AppLiveCategory.previewCount);
    expect(category.isExpanded, isFalse);
    expect(category.hasMore, isTrue);
    expect(category.visibleChildren, hasLength(AppLiveCategory.previewCount));
  });

  test('大分类按固定批次展开，避免一次构建全部项目', () {
    final category = AppLiveCategory(
      id: 'parent',
      name: '全部游戏',
      children: children(46),
    );

    expect(category.visibleChildren, hasLength(15));
    expect(category.remainingCount, 31);

    category.toggleExpanded();
    expect(category.visibleChildren, hasLength(30));
    expect(category.isExpanded, isTrue);
    expect(category.hasMore, isTrue);
    expect(category.remainingCount, 16);

    category.toggleExpanded();
    expect(category.visibleChildren, hasLength(45));
    expect(category.hasMore, isTrue);
    expect(category.remainingCount, 1);

    category.toggleExpanded();
    expect(category.visibleChildren, hasLength(46));
    expect(category.hasMore, isFalse);
    expect(category.remainingCount, 0);

    category.toggleExpanded();
    expect(category.visibleChildren, hasLength(AppLiveCategory.previewCount));
    expect(category.isExpanded, isFalse);
  });

  test('不足十五项的分类完整展示且不会响应展开操作', () {
    final category = AppLiveCategory(
      id: 'parent',
      name: '手游',
      children: children(8),
    );

    expect(category.canExpand, isFalse);
    expect(category.visibleCount.value, 8);
    expect(category.isExpanded, isTrue);
    expect(category.hasMore, isFalse);
    expect(category.visibleChildren, hasLength(8));

    category.toggleExpanded();
    expect(category.visibleCount.value, 8);
    expect(category.visibleChildren, hasLength(8));
  });
}
