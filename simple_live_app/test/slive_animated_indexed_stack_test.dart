import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/widgets/navigation/slive_animated_indexed_stack.dart';

void main() {
  testWidgets('底部导航切页时旧页面立即停止绘制，避免玻璃残影', (tester) async {
    final selectedIndex = ValueNotifier<int>(0);
    addTearDown(selectedIndex.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: selectedIndex,
            builder: (context, index, child) {
              return SliveAnimatedIndexedStack(
                index: index,
                children: const [
                  ColoredBox(
                    color: Colors.red,
                    child: Center(child: Text('首页内容')),
                  ),
                  ColoredBox(
                    color: Colors.blue,
                    child: Center(child: Text('设置内容')),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('首页内容'), findsOneWidget);
    expect(find.text('设置内容'), findsNothing);

    selectedIndex.value = 1;
    await tester.pump();

    expect(find.text('首页内容'), findsNothing);
    expect(find.text('设置内容'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.takeException(), isNull);
  });

  testWidgets('主导航可关闭整页位移动画并保持单页绘制', (tester) async {
    final selectedIndex = ValueNotifier<int>(0);
    addTearDown(selectedIndex.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: selectedIndex,
          builder: (context, index, child) {
            return SliveAnimatedIndexedStack(
              index: index,
              transitionDistance: 0,
              children: const [
                ColoredBox(color: Colors.red, child: Text('首页')),
                ColoredBox(color: Colors.blue, child: Text('关注')),
              ],
            );
          },
        ),
      ),
    );

    selectedIndex.value = 1;
    await tester.pump();

    expect(find.text('首页'), findsNothing);
    expect(find.text('关注'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('slive-indexed-page-transition'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
