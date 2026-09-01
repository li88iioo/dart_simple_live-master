import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_event.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_overlay.dart';

void main() {
  test('播放器礼物宽度受 24% 与 300px 双重限制并固定左下', () {
    expect(resolveHuyaGiftPlayerMaxWidth(1000), 240);
    expect(resolveHuyaGiftPlayerMaxWidth(1920), 300);
    expect(
      resolveHuyaGiftOverlayAlignment(HuyaGiftOverlayPlacement.player),
      Alignment.bottomLeft,
    );
    expect(
      resolveHuyaGiftOverlayAlignment(HuyaGiftOverlayPlacement.chat),
      Alignment.topLeft,
    );
  });

  testWidgets('聊天礼物使用轻量自适应高度并完整保留用户名', (tester) async {
    final event = _event(
      nominalTotalYb: null,
      giftImageUrl: 'https://cdn.example.com/gift/food.webp',
      giftEffectImageUrl: 'https://cdn.example.com/gift/food-effect.gif',
      sender: '这是一个需要完整显示的送礼用户名',
      giftName: '一份名字也需要完整显示的虎牙限定礼物',
      count: 999999,
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
    final cardSize = tester.getSize(card);
    expect(cardSize.width, greaterThan(huyaChatGiftMinWidth));
    expect(cardSize.width, lessThanOrEqualTo(huyaChatGiftMaxWidth));
    expect(cardSize.height, greaterThanOrEqualTo(huyaChatGiftMinHeight));
    expect(cardSize.height, lessThan(140));
    final sender = find.text('这是一个需要完整显示的送礼用户名');
    expect(sender, findsOneWidget);
    final senderText = tester.widget<Text>(sender);
    expect(senderText.maxLines, isNull);
    expect(senderText.overflow, isNull);
    final giftName = find.text('送出 一份名字也需要完整显示的虎牙限定礼物');
    expect(giftName, findsOneWidget);
    final giftNameText = tester.widget<Text>(giftName);
    expect(giftNameText.maxLines, isNull);
    expect(giftNameText.overflow, isNull);
    final count = find.text('×999999');
    expect(count, findsOneWidget);
    final countText = tester.widget<Text>(count);
    expect(countText.overflow, isNull);
    expect(
        find.byKey(const ValueKey('huya-gift-remote-image')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.byKey(const ValueKey('huya-chat-gift-backdrop')),
      findsOneWidget,
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('短礼物文案按内容收拢宽度而不是固定撑满', (tester) async {
    final event = _event(
      nominalTotalYb: null,
      giftImageUrl: 'https://cdn.example.com/gift/food.webp',
      giftEffectImageUrl: '',
      sender: '清凉甜心',
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

    final size = tester.getSize(
      find.byKey(const ValueKey('huya-chat-gift-card')),
    );
    expect(size.width, greaterThanOrEqualTo(huyaChatGiftMinWidth));
    expect(size.width, lessThan(huyaChatGiftMaxWidth));
  });

  testWidgets('互动礼物展示服务端真实文案且允许自然换行', (tester) async {
    final event = _event(
      nominalTotalYb: null,
      giftImageUrl: 'https://cdn.example.com/gift/light.webp',
      giftEffectImageUrl: '',
      giftName: '告白灯牌',
      interactionText: '今天也要一直喜欢你，愿每次相遇都闪闪发光',
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

    final text = find.text('今天也要一直喜欢你，愿每次相遇都闪闪发光');
    expect(text, findsOneWidget);
    final textWidget = tester.widget<Text>(text);
    expect(textWidget.maxLines, isNull);
    expect(textWidget.overflow, isNull);
    expect(
      find.byKey(const ValueKey('huya-gift-interaction-text')),
      findsOneWidget,
    );
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
    final cardSize = tester.getSize(card);
    expect(cardSize.width, 288);
    expect(cardSize.height, greaterThanOrEqualTo(huyaPlayerGiftMinHeight));
    expect(cardSize.height, lessThan(100));
    expect(
        find.byKey(const ValueKey('huya-gift-remote-image')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
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
  String sender = '测试用户',
  String giftName = '虎粮',
  int count = 3,
  String interactionText = '',
}) {
  return HuyaGiftDanmakuEvent(
    id: 'gift-test',
    sender: sender,
    senderIcon: '',
    giftName: giftName,
    giftId: 1,
    count: count,
    effectType: 9,
    colorEffectType: 9,
    comboScore: 99999,
    effectResourceUrl: '',
    effectWebResourceUrl: '',
    effectPcResourceUrl: '',
    effectResourceAttr: '',
    interactionText: interactionText,
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
