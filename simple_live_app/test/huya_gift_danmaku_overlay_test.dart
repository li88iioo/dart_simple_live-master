import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_event.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_overlay.dart';

void main() {
  test('播放器礼物宽度受 28% 与 340px 双重限制并固定左下', () {
    expect(resolveHuyaGiftPlayerMaxWidth(1000), 280);
    expect(resolveHuyaGiftPlayerMaxWidth(1920), 340);
    expect(
      resolveHuyaGiftOverlayAlignment(HuyaGiftOverlayPlacement.player),
      Alignment.bottomLeft,
    );
    expect(
      resolveHuyaGiftOverlayAlignment(HuyaGiftOverlayPlacement.chat),
      Alignment.topRight,
    );
  });

  testWidgets('聊天礼物是 252×64 内的单图横向通知', (tester) async {
    final event = _event(
      nominalTotalYb: null,
      giftImageUrl: 'https://cdn.example.com/gift/food.webp',
      giftEffectImageUrl: 'https://cdn.example.com/gift/food-effect.gif',
    );

    await tester.pumpWidget(
      _testHost(
        HuyaGiftPresentation(
          event: event,
          placement: HuyaGiftOverlayPlacement.chat,
          maxWidth: huyaChatGiftMaxWidth,
          reduceMotion: true,
          imageProviderBuilder: (_) => _memoryImage(),
        ),
      ),
    );
    await tester.pump();

    final card = find.byKey(const ValueKey('huya-chat-gift-card'));
    expect(card, findsOneWidget);
    expect(tester.getSize(card), const Size(252, 64));
    expect(find.text('虎粮'), findsOneWidget);
    expect(find.text('测试用户'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('huya-gift-remote-image')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.byKey(const ValueKey('huya-highlight-micro-particles')),
      findsNothing,
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('高价值礼物仍是边缘卡且只绘制一个远程礼物资源', (tester) async {
    final event = _event(
      nominalTotalYb: huyaGiftHighlightThresholdYb,
      giftImageUrl: 'https://cdn.example.com/gift/rocket.webp',
      giftEffectImageUrl: 'https://cdn.example.com/gift/rocket-effect.gif',
    );

    expect(
      selectHuyaGiftPresentationImageUrl(event),
      'https://cdn.example.com/gift/rocket.webp',
    );

    await tester.pumpWidget(
      _testHost(
        HuyaGiftPresentation(
          event: event,
          placement: HuyaGiftOverlayPlacement.player,
          maxWidth: resolveHuyaGiftPlayerMaxWidth(1200),
          reduceMotion: true,
          imageProviderBuilder: (_) => _memoryImage(),
        ),
      ),
    );
    await tester.pump();

    final card = find.byKey(const ValueKey('huya-player-edge-gift-card'));
    expect(card, findsOneWidget);
    expect(tester.getSize(card), const Size(320, 68));
    expect(
        find.byKey(const ValueKey('huya-gift-remote-image')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.byKey(const ValueKey('huya-highlight-micro-particles')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('huya-player-center-stage')),
      findsNothing,
    );
    expect(find.byType(BackdropFilter), findsNothing);

    for (final element in find.byType(DecoratedBox).evaluate()) {
      final decoration = (element.widget as DecoratedBox).decoration;
      if (decoration is BoxDecoration) {
        expect(decoration.boxShadow, anyOf(isNull, isEmpty));
      }
    }
  });
}

Widget _testHost(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

HuyaGiftDanmakuEvent _event({
  required int? nominalTotalYb,
  required String giftImageUrl,
  required String giftEffectImageUrl,
}) {
  return HuyaGiftDanmakuEvent(
    id: 'gift-test',
    sender: '测试用户',
    senderIcon: '',
    giftName: '虎粮',
    giftId: 1,
    count: 3,
    effectType: 9,
    colorEffectType: 9,
    comboScore: 99999,
    effectResourceUrl: '',
    effectWebResourceUrl: '',
    effectPcResourceUrl: '',
    effectResourceAttr: '',
    giftImageUrl: giftImageUrl,
    giftEffectImageUrl: giftEffectImageUrl,
    nominalTotalYb: nominalTotalYb,
  );
}

MemoryImage _memoryImage() {
  return MemoryImage(
    Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    ),
  );
}
