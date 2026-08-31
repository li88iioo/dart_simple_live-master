import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/routes/app_pages.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/routes/slive_route_transition.dart';

const _pageKey = ValueKey<String>('route-page');

void main() {
  test('只有直播间使用无快照顶层转场且下层页面不参与视差', () {
    final liveRoute = AppPages.routes.singleWhere(
      (route) => route.name == RoutePath.kLiveRoomDetail,
    );
    final settingsRoute = AppPages.routes.singleWhere(
      (route) => route.name == RoutePath.kAppstyleSetting,
    );

    expect(liveRoute.customTransition, isA<SliveRouteTransition>());
    expect(liveRoute.showCupertinoParallax, isFalse);
    expect(settingsRoute.customTransition, isNull);
  });

  testWidgets('直播间转场使用真正不透明的页面表面且不创建整页重绘边界', (tester) async {
    final primary = AnimationController(
      vsync: tester,
      duration: SliveMotion.route,
      value: 1,
    );
    final secondary = AnimationController(
      vsync: tester,
      duration: SliveMotion.route,
    );

    const page = SizedBox(key: _pageKey);
    late Widget result;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: const Color(0x80F6F3ED)),
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

    final clip = result as ClipRect;
    final slide = clip.child! as SlideTransition;
    final surface = slide.child! as ColoredBox;
    expect(surface.color.a, 1);
    expect(surface.child, same(page));
    expect(slide.child, isNot(isA<RepaintBoundary>()));
    expect(find.byType(Opacity), findsNothing);

    primary.stop();
    secondary.stop();
    await tester.pumpWidget(const SizedBox.shrink());
    primary.dispose();
    secondary.dispose();
  });

  testWidgets('返回首帧立即向右移动且保持连续', (tester) async {
    final primary = AnimationController(
      vsync: tester,
      duration: SliveMotion.route,
      value: 1,
    );
    final secondary = AnimationController(vsync: tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => SliveRouteTransition().buildTransition(
            context,
            null,
            null,
            primary,
            secondary,
            const SizedBox(key: _pageKey),
          ),
        ),
      ),
    );

    final initialOffset = tester.getTopLeft(find.byKey(_pageKey)).dx;
    primary.reverse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final firstOffset = tester.getTopLeft(find.byKey(_pageKey)).dx;
    await tester.pump(const Duration(milliseconds: 48));
    final secondOffset = tester.getTopLeft(find.byKey(_pageKey)).dx;

    expect(firstOffset, greaterThan(initialOffset));
    expect(secondOffset, greaterThan(firstOffset));
    expect(find.byType(Opacity), findsNothing);

    primary.stop();
    secondary.stop();
    await tester.pumpWidget(const SizedBox.shrink());
    primary.dispose();
    secondary.dispose();
  });

  testWidgets('下层路由动画不会移动直播间页面', (tester) async {
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
            const SizedBox(key: _pageKey),
          ),
        ),
      ),
    );

    final initialOffset = tester.getTopLeft(find.byKey(_pageKey)).dx;
    secondary.forward(from: 0);
    await tester.pump();
    await tester.pump(SliveMotion.route * 0.6);

    expect(tester.getTopLeft(find.byKey(_pageKey)).dx, initialOffset);

    primary.stop();
    secondary.stop();
    await tester.pumpWidget(const SizedBox.shrink());
    primary.dispose();
    secondary.dispose();
  });

  testWidgets('系统关闭动画时只保留不透明页面底色', (tester) async {
    const page = SizedBox(key: _pageKey);
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
    expect(find.byType(SlideTransition), findsNothing);
    expect(find.byKey(_pageKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    primary.dispose();
    secondary.dispose();
  });
}
