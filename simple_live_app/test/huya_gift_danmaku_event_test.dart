import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_event.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  test('从虎牙礼物消息提取图片特效数据', () {
    final event = HuyaGiftDanmakuEvent.fromMessage(
      LiveMessage(
        type: LiveMessageType.gift,
        userName: 'fallback-user',
        message: 'gift',
        color: LiveMessageColor.white,
        data: const {
          'messageId': 42,
          'sender': '送礼用户',
          'senderIcon': '//example.com/avatar.png',
          'senderUid': 100,
          'giftName': '星光',
          'giftId': 9,
          'count': 6,
          'effectType': 1,
          'colorEffectType': 2,
          'comboScore': 120,
          'catalogNominalTotalYb': 1800,
          'giftImageUrls': [
            '//cdn.example.com/catalog/star-108.png',
            'https://cdn.example.com/catalog/star.svga',
          ],
          'giftEffectUrls': [
            'https://cdn.example.com/catalog/star-effect.gif',
          ],
          'resourceUrl': 'https://cdn.example.com/effects/star.webp',
          'webResourceUrl': 'https://cdn.example.com/effects/star.svga',
          'pcResourceUrl': 'https://cdn.example.com/effects/star.zip',
          'resourceAttr': '{"width": 480, "height": 480}',
        },
      ),
      sequence: 1,
    );

    expect(event.id, 'message-42');
    expect(event.sender, '送礼用户');
    expect(event.senderIcon, '//example.com/avatar.png');
    expect(event.giftName, '星光');
    expect(event.giftId, 9);
    expect(event.count, 6);
    expect(event.nominalTotalYb, 1800);
    expect(event.effectResourceUrl, contains('star.webp'));
    expect(event.effectWebResourceUrl, contains('star.svga'));
    expect(event.effectPcResourceUrl, contains('star.zip'));
    expect(event.effectResourceAttr, contains('width'));
    expect(
      event.giftImageUrl,
      'https://cdn.example.com/catalog/star-108.png',
    );
    expect(
      event.giftEffectImageUrl,
      'https://cdn.example.com/catalog/star-effect.gif',
    );
    expect(event.isHighlight, isTrue);
  });

  test('缺失结构化字段时使用安全回退并限制礼物数量', () {
    final event = HuyaGiftDanmakuEvent.fromMessage(
      LiveMessage(
        type: LiveMessageType.gift,
        userName: '回退用户',
        message: 'gift',
        color: LiveMessageColor.white,
        data: const {'count': 0},
      ),
      sequence: 8,
    );

    expect(event.sender, '回退用户');
    expect(event.giftName, '礼物');
    expect(event.giftId, 0);
    expect(event.count, 1);
    expect(event.giftImageUrl, isNull);
    expect(event.id, endsWith('-8'));
  });

  test('互动礼物优先展示服务端 customText 且不伪造文案', () {
    final customTextEvent = HuyaGiftDanmakuEvent.fromMessage(
      LiveMessage(
        type: LiveMessageType.gift,
        userName: '送礼用户',
        message: 'gift',
        color: LiveMessageColor.white,
        data: const {
          'giftName': '告白灯牌',
          'customText': '今天也要一直喜欢你',
          'sendContent': '备用服务端文案',
        },
      ),
      sequence: 2,
    );
    final plainContentEvent = HuyaGiftDanmakuEvent.fromMessage(
      LiveMessage(
        type: LiveMessageType.gift,
        userName: '送礼用户',
        message: 'gift',
        color: LiveMessageColor.white,
        data: const {'sendContent': '来自服务端的互动文字'},
      ),
      sequence: 3,
    );
    final structuredContentEvent = HuyaGiftDanmakuEvent.fromMessage(
      LiveMessage(
        type: LiveMessageType.gift,
        userName: '送礼用户',
        message: 'gift',
        color: LiveMessageColor.white,
        data: const {'sendContent': '{"supportCamp":{"id":1}}'},
      ),
      sequence: 4,
    );

    expect(customTextEvent.interactionText, '今天也要一直喜欢你');
    expect(plainContentEvent.interactionText, '来自服务端的互动文字');
    expect(structuredContentEvent.interactionText, isEmpty);
  });

  test('6541 高价值特效事件可提取图标、动画与互动文案', () {
    final event = HuyaGiftDanmakuEvent.fromMessage(
      LiveMessage(
        type: LiveMessageType.gift,
        userName: '高价值用户',
        message: 'gift',
        color: LiveMessageColor.white,
        data: const {
          'kind': 'giftEffectNotice',
          'messageId': 6541001,
          'effectId': 70001,
          'senderUid': 8899,
          'sender': '高价值用户',
          'giftName': '星河飞船',
          'giftId': 70001,
          'count': 1,
          'payTotal': 188000,
          'isBigEffect': true,
          'effectParams': {
            'iconUrl': '//cdn.example.com/gift/starship.webp',
            'animationUrl': 'https://cdn.example.com/gift/starship.svga',
            'copy': '{"content":"一路星河送给你"}',
          },
        },
      ),
      sequence: 12,
    );

    expect(event.id, 'giftEffectNotice-message-6541001');
    expect(
      event.giftEffectImageUrl,
      'https://cdn.example.com/gift/starship.webp',
    );
    expect(
      event.giftAnimationUrls,
      contains('https://cdn.example.com/gift/starship.svga'),
    );
    expect(event.interactionText, '一路星河送给你');
    expect(event.nominalTotalYb, 188000);
    expect(event.isBigEffect, isTrue);
    expect(event.isHighlight, isTrue);
  });

  test('服务端 payTotal 可在目录价格缺失时识别高价值礼物', () {
    final event = HuyaGiftDanmakuEvent.fromMessage(
      LiveMessage(
        type: LiveMessageType.gift,
        userName: '高价值用户',
        message: 'gift',
        color: LiveMessageColor.white,
        data: const {
          'giftName': '星河',
          'payTotal': huyaGiftHighlightThresholdYb,
        },
      ),
      sequence: 5,
    );

    expect(event.nominalTotalYb, huyaGiftHighlightThresholdYb);
    expect(event.isHighlight, isTrue);
  });

  test('只允许明确的 HTTP 图片扩展名进入图片解码器', () {
    expect(
      isSafeHuyaGiftImageUrl('//cdn.example.com/gift/rocket.PNG?version=2'),
      isTrue,
    );
    expect(
      isSafeHuyaGiftImageUrl('https://cdn.example.com/gift/rocket.jpeg#v2'),
      isTrue,
    );
    expect(
      isSafeHuyaGiftImageUrl('http://cdn.example.com/gift/rocket.gif'),
      isTrue,
    );
    expect(
      isSafeHuyaGiftImageUrl('https://cdn.example.com/gift/rocket.svga'),
      isFalse,
    );
    expect(
      isSafeHuyaGiftImageUrl('https://cdn.example.com/gift/rocket.png.zip'),
      isFalse,
    );
    expect(
      isSafeHuyaGiftImageUrl('data:image/png;base64,AAAA'),
      isFalse,
    );
    expect(isSafeHuyaGiftImageUrl('/relative/gift.webp'), isFalse);
  });

  test('图片资源优先使用目录图标并安全回退到广播资源', () {
    expect(
      selectHuyaGiftImageUrl(
        catalogUrls: const [
          'https://cdn.example.com/gift/catalog.svga',
          '//cdn.example.com/gift/catalog.webp',
        ],
        resourceUrl: '//cdn.example.com/gift/fallback.webp',
        webResourceUrl: 'https://cdn.example.com/gift/effect.svga',
        pcResourceUrl: 'https://cdn.example.com/gift/desktop.png',
      ),
      'https://cdn.example.com/gift/catalog.webp',
    );
    expect(
      selectHuyaGiftImageUrl(
        resourceUrl: '//cdn.example.com/gift/fallback.webp',
        webResourceUrl: 'https://cdn.example.com/gift/effect.svga',
        pcResourceUrl: 'https://cdn.example.com/gift/desktop.png',
      ),
      'https://cdn.example.com/gift/fallback.webp',
    );
    expect(
      selectHuyaGiftImageUrl(
        resourceUrl: 'https://cdn.example.com/gift/effect.zip',
        webResourceUrl: 'https://cdn.example.com/gift/effect.json',
        pcResourceUrl: 'https://cdn.example.com/gift/effect.mp4',
      ),
      isNull,
    );
  });

  test('已知为低价礼物时不会因效果位误判为全屏高亮', () {
    final event = HuyaGiftDanmakuEvent.fromMessage(
      LiveMessage(
        type: LiveMessageType.gift,
        userName: '测试用户',
        message: 'gift',
        color: LiveMessageColor.white,
        data: const {
          'giftName': '超粉虎粮',
          'count': 1,
          'effectType': 1,
          'colorEffectType': 1,
          'comboScore': 12,
          'catalogNominalTotalYb': 10,
        },
      ),
      sequence: 10,
    );

    expect(event.isHighlight, isFalse);
  });

  test('目录价格未知时效果位和连击分都不会升级高亮', () {
    final event = HuyaGiftDanmakuEvent.fromMessage(
      LiveMessage(
        type: LiveMessageType.gift,
        userName: '未知价格用户',
        message: 'gift',
        color: LiveMessageColor.white,
        data: const {
          'giftName': '虎粮',
          'count': 99,
          'effectType': 9,
          'colorEffectType': 9,
          'comboScore': 99999,
        },
      ),
      sequence: 11,
    );

    expect(event.nominalTotalYb, isNull);
    expect(event.isHighlight, isFalse);
  });

  test('同一路径的不同 CDN 查询变体会保留为独立礼物资源', () {
    final event = HuyaGiftDanmakuEvent.fromMessage(
      LiveMessage(
        type: LiveMessageType.gift,
        userName: '测试用户',
        message: 'gift',
        color: LiveMessageColor.white,
        data: const {
          'giftName': '虎粮',
          'giftImageUrls': [
            '//cdn.example.com/gift/food.webp?size=108',
          ],
          'giftEffectUrls': [
            'https://cdn.example.com/gift/food.webp?animation=1',
          ],
        },
      ),
      sequence: 9,
    );

    expect(
      event.giftImageUrl,
      'https://cdn.example.com/gift/food.webp?size=108',
    );
    expect(
      event.giftEffectImageUrl,
      'https://cdn.example.com/gift/food.webp?animation=1',
    );
  });

  test('礼物队列有上限并优先保留最新待展示事件', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 2);
    final first = _event('first');
    final second = _event('second');
    final third = _event('third');
    final fourth = _event('fourth');

    expect(queue.enqueue(first), isTrue);
    expect(queue.enqueue(second), isFalse);
    expect(queue.enqueue(third), isFalse);
    expect(queue.enqueue(fourth), isFalse);
    expect(queue.pendingCount, 2);

    expect(queue.advance()?.id, third.id);
    expect(queue.advance()?.id, fourth.id);
    expect(queue.advance(), isNull);
  });

  test('普通礼物洪峰不会把待展示的高价值礼物挤出队列', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 3);
    final active = _event('active');
    final highValue = _event(
      'high-value',
      nominalTotalYb: huyaGiftHighlightThresholdYb,
    );

    expect(queue.enqueue(active), isTrue);
    queue.enqueue(_event('normal-1'));
    queue.enqueue(highValue);
    queue.enqueue(_event('normal-2'));
    queue.enqueue(_event('normal-3'));
    queue.enqueue(_event('normal-4'));

    expect(queue.pendingCount, 3);
    expect(queue.advance()?.id, highValue.id);
    expect(queue.advance()?.isHighlight, isFalse);
    expect(queue.advance()?.isHighlight, isFalse);
  });

  test('普通礼物和高价值礼物使用不同的低干扰停留时间', () {
    final normal = _event('normal');
    final highlight = HuyaGiftDanmakuEvent(
      id: 'highlight',
      sender: '用户',
      senderIcon: '',
      giftName: '高价值礼物',
      giftId: 2,
      count: 1,
      effectType: 0,
      colorEffectType: 0,
      comboScore: 0,
      effectResourceUrl: '',
      effectWebResourceUrl: '',
      effectPcResourceUrl: '',
      effectResourceAttr: '',
      nominalTotalYb: huyaGiftHighlightThresholdYb,
    );

    expect(
      resolveHuyaGiftDisplayDuration(normal),
      const Duration(milliseconds: 2200),
    );
    expect(
      resolveHuyaGiftDisplayDuration(highlight),
      const Duration(milliseconds: 2700),
    );
  });

  test('普通播放器弹幕关闭不参与虎牙礼物接收条件', () {
    const showDanmakuState = false;

    expect(showDanmakuState, isFalse);
    expect(
      resolveGiftMessageUiAction(
        isHuya: true,
        giftDanmakuEnabled: true,
        isLive: true,
        isBackground: false,
      ),
      GiftMessageUiAction.showHuyaEffect,
    );
  });

  test('虎牙礼物开关和生命周期决定是否丢弃礼物 UI', () {
    GiftMessageUiAction action({
      bool giftEnabled = true,
      bool isLive = true,
      bool isBackground = false,
    }) {
      return resolveGiftMessageUiAction(
        isHuya: true,
        giftDanmakuEnabled: giftEnabled,
        isLive: isLive,
        isBackground: isBackground,
      );
    }

    expect(action(), GiftMessageUiAction.showHuyaEffect);
    expect(action(giftEnabled: false), GiftMessageUiAction.discard);
    expect(action(isLive: false), GiftMessageUiAction.discard);
    expect(action(isBackground: true), GiftMessageUiAction.discard);
  });

  test('其他平台礼物继续作为聊天文字事件处理', () {
    expect(
      resolveGiftMessageUiAction(
        isHuya: false,
        giftDanmakuEnabled: false,
        isLive: false,
        isBackground: true,
      ),
      GiftMessageUiAction.appendText,
    );
  });
}

HuyaGiftDanmakuEvent _event(String id, {int? nominalTotalYb}) {
  return HuyaGiftDanmakuEvent(
    id: id,
    sender: id,
    senderIcon: '',
    giftName: '礼物',
    giftId: 1,
    count: 1,
    effectType: 0,
    colorEffectType: 0,
    comboScore: 0,
    effectResourceUrl: '',
    effectWebResourceUrl: '',
    effectPcResourceUrl: '',
    effectResourceAttr: '',
    nominalTotalYb: nominalTotalYb,
  );
}
