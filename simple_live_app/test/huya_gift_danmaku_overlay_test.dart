import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_event.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_overlay.dart';

void main() {
  for (final placement in HuyaGiftOverlayPlacement.values) {
    testWidgets('守护 ${placement.name} 不冒充普通礼物并保持原有边缘布局', (tester) async {
      final event = HuyaGiftDanmakuEvent.fromMessage(
          LiveMessage(
              type: LiveMessageType.gift,
              userName: '很长的完整守护用户名',
              message: '',
              color: LiveMessageColor.white,
              data: const {
                'kind': 'guardianOpen',
                'giftName': '守护',
                'guardianLevel': 5,
                'guardianOpenDays': 93,
                'guardianLastLevel': 0,
                'countKnown': false,
              }),
          sequence: 1);
      await tester.pumpWidget(_testHost(HuyaGiftPresentation(
          event: event,
          placement: placement,
          maxWidth: 260,
          reduceMotion: true)));
      expect(find.text('很长的完整守护用户名'), findsOneWidget);
      expect(find.text('开通 守护'), findsOneWidget);
      expect(find.text('V5'), findsOneWidget);
      expect(find.text('93天'), findsOneWidget);
      expect(find.text('×1'), findsNothing);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final fixtureName in ['specialGiftV2', 'specialGiftAsciiV2']) {
      testWidgets('type16 $fixtureName 从 core 到 ${placement.name} 图像卡片回放',
          (tester) async {
        final fixtures = jsonDecode(File(
                '../simple_live_core/test/platforms/huya/fixtures/gift_wire.json')
            .readAsStringSync()) as Map;
        final command =
            base64Decode(fixtures[fixtureName]['commandBase64'] as String);
        final messages = <LiveMessage>[];
        final danmaku = HuyaDanmaku()
          ..danmakuArgs =
              HuyaDanmakuArgs(ayyuid: 2272316519, topSid: 1, subSid: 2)
          ..onMessage = messages.add;
        danmaku.decodeMessage(command);
        expect(messages, hasLength(1));
        final event =
            HuyaGiftDanmakuEvent.fromMessage(messages.single, sequence: 1);
        final urls = <String>[];
        await tester.pumpWidget(_testHost(HuyaGiftPresentation(
            event: event,
            placement: placement,
            maxWidth: 280,
            reduceMotion: true,
            imageProviderBuilder: (url) {
              urls.add(url);
              return _memoryImage();
            })));
        await tester.pump();
        expect(find.text('完整的特殊礼物送礼用户'), findsOneWidget);
        expect(find.text('送出 测试特殊守护礼物'), findsOneWidget);
        expect(find.text('×2'), findsOneWidget);
        expect(
            urls,
            contains(fixtureName == 'specialGiftV2'
                ? 'https://cdn.example.com/special/shield.webp'
                : 'https://cdn.example.com/special/gift.png'));
        // 二进制资源 URL 只给图像加载，不得泄漏到互动文案中。
        expect(event.interactionText, isEmpty);
        expect(find.byType(Image), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [280.0, 320.0, 360.0, 390.0, 600.0, 720.0, 1000.0]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('播放器礼物 ${width}px 字体倍率 $textScale 无布局溢出', (tester) async {
        final maxWidth = resolveHuyaGiftPlayerMaxWidth(width);
        await tester.pumpWidget(_testHost(MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: SizedBox(
            width: width,
            height: 640,
            child: Center(
                child: HuyaGiftPresentation(
              event: _event(
                nominalTotalYb: null,
                giftImageUrl: '',
                giftEffectImageUrl: '',
                sender: '完整送礼用户',
                giftName: '完整礼物名称',
                count: 999999,
              ),
              placement: HuyaGiftOverlayPlacement.player,
              maxWidth: maxWidth,
              reduceMotion: true,
            )),
          ),
        )));
        expect(tester.takeException(), isNull);
        final size = tester.getSize(find.byKey(
          const ValueKey('huya-player-edge-gift-card'),
        ));
        expect(size.width, lessThanOrEqualTo(maxWidth));
        expect(size.height, greaterThanOrEqualTo(huyaPlayerGiftMinHeight));
        expect(find.text('完整送礼用户'), findsOneWidget);
        expect(find.text('送出 完整礼物名称'), findsOneWidget);
        expect(find.text('×999999'), findsOneWidget);
      });
    }
  }

  testWidgets('礼物 transitionBuilder 不累积额外动画状态监听', (tester) async {
    Get.testMode = true;
    Get.put<AppSettingsController>(_GiftTestSettings());
    final controller = LiveRoomController(
      pSite: Sites.allSites['huya']!,
      pRoomId: 'test-room',
    );
    controller.liveStatus.value = true;
    controller.activeHuyaGiftEffect.value = _event(
      nominalTotalYb: null,
      giftImageUrl: '',
      giftEffectImageUrl: '',
    );
    try {
      await tester.pumpWidget(_testHost(Stack(children: [
        HuyaGiftDanmakuOverlay(controller: controller),
      ])));
      final switcher =
          tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
      final animation = _TrackingGiftAnimation();
      for (var i = 0; i < 100; i++) {
        switcher.transitionBuilder(const SizedBox(), animation);
      }
      expect(animation.statusListeners, isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox());
      controller.scrollController.dispose();
      Get.reset();
    }
  });

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

  testWidgets('礼物图片候选更新时丢弃旧回调且不会越界', (tester) async {
    final firstEvent = _event(
      nominalTotalYb: null,
      giftImageUrl: 'https://cdn.example.com/gift/broken-a.webp',
      giftEffectImageUrl: '',
      giftImageUrls: const <String>[
        'https://cdn.example.com/gift/broken-a.webp',
        'https://cdn.example.com/gift/broken-b.webp',
      ],
    );
    final updatedEvent = _event(
      nominalTotalYb: null,
      giftImageUrl: 'https://cdn.example.com/gift/safe.webp',
      giftEffectImageUrl: '',
      giftImageUrls: const <String>[
        'https://cdn.example.com/gift/safe.webp',
      ],
    );

    ImageProvider<Object> providerFor(String url) {
      if (url.contains('/safe.webp')) return _memoryImage();
      return MemoryImage(Uint8List(0));
    }

    Widget presentation(HuyaGiftDanmakuEvent event) {
      return _testHost(
        HuyaGiftPresentation(
          event: event,
          placement: HuyaGiftOverlayPlacement.chat,
          maxWidth: huyaChatGiftMaxWidth,
          reduceMotion: true,
          imageProviderBuilder: providerFor,
        ),
      );
    }

    await tester.pumpWidget(presentation(firstEvent));
    await tester.pump();
    await tester.pumpWidget(presentation(updatedEvent));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('huya-gift-remote-image')),
      findsOneWidget,
    );
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
  List<String> giftImageUrls = const <String>[],
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
    giftImageUrls: giftImageUrls,
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

class _GiftTestSettings extends AppSettingsController {
  // 本测试只使用内存默认值，显式隔离持久化/平台初始化。
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _TrackingGiftAnimation extends Animation<double> {
  final statusListeners = <AnimationStatusListener>{};
  @override
  double get value => 1;
  @override
  AnimationStatus get status => AnimationStatus.completed;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  void addStatusListener(AnimationStatusListener listener) =>
      statusListeners.add(listener);
  @override
  void removeStatusListener(AnimationStatusListener listener) =>
      statusListeners.remove(listener);
}
