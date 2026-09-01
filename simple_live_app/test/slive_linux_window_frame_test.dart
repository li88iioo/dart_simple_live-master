import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/services/window_service.dart';
import 'package:simple_live_app/widgets/desktop/slive_linux_window_frame.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');
  final calls = <String>[];
  var maximized = false;

  setUp(() {
    calls.clear();
    maximized = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isMaximized':
          return maximized;
        case 'maximize':
          maximized = true;
          return null;
        case 'unmaximize':
          maximized = false;
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    Get.reset();
  });

  testWidgets('Linux window frame keeps content mounted while title bar hides',
      (tester) async {
    final service = Get.put(WindowService());

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SliveLinuxWindowFrame(child: child!),
        home: const ColoredBox(
          color: Colors.white,
          child: Text('window content'),
        ),
      ),
    );

    expect(find.text('Slive'), findsOneWidget);
    expect(find.text('window content'), findsOneWidget);
    expect(find.byIcon(Icons.horizontal_rule_rounded), findsOneWidget);
    expect(find.byIcon(Icons.crop_square_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    service.isFullScreen.value = true;
    await tester.pump();

    expect(find.text('Slive'), findsNothing);
    expect(find.text('window content'), findsOneWidget);

    service.isFullScreen.value = false;
    service.isMaximized.value = true;
    await tester.pump();

    expect(find.byIcon(Icons.filter_none_rounded), findsOneWidget);
    expect(find.text('window content'), findsOneWidget);
  });

  testWidgets('Linux title bar controls receive clicks above drag regions',
      (tester) async {
    Get.put(WindowService());

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SliveLinuxWindowFrame(child: child!),
        home: const ColoredBox(color: Colors.white),
      ),
    );

    await tester.tap(find.byIcon(Icons.horizontal_rule_rounded));
    await tester.pump();
    expect(calls, contains('minimize'));

    calls.clear();
    await tester.tap(find.byIcon(Icons.crop_square_rounded));
    await tester.pump();
    expect(calls, containsAllInOrder(['isMaximized', 'maximize']));
    expect(find.byIcon(Icons.filter_none_rounded), findsOneWidget);

    calls.clear();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(calls, contains('close'));
  });

  testWidgets('Linux title bar hover does not depend on a Navigator overlay',
      (tester) async {
    Get.put(WindowService());

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SliveLinuxWindowFrame(child: child!),
        home: const ColoredBox(color: Colors.white),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byIcon(Icons.horizontal_rule_rounded)),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.horizontal_rule_rounded));
    await tester.pump();
    expect(calls, contains('minimize'));

    await mouse.removePointer();
  });
}
