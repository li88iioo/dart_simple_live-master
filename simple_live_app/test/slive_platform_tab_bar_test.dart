import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/navigation/slive_platform_tab_bar.dart';

void main() {
  final sites = [
    Sites.allSites[Constant.kBiliBili]!,
    Sites.allSites[Constant.kDouyu]!,
    Sites.allSites[Constant.kHuya]!,
  ];

  testWidgets('平台选项暴露可执行的语义点击动作', (tester) async {
    final semantics = tester.ensureSemantics();
    final key = GlobalKey<_PlatformTabHarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppStyle.light(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6F8FD8),
          ),
          glassMode: SliveGlassMode.soft,
        ),
        home: Scaffold(
          body: SafeArea(
            child: _PlatformTabHarness(key: key, sites: sites),
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('虎牙直播'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    node.owner!.performAction(
      node.id,
      SemanticsAction.tap,
    );
    await tester.pump(const Duration(milliseconds: 220));
    expect(key.currentState?.selectedIndex, 2);
    semantics.dispose();
  });

  testWidgets('平台胶囊栏展示三个平台并同步选择状态', (tester) async {
    final key = GlobalKey<_PlatformTabHarnessState>();
    await tester.binding.setSurfaceSize(const Size(430, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppStyle.light(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6F8FD8),
          ),
          glassMode: SliveGlassMode.soft,
        ),
        home: Scaffold(
          body: SafeArea(
            child: _PlatformTabHarness(key: key, sites: sites),
          ),
        ),
      ),
    );

    for (final site in sites) {
      expect(find.text(site.name), findsOneWidget);
    }

    await tester.tap(find.text('虎牙直播'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(key.currentState?.selectedIndex, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('平台切换使用唯一共享胶囊并连续移动', (tester) async {
    final key = GlobalKey<_PlatformTabHarnessState>();
    await tester.binding.setSurfaceSize(const Size(430, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppStyle.light(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6F8FD8),
          ),
          glassMode: SliveGlassMode.soft,
        ),
        home: Scaffold(
          body: SafeArea(
            child: _PlatformTabHarness(key: key, sites: sites),
          ),
        ),
      ),
    );

    final selection = find.byKey(
      const ValueKey<String>('slive-platform-shared-selection'),
    );
    expect(selection, findsOneWidget);

    final decoration = tester.widget<DecoratedBox>(
      find.descendant(of: selection, matching: find.byType(DecoratedBox)),
    );
    final boxDecoration = decoration.decoration as BoxDecoration;
    expect(boxDecoration.border, isNull);
    expect(boxDecoration.boxShadow, isNull);

    final initialLeft = tester.getTopLeft(selection).dx;
    await tester.tap(find.text('虎牙直播'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final movingLeft = tester.getTopLeft(selection).dx;
    expect(movingLeft, greaterThan(initialLeft));

    await tester.pump(const Duration(milliseconds: 180));
    final finalLeft = tester.getTopLeft(selection).dx;
    expect(finalLeft, greaterThan(movingLeft));
    expect(key.currentState?.selectedIndex, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无尾部按钮的移动平台栏完整填充且不留异常空段', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppStyle.light(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6F8FD8),
          ),
          glassMode: SliveGlassMode.soft,
        ),
        home: Scaffold(
          body: SafeArea(
            child: _PlatformTabHarness(sites: sites),
          ),
        ),
      ),
    );

    final selection = find.byKey(
      const ValueKey<String>('slive-platform-shared-selection'),
    );
    final bar = find.byType(SlivePlatformTabBar);
    final selectionWidth = tester.getSize(selection).width;
    final barWidth = tester.getSize(bar).width;

    expect(selectionWidth * sites.length, greaterThan(barWidth * 0.92));
    expect(tester.takeException(), isNull);
  });
}

class _PlatformTabHarness extends StatefulWidget {
  const _PlatformTabHarness({
    super.key,
    required this.sites,
  });

  final List<Site> sites;

  @override
  State<_PlatformTabHarness> createState() => _PlatformTabHarnessState();
}

class _PlatformTabHarnessState extends State<_PlatformTabHarness>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: widget.sites.length,
    vsync: this,
  );

  int get selectedIndex => _controller.index;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SlivePlatformTabBar(
          controller: _controller,
          sites: widget.sites,
        ),
      ),
    );
  }
}
