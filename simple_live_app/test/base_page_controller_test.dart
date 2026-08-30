import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';

void main() {
  test('刷新期间保留旧列表，成功后原位替换', () async {
    final controller = _TestPageController();
    controller.responses.add(Future.value([1, 2]));
    await controller.loadData();
    expect(controller.list, [1, 2]);

    final refreshResult = Completer<List<int>>();
    controller.responses.add(refreshResult.future);
    final refreshing = controller.refreshData();
    await Future<void>.delayed(Duration.zero);

    expect(controller.list, [1, 2]);
    expect(controller.pageLoadding.value, isFalse);

    refreshResult.complete([3, 4]);
    await refreshing;
    expect(controller.list, [3, 4]);
  });

  test('加载更多追加数据并保持正确页码', () async {
    final controller = _TestPageController();
    controller.responses
      ..add(Future.value([1, 2]))
      ..add(Future.value([3]));

    await controller.loadData();
    await controller.loadData();

    expect(controller.list, [1, 2, 3]);
    expect(controller.currentPage, 3);
  });
}

class _TestPageController extends BasePageController<int> {
  final List<Future<List<int>>> responses = [];

  @override
  Future<List<int>> getData(int page, int pageSize) {
    return responses.removeAt(0);
  }
}
