import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';

void main() {
  testWidgets('点击独立操作按钮不会唤起直播间悬浮栏', (tester) async {
    var revealCount = 0;
    var latestCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveRoomChromeRevealSurface(
            onReveal: () => revealCount++,
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.white)),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Material(
                    child: InkWell(
                      key: const ValueKey('latest-action'),
                      onTap: () => latestCount++,
                      child: const SizedBox(
                        width: 72,
                        height: 40,
                        child: Center(child: Text('最新')),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('latest-action')));
    await tester.pump();
    expect(latestCount, 1);
    expect(revealCount, 0);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(revealCount, 1);
  });
}
