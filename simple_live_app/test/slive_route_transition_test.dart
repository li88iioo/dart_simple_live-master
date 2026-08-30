import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/routes/slive_route_transition.dart';

void main() {
  testWidgets('页面转场只使用固定像素 transform，不创建全屏透明层', (tester) async {
    final primary = AnimationController(
      vsync: tester,
      duration: SliveMotion.route,
      value: 1,
    );
    final secondary = AnimationController(
      vsync: tester,
      duration: SliveMotion.route,
    );

    const page = SizedBox(key: ValueKey('route-page'));
    late Widget result;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFF6F3ED)),
        home: Builder(
          builder: (context) {
            result = SliveRouteTransition().buildTransition(
              context,
              null,
              null,
              primary,
              secondary,
              page,
            );
            return result;
          },
        ),
      ),
    );

    final outerBuilder = result as AnimatedBuilder;
    final innerBuilder = outerBuilder.child! as AnimatedBuilder;
    final surface = innerBuilder.child! as ColoredBox;
    expect(surface.child, same(page));
    expect(find.byKey(const ValueKey('route-page')), findsOneWidget);

    primary.stop();
    secondary.stop();
    await tester.pumpWidget(const SizedBox.shrink());
    primary.dispose();
    secondary.dispose();
  });

  testWidgets('返回首帧立即向右移动且始终保持页面不透明', (tester) async {
    final primary = AnimationController(
      vsync: tester,
      duration: SliveMotion.route,
      value: 1,
    );
    final secondary = AnimationController(
      vsync: tester,
      duration: SliveMotion.route,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => SliveRouteTransition().buildTransition(
            context,
            null,
            null,
            primary,
            secondary,
            const SizedBox(key: ValueKey('route-page')),
          ),
        ),
      ),
    );

    Offset pageOffset() => tester.getTopLeft(
          find.byKey(const ValueKey('route-page')),
        );

    final initialOffset = pageOffset();
    primary.reverse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(pageOffset().dx, greaterThan(initialOffset.dx));

    primary.stop();
    secondary.stop();
    await tester.pumpWidget(const SizedBox.shrink());
    primary.dispose();
    secondary.dispose();
  });

  testWidgets('下层页面在返回期间连续回到原位', (tester) async {
    final primary = AnimationController(
      vsync: tester,
      duration: SliveMotion.route,
      value: 1,
    );
    final secondary = AnimationController(
      vsync: tester,
      duration: SliveMotion.route,
      value: 1,
    );

    const pageKey = ValueKey('covered-page');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => SliveRouteTransition().buildTransition(
            context,
            null,
            null,
            primary,
            secondary,
            const SizedBox(key: pageKey),
          ),
        ),
      ),
    );

    final initialOffset = tester.getTopLeft(find.byKey(pageKey)).dx;
    expect(initialOffset, lessThan(0));

    secondary.reverse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final nextOffset = tester.getTopLeft(find.byKey(pageKey)).dx;
    expect(nextOffset, greaterThan(initialOffset));
    expect(nextOffset, lessThanOrEqualTo(0));

    primary.stop();
    secondary.stop();
    await tester.pumpWidget(const SizedBox.shrink());
    primary.dispose();
    secondary.dispose();
  });

  testWidgets('系统关闭动画时保留不透明页面底色但不添加位移动画', (tester) async {
    const page = SizedBox(key: ValueKey('reduced-motion-page'));
    final primary = AnimationController(vsync: tester);
    final secondary = AnimationController(vsync: tester);

    late Widget result;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              result = SliveRouteTransition().buildTransition(
                context,
                null,
                null,
                primary,
                secondary,
                page,
              );
              return result;
            },
          ),
        ),
      ),
    );

    expect(result, isA<ColoredBox>());
    expect(find.byType(Transform), findsNothing);
    expect(find.byKey(const ValueKey('reduced-motion-page')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    primary.dispose();
    secondary.dispose();
  });
}
