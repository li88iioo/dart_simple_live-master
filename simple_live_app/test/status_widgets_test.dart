import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/status/app_empty_widget.dart';
import 'package:simple_live_app/widgets/status/app_error_widget.dart';
import 'package:simple_live_app/widgets/status/app_loadding_widget.dart';

void main() {
  testWidgets('短加载阶段保留固定占位且延迟显示指示器', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppStyle.light(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6F8FD8),
          ),
          glassMode: SliveGlassMode.soft,
        ),
        home: const Scaffold(body: AppLoaddingWidget()),
      ),
    );

    final beforeSize = tester.getSize(find.byType(AnimatedOpacity));
    expect(beforeSize, const Size(48, 48));
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0);

    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.getSize(find.byType(AnimatedOpacity)), beforeSize);
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空状态在横屏大字体下可滚动且不溢出', (tester) async {
    await _setCompactLandscape(tester);
    await tester.pumpWidget(_testApp(const AppEmptyWidget(onRefresh: _noop)));
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('错误状态在横屏大字体下可滚动且不溢出', (tester) async {
    await _setCompactLandscape(tester);
    await tester.pumpWidget(
      _testApp(
        const AppErrorWidget(
          errorMsg: '网络连接失败，请检查网络设置后重新加载',
          onRefresh: _noop,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

Future<void> _setCompactLandscape(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(640, 360);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _testApp(Widget body) {
  return MaterialApp(
    theme: AppStyle.light(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6F8FD8),
      ),
      glassMode: SliveGlassMode.soft,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.5),
      ),
      child: child!,
    ),
    home: Scaffold(
      appBar: AppBar(title: const Text('状态页')),
      body: body,
    ),
  );
}
