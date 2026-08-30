import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/widgets/navigation/slive_animated_indexed_stack.dart';

void main() {
  testWidgets('主导航惰性保活页面，切走后停止 ticker 与 layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final selectedIndex = ValueNotifier<int>(0);
    final firstMetrics = _PageMetrics();
    final secondMetrics = _PageMetrics();
    addTearDown(selectedIndex.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: selectedIndex,
          builder: (context, index, child) {
            return SliveAnimatedIndexedStack(
              index: index,
              children: [
                _TickerLayoutProbePage(
                  label: '首页',
                  metrics: firstMetrics,
                ),
                _TickerLayoutProbePage(
                  label: '关注',
                  metrics: secondMetrics,
                ),
              ],
            );
          },
        ),
      ),
    );

    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(firstMetrics.initCount, 1);
    expect(firstMetrics.tickCount, greaterThan(0));
    expect(firstMetrics.layoutCount, greaterThan(0));

    selectedIndex.value = 1;
    await tester.pump();
    await tester.pump(SliveAnimatedIndexedStack.defaultDuration);

    expect(secondMetrics.initCount, 1);
    expect(firstMetrics.disposeCount, 0);

    final hiddenTickCount = firstMetrics.tickCount;
    final hiddenLayoutCount = firstMetrics.layoutCount;

    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.binding.setSurfaceSize(const Size(920, 660));
    await tester.pump();

    expect(firstMetrics.tickCount, hiddenTickCount);
    expect(firstMetrics.layoutCount, hiddenLayoutCount);
    expect(firstMetrics.disposeCount, 0);

    selectedIndex.value = 0;
    await tester.pump();
    await tester.pump(SliveAnimatedIndexedStack.defaultDuration);
    await tester.pump(const Duration(milliseconds: 16));

    expect(firstMetrics.initCount, 1);
    expect(firstMetrics.disposeCount, 0);
    expect(firstMetrics.tickCount, greaterThan(hiddenTickCount));
    expect(firstMetrics.layoutCount, greaterThan(hiddenLayoutCount));

    await tester.pumpWidget(const SizedBox.shrink());
    expect(firstMetrics.disposeCount, 1);
    expect(secondMetrics.disposeCount, 1);
  });

  testWidgets('TabController 桥接只在索引变化时切页，不随动画逐帧布局重列表', (tester) async {
    final key = GlobalKey<_TabBridgeHarnessState>();
    final firstMetrics = _PageMetrics();
    final secondMetrics = _PageMetrics();

    await tester.pumpWidget(
      MaterialApp(
        home: _TabBridgeHarness(
          key: key,
          firstMetrics: firstMetrics,
          secondMetrics: secondMetrics,
        ),
      ),
    );
    await tester.pump();

    key.currentState!.select(1);
    await tester.pump();

    final activeLayoutCount = secondMetrics.layoutCount;
    expect(activeLayoutCount, greaterThan(0));

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(secondMetrics.layoutCount, activeLayoutCount);
    expect(firstMetrics.disposeCount, 0);
    expect(secondMetrics.initCount, 1);
  });

  testWidgets('页面容器禁用整页透明层和自动大纹理 RepaintBoundary', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SliveAnimatedIndexedStack(
          index: 0,
          children: [
            ColoredBox(color: Colors.red),
            ColoredBox(color: Colors.blue),
          ],
        ),
      ),
    );

    final pageView = tester.widget<PageView>(find.byType(PageView));
    final delegate = pageView.childrenDelegate as SliverChildBuilderDelegate;

    expect(pageView.allowImplicitScrolling, isFalse);
    expect(delegate.addRepaintBoundaries, isFalse);
    expect(
      find.descendant(
        of: find.byType(SliveAnimatedIndexedStack),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });
}

class _PageMetrics {
  int initCount = 0;
  int disposeCount = 0;
  int tickCount = 0;
  int layoutCount = 0;
}

class _TickerLayoutProbePage extends StatefulWidget {
  const _TickerLayoutProbePage({
    required this.label,
    required this.metrics,
  });

  final String label;
  final _PageMetrics metrics;

  @override
  State<_TickerLayoutProbePage> createState() => _TickerLayoutProbePageState();
}

class _TickerLayoutProbePageState extends State<_TickerLayoutProbePage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    widget.metrics.initCount++;
    _ticker = createTicker((_) => widget.metrics.tickCount++)..start();
  }

  @override
  void dispose() {
    widget.metrics.disposeCount++;
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LayoutProbe(
      onLayout: () => widget.metrics.layoutCount++,
      child: ColoredBox(
        color: Colors.transparent,
        child: Center(child: Text(widget.label)),
      ),
    );
  }
}

class _LayoutProbe extends SingleChildRenderObjectWidget {
  const _LayoutProbe({
    required this.onLayout,
    required super.child,
  });

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLayoutProbe(onLayout);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderLayoutProbe renderObject,
  ) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderLayoutProbe extends RenderProxyBox {
  _RenderLayoutProbe(this.onLayout);

  VoidCallback onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }
}

class _TabBridgeHarness extends StatefulWidget {
  const _TabBridgeHarness({
    super.key,
    required this.firstMetrics,
    required this.secondMetrics,
  });

  final _PageMetrics firstMetrics;
  final _PageMetrics secondMetrics;

  @override
  State<_TabBridgeHarness> createState() => _TabBridgeHarnessState();
}

class _TabBridgeHarnessState extends State<_TabBridgeHarness>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: 2,
    vsync: this,
    animationDuration: const Duration(milliseconds: 150),
  );

  void select(int index) {
    _controller.animateTo(
      index,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliveTabIndexedStack(
      controller: _controller,
      children: [
        _TickerLayoutProbePage(label: '平台一', metrics: widget.firstMetrics),
        _TickerLayoutProbePage(label: '平台二', metrics: widget.secondMetrics),
      ],
    );
  }
}
