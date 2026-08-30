import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';

void main() {
  testWidgets('直播间 Tab 首次访问才挂载，并在往返切换后保留状态', (tester) async {
    final index = ValueNotifier<int>(0);
    final mounts = List<int>.filled(4, 0);
    final pages = List<Widget>.generate(
      4,
      (pageIndex) => _StatefulCounterPage(
        pageIndex: pageIndex,
        onMount: () => mounts[pageIndex]++,
      ),
      growable: false,
    );
    addTearDown(index.dispose);

    await tester.pumpWidget(_buildHarness(index: index, pages: pages));

    expect(mounts, <int>[1, 0, 0, 0]);
    await tester.tap(find.byKey(const ValueKey('increment-0')));
    await tester.pump();
    expect(find.text('页面 0 · 1'), findsOneWidget);

    index.value = 1;
    await tester.pump();
    expect(
        find.byKey(const ValueKey('increment-0')).hitTestable(), findsNothing);
    expect(
      find.byKey(const ValueKey('increment-1')).hitTestable(),
      findsOneWidget,
    );
    expect(mounts, <int>[1, 1, 0, 0]);

    index.value = 0;
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('页面 0 · 1'), findsOneWidget);
    expect(mounts, <int>[1, 1, 0, 0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('非当前直播间 Tab 不布局、不绘制且不参与命中', (tester) async {
    final index = ValueNotifier<int>(0);
    final viewportWidth = ValueNotifier<double>(620);
    final firstActivity = _RenderActivityCounter();
    final secondActivity = _RenderActivityCounter();
    var firstTaps = 0;
    var secondTaps = 0;
    final pages = <Widget>[
      _InteractiveRenderPage(
        label: '聊天页',
        color: Colors.red,
        counter: firstActivity,
        onTap: () => firstTaps++,
      ),
      _InteractiveRenderPage(
        label: '设置页',
        color: Colors.blue,
        counter: secondActivity,
        onTap: () => secondTaps++,
      ),
    ];
    addTearDown(index.dispose);
    addTearDown(viewportWidth.dispose);

    await tester.pumpWidget(
      _buildHarness(
        index: index,
        pages: pages,
        viewportWidth: viewportWidth,
      ),
    );
    await tester.pump();
    final firstPaintCountBeforeSwitch = firstActivity.paints;
    expect(firstPaintCountBeforeSwitch, greaterThan(0));
    expect(firstActivity.layouts, greaterThan(0));
    expect(secondActivity.paints, 0);
    expect(secondActivity.layouts, 0);

    index.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(firstActivity.paints, firstPaintCountBeforeSwitch);
    expect(secondActivity.paints, greaterThan(0));
    expect(find.text('聊天页').hitTestable(), findsNothing);
    expect(find.text('设置页').hitTestable(), findsOneWidget);

    final hiddenLayoutsAfterSwitch = firstActivity.layouts;
    final currentLayoutsBeforeResize = secondActivity.layouts;
    viewportWidth.value = 540;
    await tester.pump();
    expect(firstActivity.layouts, hiddenLayoutsAfterSwitch);
    expect(secondActivity.layouts, greaterThan(currentLayoutsBeforeResize));

    await tester.tap(find.text('设置页'));
    await tester.pump();
    expect(firstTaps, 0);
    expect(secondTaps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('快速连续切换会立即响应最终 Tab，且只做定尺寸位移动画', (tester) async {
    final index = ValueNotifier<int>(0);
    final pages = List<Widget>.generate(
      4,
      (pageIndex) => ColoredBox(
        color: Colors.primaries[pageIndex],
        child: Center(child: Text('快速页面 $pageIndex')),
      ),
      growable: false,
    );
    addTearDown(index.dispose);

    await tester.pumpWidget(_buildHarness(index: index, pages: pages));
    final initialSize = tester.getSize(find.byType(LiveRoomTabViewport));

    index.value = 1;
    await tester.pump();
    index.value = 2;
    await tester.pump(const Duration(milliseconds: 16));
    index.value = 3;
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('快速页面 3').hitTestable(), findsOneWidget);
    expect(find.text('快速页面 2').hitTestable(), findsNothing);
    expect(
      tester.getSize(find.byType(LiveRoomTabViewport)),
      initialSize,
    );
    expect(find.byType(AnimatedSize), findsNothing);
    expect(
      find.descendant(
        of: find.byType(LiveRoomTabViewport),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );

    final transitionTransform = tester
        .widgetList<Transform>(
      find.ancestor(
        of: find.text('快速页面 3'),
        matching: find.byType(Transform),
      ),
    )
        .firstWhere((transform) {
      final offsetX = transform.transform.getTranslation().x;
      return offsetX > 0 && offsetX <= 8;
    });
    expect(
      transitionTransform.transform.getTranslation().x,
      inInclusiveRange(0, 8),
    );

    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('快速页面 3'), findsOneWidget);
    expect(
      tester.getSize(find.byType(LiveRoomTabViewport)),
      initialSize,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keep-alive 隐藏页会停用 Ticker、焦点、语义和指针', (tester) async {
    final index = ValueNotifier<int>(0);
    final chatActivity = _TickerActivityCounter();
    final settingsActivity = _TickerActivityCounter();
    final chatFocusNode = FocusNode();
    final settingsFocusNode = FocusNode();
    var chatTaps = 0;
    var settingsTaps = 0;
    final semanticsHandle = tester.ensureSemantics();
    final pages = <Widget>[
      _TickerActivityPage(
        pageKey: const ValueKey('chat-activity-page'),
        semanticsLabel: '聊天活动页',
        counter: chatActivity,
        focusNode: chatFocusNode,
        onTap: () => chatTaps++,
      ),
      _TickerActivityPage(
        pageKey: const ValueKey('settings-activity-page'),
        semanticsLabel: '设置活动页',
        counter: settingsActivity,
        focusNode: settingsFocusNode,
        onTap: () => settingsTaps++,
      ),
    ];
    addTearDown(index.dispose);
    addTearDown(chatFocusNode.dispose);
    addTearDown(settingsFocusNode.dispose);

    await tester.pumpWidget(_buildHarness(index: index, pages: pages));
    await tester.pump(const Duration(milliseconds: 64));
    expect(chatActivity.ticks, greaterThan(0));
    expect(settingsActivity.ticks, 0);
    expect(find.bySemanticsLabel(RegExp('聊天活动页')), findsOneWidget);

    chatFocusNode.requestFocus();
    await tester.pump();
    expect(chatFocusNode.hasFocus, isTrue);

    index.value = 1;
    await tester.pump();
    final stoppedChatTicks = chatActivity.ticks;
    await tester.pump(const Duration(milliseconds: 80));

    expect(chatActivity.ticks, stoppedChatTicks);
    expect(settingsActivity.ticks, greaterThan(0));
    expect(chatFocusNode.hasFocus, isFalse);
    expect(chatFocusNode.canRequestFocus, isFalse);
    expect(settingsFocusNode.canRequestFocus, isTrue);
    expect(find.bySemanticsLabel(RegExp('聊天活动页')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('设置活动页')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('设置活动页')));
    await tester.pump();
    expect(chatTaps, 0);
    expect(settingsTaps, 1);
    semanticsHandle.dispose();
    expect(tester.takeException(), isNull);
  });
}

Widget _buildHarness({
  required ValueNotifier<int> index,
  required List<Widget> pages,
  ValueNotifier<double>? viewportWidth,
}) {
  Widget buildViewport() {
    return ValueListenableBuilder<int>(
      valueListenable: index,
      builder: (context, selectedIndex, child) {
        return LiveRoomTabViewport(
          index: selectedIndex,
          children: pages,
        );
      },
    );
  }

  return MaterialApp(
    home: Scaffold(
      body: viewportWidth == null
          ? buildViewport()
          : ValueListenableBuilder<double>(
              valueListenable: viewportWidth,
              builder: (context, width, child) {
                return Center(
                  child: SizedBox(
                    width: width,
                    height: 420,
                    child: buildViewport(),
                  ),
                );
              },
            ),
    ),
  );
}

class _StatefulCounterPage extends StatefulWidget {
  const _StatefulCounterPage({
    required this.pageIndex,
    required this.onMount,
  });

  final int pageIndex;
  final VoidCallback onMount;

  @override
  State<_StatefulCounterPage> createState() => _StatefulCounterPageState();
}

class _StatefulCounterPageState extends State<_StatefulCounterPage> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        key: ValueKey('increment-${widget.pageIndex}'),
        onPressed: () => setState(() => _count++),
        child: Text('页面 ${widget.pageIndex} · $_count'),
      ),
    );
  }
}

class _InteractiveRenderPage extends StatelessWidget {
  const _InteractiveRenderPage({
    required this.label,
    required this.color,
    required this.counter,
    required this.onTap,
  });

  final String label;
  final Color color;
  final _RenderActivityCounter counter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _RenderActivityCounterWidget(
        counter: counter,
        child: ColoredBox(
          color: color,
          child: Center(child: Text(label)),
        ),
      ),
    );
  }
}

class _RenderActivityCounter {
  int layouts = 0;
  int paints = 0;
}

class _RenderActivityCounterWidget extends SingleChildRenderObjectWidget {
  const _RenderActivityCounterWidget({
    required this.counter,
    required super.child,
  });

  final _RenderActivityCounter counter;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderActivityCounterBox(counter);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderActivityCounterBox renderObject,
  ) {
    renderObject.counter = counter;
  }
}

class _RenderActivityCounterBox extends RenderProxyBox {
  _RenderActivityCounterBox(this._counter);

  _RenderActivityCounter _counter;

  set counter(_RenderActivityCounter value) {
    _counter = value;
  }

  @override
  void performLayout() {
    _counter.layouts++;
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _counter.paints++;
    super.paint(context, offset);
  }
}

class _TickerActivityCounter {
  int ticks = 0;
}

class _TickerActivityPage extends StatefulWidget {
  const _TickerActivityPage({
    required this.pageKey,
    required this.semanticsLabel,
    required this.counter,
    required this.focusNode,
    required this.onTap,
  });

  final Key pageKey;
  final String semanticsLabel;
  final _TickerActivityCounter counter;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  State<_TickerActivityPage> createState() => _TickerActivityPageState();
}

class _TickerActivityPageState extends State<_TickerActivityPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(() => widget.counter.ticks++)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: widget.pageKey,
      label: widget.semanticsLabel,
      button: true,
      child: Focus(
        focusNode: widget.focusNode,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: ColoredBox(
            color: Colors.green,
            child: Center(child: Text(widget.semanticsLabel)),
          ),
        ),
      ),
    );
  }
}
