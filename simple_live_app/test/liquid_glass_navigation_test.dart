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

  testWidgets('移动底栏选中层无 Border、BoxShadow 和 BackdropFilter', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 150));

    final selectionFinder = find.byKey(
      const ValueKey<String>('liquid-navigation-selection-0'),
    );
    final selectedDecoration = tester.widget<DecoratedBox>(
      find.descendant(
        of: selectionFinder,
        matching: find.byType(DecoratedBox),
      ),
    );
    final boxDecoration = selectedDecoration.decoration as BoxDecoration;

    expect(boxDecoration.border, isNull);
    expect(boxDecoration.boxShadow, isNull);
    expect(boxDecoration.gradient, isA<RadialGradient>());
    expect(tester.getSize(selectionFinder).width, lessThanOrEqualTo(58));
    expect(tester.getSize(selectionFinder).height, lessThanOrEqualTo(40));
    expect(
      find.descendant(
        of: selectionFinder,
        matching: find.byType(ClipOval),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(LiquidGlassBottomBar),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    _expectNoBoxShadow(tester, find.byType(LiquidGlassBottomBar));
  });

  testWidgets('移动底栏切换可用且整栏没有 Opacity 包裹', (tester) async {
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

    expect(
      find.ancestor(
        of: find.byType(LiquidGlassBottomBar),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );

    await tester.tap(find.text('关注'));
    await tester.pump(const Duration(milliseconds: 150));

    expect(selectedValue.value, 1);
    expect(
      find.byKey(
        const ValueKey<String>('liquid-navigation-selection-1'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('PC 侧栏在深色与减少动画模式下复用无边框轻柔光', (tester) async {
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

    final selectionFinder = find.byKey(
      const ValueKey<String>('liquid-navigation-selection-2'),
    );
    final selectedDecoration = tester.widget<DecoratedBox>(
      find.descendant(
        of: selectionFinder,
        matching: find.byType(DecoratedBox),
      ),
    );
    final boxDecoration = selectedDecoration.decoration as BoxDecoration;

    expect(boxDecoration.border, isNull);
    expect(boxDecoration.boxShadow, isNull);
    expect(
      find.descendant(
        of: selectionFinder,
        matching: find.byType(ClipOval),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(LiquidGlassSideRail),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byType(LiquidGlassSideRail),
        matching: find.byType(Opacity),
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
  final decoratedBoxes = find.descendant(
    of: root,
    matching: find.byType(DecoratedBox),
  );

  for (final element in decoratedBoxes.evaluate()) {
    final decoration = (element.widget as DecoratedBox).decoration;
    if (decoration is BoxDecoration) {
      expect(decoration.boxShadow, anyOf(isNull, isEmpty));
    }
  }
}
