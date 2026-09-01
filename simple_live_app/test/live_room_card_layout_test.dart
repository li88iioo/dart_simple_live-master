import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/widgets/live_room_card.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  final site = Site(
    id: 'layout-test',
    name: '测试平台',
    logo: '',
    iconData: Icons.live_tv_rounded,
    liveSite: LiveSite(),
  );
  final item = LiveRoomItem(
    roomId: 'room-1',
    title: '这是用于验证固定高度布局不会溢出的较长直播间标题',
    cover: '',
    userName: '这是一个较长的主播名称',
    online: 123456,
  );

  for (final width in <double>[176, 187.5, 203]) {
    for (final scale in <double>[1, 1.3, 1.5]) {
      testWidgets('直播卡片在宽 $width、文字缩放 $scale 时底部不溢出', (tester) async {
        final textScaler = TextScaler.linear(scale);
        final height = LiveRoomCard.resolveMainAxisExtent(
          cardWidth: width,
          textScaler: textScaler,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: const Size(430, 900),
                  devicePixelRatio: 3,
                  textScaler: textScaler,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: LiveRoomCard(site, item),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(LiveRoomCard)).height, height);
      });
    }
  }

  test('卡片高度会随文字缩放单调增加', () {
    const width = 187.5;
    final normal = LiveRoomCard.resolveMainAxisExtent(
      cardWidth: width,
      textScaler: TextScaler.noScaling,
    );
    final enlarged = LiveRoomCard.resolveMainAxisExtent(
      cardWidth: width,
      textScaler: const TextScaler.linear(1.5),
    );

    expect(enlarged, greaterThan(normal));
  });
}
