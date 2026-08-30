import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/widgets/navigation/liquid_glass_bottom_bar.dart';

void main() {
  const destinations = [
    LiquidGlassBottomBarDestination(
      icon: Icons.home_outlined,
      label: '首页',
      value: 0,
    ),
    LiquidGlassBottomBarDestination(
      icon: Icons.favorite_border,
      label: '关注',
      value: 1,
    ),
    LiquidGlassBottomBarDestination(
      icon: Icons.grid_view_outlined,
      label: '分类',
      value: 2,
    ),
    LiquidGlassBottomBarDestination(
      icon: Icons.person_outline,
      label: '我的',
      value: 3,
    ),
  ];

  testWidgets('液态玻璃底栏展示全部入口并转发选择事件', (tester) async {
    final selectedValue = ValueNotifier<int>(0);
    addTearDown(selectedValue.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: const ColoredBox(color: Colors.blueGrey),
          bottomNavigationBar: ValueListenableBuilder<int>(
            valueListenable: selectedValue,
            builder: (context, value, child) {
              return LiquidGlassBottomBar(
                destinations: destinations,
                selectedValue: value,
                onDestinationSelected: (nextValue) {
                  selectedValue.value = nextValue;
                },
              );
            },
          ),
        ),
      ),
    );

    for (final destination in destinations) {
      expect(find.text(destination.label), findsOneWidget);
    }

    await tester.tap(find.text('关注'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(selectedValue.value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('液态玻璃底栏在窄屏深色模式下不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(280, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          extendBody: true,
          body: const ColoredBox(color: Colors.black),
          bottomNavigationBar: LiquidGlassBottomBar(
            destinations: destinations,
            selectedValue: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LiquidGlassBottomBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
