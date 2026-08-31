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

  testWidgets('移动底栏完全不绘制选中背景、投影和实时模糊', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4F73B8),
          ),
        ),
        home: Scaffold(
          bottomNavigationBar: LiquidGlassBottomBar(
            destinations: destinations,
            selectedValue: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('liquid-navigation-selection-horizontal'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(LiquidGlassBottomBar),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(LiquidGlassBottomBar),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
    _expectNoBoxShadow(tester, find.byType(LiquidGlassBottomBar));

    final selectedIcon = tester.widget<Icon>(find.byIcon(Icons.home_outlined));
    final inactiveIcon =
        tester.widget<Icon>(find.byIcon(Icons.favorite_border));
    expect(selectedIcon.color, isNot(inactiveIcon.color));
  });

  testWidgets('移动底栏切换只过渡图标与文字颜色', (tester) async {
    final selectedValue = ValueNotifier<int>(0);
    addTearDown(selectedValue.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
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

    final oldSelectedColor =
        tester.widget<Icon>(find.byIcon(Icons.home_outlined)).color;
    await tester.tap(find.text('关注'));
    await tester.pumpAndSettle();

    expect(selectedValue.value, 1);
    expect(
      find.byKey(
        const ValueKey<String>('liquid-navigation-selection-horizontal'),
      ),
      findsNothing,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.favorite_border)).color,
      oldSelectedColor,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('PC 侧栏同样不绘制选中背景且支持减少动画', (tester) async {
    final selectedValue = ValueNotifier<int>(2);
    addTearDown(selectedValue.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8BA8E8),
            brightness: Brightness.dark,
          ),
        ),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Align(
              alignment: Alignment.centerLeft,
              child: ValueListenableBuilder<int>(
                valueListenable: selectedValue,
                builder: (context, value, child) {
                  return LiquidGlassSideRail(
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
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('liquid-navigation-selection-vertical'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(LiquidGlassSideRail),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    _expectNoBoxShadow(tester, find.byType(LiquidGlassSideRail));

    await tester.tap(find.text('我的'));
    await tester.pump();
    expect(selectedValue.value, 3);
    expect(tester.takeException(), isNull);
  });
}

void _expectNoBoxShadow(WidgetTester tester, Finder root) {
  for (final decoratedBox in tester.widgetList<DecoratedBox>(
    find.descendant(of: root, matching: find.byType(DecoratedBox)),
  )) {
    final decoration = decoratedBox.decoration;
    if (decoration is BoxDecoration) {
      expect(decoration.boxShadow, anyOf(isNull, isEmpty));
    }
  }
}
