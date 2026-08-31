import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/modules/home/home_list_view.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';
import 'package:simple_live_app/widgets/page_list_view.dart';

void main() {
  test('首页缓存范围跟随视口高度并保持有限上下界', () {
    expect(HomeListView.resolveCacheExtent(300), 300);
    expect(HomeListView.resolveCacheExtent(800), 320);
    expect(HomeListView.resolveCacheExtent(1600), 420);
  });

  testWidgets('PageGridView 直接交给 EasyRefresh 的网格可以正常布局', (tester) async {
    final controller = _StaticPageController(['房间 A', '房间 B']);
    addTearDown(controller.onClose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageGridView(
            pageController: controller,
            crossAxisCount: 2,
            mainAxisExtent: 100,
            itemBuilder: (context, index) => Center(
              child: Text(controller.list[index]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('房间 A'), findsOneWidget);
    expect(find.text('房间 B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PageGridView 原生滚动模式使用 Clamping 物理且正常布局', (tester) async {
    final controller = _StaticPageController(['房间 A', '房间 B']);
    addTearDown(controller.onClose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageGridView(
            pageController: controller,
            crossAxisCount: 2,
            mainAxisExtent: 100,
            useNativeScrollPhysics: true,
            itemBuilder: (context, index) => Center(
              child: Text(controller.list[index]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(grid.physics, isA<ClampingScrollPhysics>());
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('房间 A'), findsOneWidget);
    expect(find.text('房间 B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PageListView 直接交给 EasyRefresh 的列表可以正常布局', (tester) async {
    final controller = _StaticPageController(['结果 A', '结果 B']);
    addTearDown(controller.onClose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageListView(
            pageController: controller,
            itemBuilder: (context, index) => SizedBox(
              height: 64,
              child: Center(child: Text(controller.list[index])),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('结果 A'), findsOneWidget);
    expect(find.text('结果 B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _StaticPageController extends BasePageController<String> {
  _StaticPageController(List<String> values) {
    list.addAll(values);
  }
}
