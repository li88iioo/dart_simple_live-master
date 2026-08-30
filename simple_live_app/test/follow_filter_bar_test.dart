import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_page.dart';

void main() {
  final options = <FollowUserTag>[
    FollowUserTag(id: 'all', tag: '全部', userId: const []),
    FollowUserTag(id: 'live', tag: '直播中', userId: const []),
    FollowUserTag(id: 'offline', tag: '未开播', userId: const []),
  ];

  testWidgets('关注筛选栏保持整行外层与紧凑左对齐选项', (tester) async {
    final selectedId = ValueNotifier<String>('all');
    addTearDown(selectedId.dispose);
    await tester.binding.setSurfaceSize(const Size(430, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _FilterBarTestApp(options: options, selectedId: selectedId),
    );
    await tester.pump();

    final barFinder = find.byKey(const ValueKey('follow-filter-bar'));
    final selectionFinder =
        find.byKey(const ValueKey('follow-filter-selection'));
    final barRect = tester.getRect(barFinder);
    final allRect = tester.getRect(
      find.byKey(const ValueKey('follow-filter-slot-all')),
    );
    final offlineRect = tester.getRect(
      find.byKey(const ValueKey('follow-filter-slot-offline')),
    );

    expect(barRect.size, const Size(390, 44));
    expect(allRect.width, 96);
    expect(allRect.left, closeTo(barRect.left + 3, 0.5));
    expect(offlineRect.right, lessThan(barRect.left + 310));

    final selectedDecoration = tester
        .widget<DecoratedBox>(selectionFinder)
        .decoration as BoxDecoration;
    expect(selectedDecoration.border, isNull);
    expect(selectedDecoration.boxShadow, isNull);
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.tap(find.text('直播中'));
    await tester.pump(const Duration(milliseconds: 220));

    expect(selectedId.value, 'live');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('follow-filter-slot-live')),
        matching: find.byKey(const ValueKey('follow-filter-selection')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('PC 超宽窗口不会把三个筛选项拉散', (tester) async {
    final selectedId = ValueNotifier<String>('offline');
    addTearDown(selectedId.dispose);
    await tester.binding.setSurfaceSize(const Size(2048, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _FilterBarTestApp(
        options: options,
        selectedId: selectedId,
        width: 2000,
      ),
    );
    await tester.pump();

    final barRect = tester.getRect(
      find.byKey(const ValueKey('follow-filter-bar')),
    );
    final allRect = tester.getRect(
      find.byKey(const ValueKey('follow-filter-slot-all')),
    );
    final liveRect = tester.getRect(
      find.byKey(const ValueKey('follow-filter-slot-live')),
    );
    final offlineRect = tester.getRect(
      find.byKey(const ValueKey('follow-filter-slot-offline')),
    );
    final selectedRect = tester.getRect(
      find.byKey(const ValueKey('follow-filter-selection')),
    );

    expect(barRect.width, 2000);
    expect(allRect.left, closeTo(barRect.left + 3, 0.5));
    expect(allRect.width, 96);
    expect(liveRect.left - allRect.right, closeTo(2, 0.5));
    expect(offlineRect.left - liveRect.right, closeTo(2, 0.5));
    expect(offlineRect.right, lessThan(barRect.left + 310));
    expect(selectedRect.center.dx, closeTo(offlineRect.center.dx, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('大字体和减少动画下保持稳定高度并允许横向滚动', (tester) async {
    final selectedId = ValueNotifier<String>('offline');
    addTearDown(selectedId.dispose);
    await tester.binding.setSurfaceSize(const Size(320, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 180),
          disableAnimations: true,
          textScaler: TextScaler.linear(1.5),
        ),
        child: _FilterBarTestApp(
          options: options,
          selectedId: selectedId,
          width: 296,
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey('follow-filter-bar'))),
      const Size(296, 44),
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FilterBarTestApp extends StatelessWidget {
  const _FilterBarTestApp({
    required this.options,
    required this.selectedId,
    this.width = 390,
  });

  final List<FollowUserTag> options;
  final ValueNotifier<String> selectedId;
  final double width;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppStyle.light(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6F8FD8),
        ),
        glassMode: SliveGlassMode.soft,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: ValueListenableBuilder<String>(
              valueListenable: selectedId,
              builder: (context, value, child) {
                return FollowFilterBar(
                  options: options,
                  selectedId: value,
                  onSelected: (option) => selectedId.value = option.id,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
