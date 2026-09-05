import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_event.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  HuyaGiftDanmakuEvent fromData(Map<String, Object?> data) =>
      HuyaGiftDanmakuEvent.fromMessage(
          LiveMessage(
              type: LiveMessageType.gift,
              userName: '测试用户',
              message: '',
              color: LiveMessageColor.white,
              data: data),
          sequence: 1);

  test('队列优先级与视觉高亮分离，贵重礼物和守护高于仅动画', () {
    final cheap = fromData({
      'catalogNominalTotalYb': 1,
      'giftEffectUrls': ['https://cdn.example.com/cheap.svga'],
    });
    final valuable = fromData({'catalogNominalTotalYb': 100000});
    final guardian = fromData({'kind': 'guardianOpen', 'guardianLevel': 1});
    final normal = fromData({'catalogNominalTotalYb': 1});
    expect(cheap.isHighlight, isTrue);
    expect(cheap.queuePriority, HuyaGiftQueuePriority.effect);
    expect(valuable.queuePriority, HuyaGiftQueuePriority.valuable);
    expect(guardian.queuePriority, HuyaGiftQueuePriority.valuable);
    expect(normal.queuePriority, HuyaGiftQueuePriority.normal);
  });

  test('廉价动画占满 pending 时贵重礼物淘汰最早低级项', () {
    final queue = HuyaGiftDanmakuQueue();
    queue.enqueue(_event('active'));
    for (var i = 1; i <= 3; i++) {
      queue.enqueue(fromData({
        'eventId': 'cheap-$i',
        'catalogNominalTotalYb': 1,
        'giftEffectUrls': ['https://cdn.example.com/cheap-$i.svga'],
      }));
    }
    final valuable = fromData({'eventId': 'valuable', 'payTotal': 100000});
    queue.enqueue(valuable);
    expect(queue.pendingCount, 3);
    expect(queue.advance(), same(valuable));
    expect(queue.advance()?.id, 'cheap-2');
    expect(queue.advance()?.id, 'cheap-3');
    expect(queue.advance(), isNull);
  });

  test('满队只淘汰严格低级项，同级保留先到者', () {
    for (final data in <Map<String, Object?>>[
      {},
      {
        'giftEffectUrls': ['https://cdn.example.com/gift.svga']
      },
      {'payTotal': 100000},
    ]) {
      final queue = HuyaGiftDanmakuQueue(maxPending: 2);
      queue.enqueue(_event('active'));
      for (final id in ['first', 'second', 'third']) {
        queue.enqueue(fromData({...data, 'eventId': id}));
      }
      expect(queue.pendingCount, 2);
      expect(queue.advance()?.id, 'first');
      expect(queue.advance()?.id, 'second');
      expect(queue.advance(), isNull);
    }
  });

  test('每两条高优先级后给等待中的普通礼物一次且保持同级 FIFO', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 3);
    queue.enqueue(_event('active'));
    for (var round = 0; round < 5; round++) {
      queue.enqueue(_event('normal-$round'));
      queue.enqueue(_event('high-$round-a', nominalTotalYb: 1000));
      expect(queue.advance()?.id, 'high-$round-a');
      queue.enqueue(_event('high-$round-b', nominalTotalYb: 1000));
      expect(queue.advance()?.id, 'high-$round-b');
      queue.enqueue(_event('high-$round-c', nominalTotalYb: 1000));
      expect(queue.advance()?.id, 'normal-$round');
      expect(queue.advance()?.id, 'high-$round-c');
      // 清空后重新开始，公平计数不跨空闲段保留。
      expect(queue.advance(), isNull);
      queue.enqueue(_event('active-$round'));
    }
    queue.clear();
  });

  test('normal 缺席时 valuable 与 effect 两高一低轮转，公平 slot 重置配额', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 3);
    HuyaGiftDanmakuEvent effect(int id) => fromData({
          'eventId': 'effect-$id',
          'catalogNominalTotalYb': 1,
          'giftEffectUrls': ['https://cdn.example.com/effect-$id.svga'],
        });
    queue.enqueue(_event('valuable-0', nominalTotalYb: 1000));
    queue.enqueue(effect(0));
    queue.enqueue(effect(1));
    queue.enqueue(_event('valuable-1', nominalTotalYb: 1000));
    expect(queue.advance()?.id, 'valuable-1');
    queue.enqueue(_event('valuable-2', nominalTotalYb: 1000));
    expect(queue.advance()?.id, 'effect-0');
    // 公平 slot 之后仍有 effect 等待，但必须恢复 valuable 优先。
    expect(queue.advance()?.id, 'valuable-2');
    queue.enqueue(_event('valuable-3', nominalTotalYb: 1000));
    expect(queue.advance()?.id, 'valuable-3');
    queue.enqueue(_event('valuable-4', nominalTotalYb: 1000));
    expect(queue.advance()?.id, 'effect-1');
    expect(queue.advance()?.id, 'valuable-4');
    expect(queue.advance(), isNull);
  });

  test('clear 重置公平计数，首个高价值 active 也计入连续配额', () {
    final queue = HuyaGiftDanmakuQueue();
    queue.enqueue(_event('high-active', nominalTotalYb: 1000));
    queue.enqueue(_event('normal'));
    queue.enqueue(_event('high-1', nominalTotalYb: 1000));
    queue.enqueue(_event('high-2', nominalTotalYb: 1000));
    expect(queue.advance()?.id, 'high-1');
    expect(queue.advance()?.id, 'normal');
    queue.clear();
    queue.enqueue(_event('active'));
    queue.enqueue(_event('next-normal'));
    queue.enqueue(_event('next-high', nominalTotalYb: 1000));
    expect(queue.advance()?.id, 'next-high');
  });

  test('event ID 优先替换目标其次稳定 ID，空值兼容旧规则', () {
    final update = fromData({
      'replacesEventId': ' effect-1 ',
      'eventId': 'payment-1',
      'messageId': 9,
      'giftId': 2,
    });
    expect(update.id, 'effect-1');
    expect(update.isUpdate, isTrue);
    final initial = fromData({'eventId': 'stable-1', 'messageId': 9});
    expect(initial.id, 'stable-1');
    expect(initial.isUpdate, isFalse);
    final legacy = fromData({
      'replacesEventId': ' ',
      'eventId': '',
      'messageId': 9,
    });
    expect(legacy.id, 'message-9');
    expect(legacy.isUpdate, isFalse);
    expect(_event('legacy').isUpdate, isFalse);
  });

  test('同 ID update 只替换 active 不累加且不抢占 pending', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 1);
    queue.enqueue(fromData({'eventId': 'effect', 'count': 2}));
    final pending = _event('pending');
    queue.enqueue(pending);
    final updated = fromData({
      'replacesEventId': 'effect',
      'eventId': 'payment',
      'count': 7,
      'giftName': '真实礼物',
      'payTotal': 100000,
    });
    expect(queue.enqueue(updated), isFalse);
    expect(queue.active?.id, updated.id);
    expect(queue.active?.count, 7);
    expect(queue.pendingCount, 1);
    expect(queue.advance(), same(pending));
    expect(queue.advance(), isNull);
  });

  test('pending update 原位替换，容量和同级顺序不变', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 3);
    queue.enqueue(_event('active'));
    queue.enqueue(fromData({'eventId': 'before', 'payTotal': 10000}));
    queue.enqueue(
        fromData({'eventId': 'target', 'payTotal': 10000, 'count': 2}));
    queue.enqueue(fromData({'eventId': 'after', 'payTotal': 10000}));
    final updated = fromData({
      'replacesEventId': 'target',
      'count': 7,
      'payTotal': 20000,
    });
    expect(queue.enqueue(updated), isFalse);
    expect(queue.active?.id, 'active');
    expect(queue.pendingCount, 3);
    expect(queue.advance()?.id, 'before');
    expect(queue.advance()?.count, updated.count);
    expect(queue.advance()?.id, 'after');
    expect(queue.advance(), isNull);
  });

  test('pending update 可更新优先级但不是重新入队', () {
    final queue = HuyaGiftDanmakuQueue();
    queue.enqueue(_event('active'));
    queue.enqueue(_event('normal'));
    queue.enqueue(fromData({'eventId': 'effect', 'countKnown': false}));
    final update = fromData({
      'replacesEventId': 'effect',
      'count': 3,
      'payTotal': 100000,
    });
    queue.enqueue(update);
    expect(queue.pendingCount, 2);
    expect(queue.advance()?.id, update.id);
    expect(queue.advance()?.id, 'normal');
  });

  for (final isActive in [true, false]) {
    test('交易更新 ${isActive ? 'active' : 'pending'} 保留缺失视觉资源与更强价值证据', () {
      final queue = HuyaGiftDanmakuQueue();
      final effect = fromData({
        'eventId': 'effect',
        'kind': 'giftEffectNotice',
        'countKnown': false,
        'giftName': '初始特效',
        'sender': '特效昵称',
        'count': 2,
        'giftImageUrls': [
          'https://cdn.example.com/icon-a.png',
          'https://cdn.example.com/icon-b.webp'
        ],
        'giftEffectUrls': [
          'https://cdn.example.com/effect.gif',
          'https://cdn.example.com/effect.svga'
        ],
        'resourceUrl': 'https://cdn.example.com/resource.png',
        'catalogNominalTotalYb': 100000,
        'effectInfo': {'showType': 2, 'streamDuration': 3200},
      });
      if (!isActive) queue.enqueue(_event('active'));
      queue.enqueue(effect);
      queue.enqueue(fromData({
        'replacesEventId': 'effect',
        'sender': '真实交易昵称',
        'giftName': '真实交易礼物',
        'count': 7,
        'payTotal': 1,
      }));
      final merged = isActive ? queue.active! : queue.advance()!;
      expect(merged.id, 'effect');
      expect(merged.sender, '真实交易昵称');
      expect(merged.giftName, '真实交易礼物');
      expect(merged.count, 7);
      expect(merged.quantityLabel, '×7');
      expect(merged.presentationImageUrls, effect.presentationImageUrls);
      expect(merged.giftAnimationUrls, effect.giftAnimationUrls);
      expect(merged.effectResourceUrl, effect.effectResourceUrl);
      expect(merged.isBigEffect, isTrue);
      expect(merged.isHighlight, isTrue);
      expect(merged.nominalTotalYb, 100000);
      expect(merged.queuePriority, HuyaGiftQueuePriority.valuable);
    });
  }

  test('未知、退场、淘汰和 clear 后的 update 一律丢弃不重播', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 1);
    final update = fromData({'replacesEventId': 'target', 'count': 7});
    expect(queue.enqueue(update), isFalse);
    expect(queue.active, isNull);
    queue.enqueue(fromData({'eventId': 'target'}));
    queue.advance();
    expect(queue.enqueue(update), isFalse);
    expect(queue.active, isNull);
    queue.enqueue(_event('active'));
    queue.enqueue(fromData({'eventId': 'target'}));
    queue.enqueue(_event('valuable', nominalTotalYb: 10000));
    queue.enqueue(update);
    expect(queue.pendingCount, 1);
    expect(queue.advance()?.id, 'valuable');
    queue.clear();
    expect(queue.enqueue(update), isFalse);
    expect(queue.active, isNull);
  });

  test('相同支付号不同 group 的稳定 eventId 不误作 update 或相互去重', () {
    final queue = HuyaGiftDanmakuQueue();
    for (final group in ['a', 'b']) {
      final event = fromData({
        'eventId': 'payment-9-group-$group',
        'messageId': 9,
        'count': 2,
      });
      expect(event.isUpdate, isFalse);
      queue.enqueue(event);
    }
    expect(queue.active?.id, 'payment-9-group-a');
    expect(queue.advance()?.id, 'payment-9-group-b');
    expect(queue.advance(), isNull);
  });

  test('守护通知展示等级与原始天数，不产生送出、件数或虚构价格', () {
    final event = fromData({
      'kind': 'guardianOpen',
      'giftName': '守护',
      'guardianLevel': 5,
      'guardianOpenDays': 93,
      'guardianLastLevel': 0,
      'countKnown': false,
      'senderIcon': 'https://cdn.example.com/avatar.png',
    });
    expect(event.description, '开通 守护');
    expect(event.quantityLabel, 'V5');
    expect(event.interactionText, '93天');
    expect(event.nominalTotalYb, isNull);
    expect(event.isHighlight, isTrue);
    expect(event.presentationImageUrls, isEmpty);
    expect(event.semanticsLabel, isNot(contains('个')));
    expect(event.semanticsLabel, isNot(contains('送出')));
    final update = fromData({
      'kind': 'guardianOpen',
      'giftName': '守护',
      'guardianLevel': 5,
      'guardianLastLevel': 4
    });
    expect(update.description, '更新 守护');
  });

  test('活动通知未知数量不展示 ×1，帧数不当件数', () {
    final event = fromData({
      'kind': 'giftActivityEffect',
      'giftName': '活动礼物特效',
      'effectFrames': 120,
      'effectId': 8888,
      'countKnown': false
    });
    expect(event.quantityLabel, isNull);
    expect(event.description, '触发 活动礼物特效');
    expect(event.giftId, 0);
  });

  test('同一次绘图的不同道具不会在应用队列按 messageId 互相覆盖', () {
    final queue = HuyaGiftDanmakuQueue();
    final first =
        fromData({'kind': 'giftDrawing', 'messageId': 10, 'giftId': 4});
    final second =
        fromData({'kind': 'giftDrawing', 'messageId': 10, 'giftId': 9});
    expect(first.id, isNot(second.id));
    queue.enqueue(first);
    queue.enqueue(second);
    expect(queue.pendingCount, 1);
    expect(queue.advance()?.giftId, 9);
  });

  test('type16 资源价格让特殊礼物在目录缺失时仍具备优先级', () {
    final event = fromData({
      'resourceNominalTotalYb': 188000,
      'giftImageUrls': ['https://cdn.example.com/shield.webp']
    });
    expect(event.nominalTotalYb, 188000);
    expect(event.isHighlight, isTrue);
    expect(
        event.presentationImageUrls, ['https://cdn.example.com/shield.webp']);
  });

  test('effectParams 用户头像和用户自填文案 URL 不变成礼物资源', () {
    final event = fromData({
      'effectParams': {
        'senderAvatar': 'https://cdn.example.com/avatar.png',
        'content': 'https://cdn.example.com/user-text.gif',
        'iconUrl': 'https://cdn.example.com/real-gift.png',
        'animationUrl': 'https://cdn.example.com/gift.svga',
      }
    });
    expect(
        event.presentationImageUrls, ['https://cdn.example.com/real-gift.png']);
    expect(event.giftAnimationUrls, ['https://cdn.example.com/gift.svga']);
  });

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

  test('动画资源仅接受已知扩展名并保留查询参数和候选顺序', () {
    expect(
      collectHuyaGiftAnimationUrls(const [
        '//cdn.example.com/gift/effect.SVGA?v=1#first',
        'https://cdn.example.com/gift/effect.SVGA?v=1#duplicate',
        'https://cdn.example.com/gift/effect.SVGA?v=2',
        'https://cdn.example.com/gift/effect.png.zip',
        'https://cdn.example.com/gift/effect.mp4',
        'https://cdn.example.com/gift/effect.webm',
        'https://cdn.example.com/gift/effect.json',
        'https://cdn.example.com/gift/effect.vap',
        'https://cdn.example.com/gift/effect.lottie',
        'https://cdn.example.com/gift/effect.bin',
      ]),
      [
        'https://cdn.example.com/gift/effect.SVGA?v=1#first',
        'https://cdn.example.com/gift/effect.SVGA?v=2',
        'https://cdn.example.com/gift/effect.png.zip',
        'https://cdn.example.com/gift/effect.mp4',
        'https://cdn.example.com/gift/effect.webm',
        'https://cdn.example.com/gift/effect.json',
        'https://cdn.example.com/gift/effect.vap',
        'https://cdn.example.com/gift/effect.lottie',
        'https://cdn.example.com/gift/effect.bin',
      ],
    );
  });

  test('图片、未知格式和无效地址不能被当成复杂动画', () {
    expect(
      collectHuyaGiftAnimationUrls(const [
        'https://cdn.example.com/gift/icon.PNG?format=svga',
        'https://cdn.example.com/gift/effect.gif',
        'https://cdn.example.com/gift/image?id=1',
        'https://cdn.example.com/gift/effect.html?file=effect.svga',
        'https://cdn.example.com/gift/effect.txt#effect.svga',
        'https://cdn.example.com/gift/effect.unknown',
        'https://cdn.example.com/',
        'https:///effect.svga',
        'ftp://cdn.example.com/gift/effect.svga',
        '/relative/effect.svga',
        'data:application/json,{}',
        '',
      ]),
      isEmpty,
    );
  });

  test('未知资源不升级高亮且不会从发送者或业务字段提取头像', () {
    final event = HuyaGiftDanmakuEvent.fromMessage(
      LiveMessage(
        type: LiveMessageType.gift,
        userName: '用户',
        message: 'gift',
        color: LiveMessageColor.white,
        data: const {
          'senderIcon': '//cdn.example.com/avatar.png',
          'giftName': '虎粮',
          'catalogNominalTotalYb': 10,
          'giftImageUrls': ['//cdn.example.com/gift/icon.webp'],
          'resourceUrl': 'https://cdn.example.com/gift/page.html',
          'webResourceUrl': 'https://cdn.example.com/gift/readme.txt',
          'pcResourceUrl': 'https://cdn.example.com/gift/effect.unknown',
          'bizData': {'avatar': 'https://cdn.example.com/avatar.webp'},
          'expand': {'userIcon': 'https://cdn.example.com/avatar.gif'},
        },
      ),
      sequence: 13,
    );

    expect(event.senderIcon, '//cdn.example.com/avatar.png');
    expect(event.presentationImageUrls, [
      'https://cdn.example.com/gift/icon.webp',
    ]);
    expect(event.giftEffectImageUrls, isEmpty);
    expect(event.giftAnimationUrls, isEmpty);
    expect(event.isHighlight, isFalse);
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

  test('普通礼物队列有上限，同级满队保留已等待事件', () {
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

    expect(queue.advance()?.id, second.id);
    expect(queue.advance()?.id, third.id);
    expect(queue.advance(), isNull);
  });

  test('高价值优先但同级 FIFO，且不打断当前展示', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 5);
    final active = _event('active');
    final normal1 = _event('normal-1');
    final normal2 = _event('normal-2');
    final high1 = _event('high-1', nominalTotalYb: 1000);
    final high2 = _event('high-2', nominalTotalYb: 10000);
    final high3 = _event('high-3', nominalTotalYb: 2000);

    expect(queue.enqueue(active), isTrue);
    for (final event in [normal1, high1, normal2, high2, high3]) {
      expect(queue.enqueue(event), isFalse);
      expect(queue.active, same(active));
    }
    expect(queue.pendingCount, 5);

    for (final event in [high1, high2, normal1, high3, normal2]) {
      expect(queue.advance(), same(event));
    }
    expect(queue.advance(), isNull);
    expect(queue.active, isNull);
    expect(queue.pendingCount, 0);
  });

  for (final capacity in [1, 3]) {
    test('全高价值队列满时拒绝新事件而不淘汰旧事件，容量 $capacity', () {
      final queue = HuyaGiftDanmakuQueue(maxPending: capacity);
      final active = _event('active');
      final waiting = List.generate(
        capacity,
        (i) => _event('waiting-$i', nominalTotalYb: 1000),
      );

      expect(queue.enqueue(active), isTrue);
      for (final event in waiting) {
        expect(queue.enqueue(event), isFalse);
      }
      for (var i = 0; i < 100; i++) {
        expect(
          queue.enqueue(_event('incoming-high-$i', nominalTotalYb: 10000)),
          isFalse,
        );
        expect(queue.enqueue(_event('incoming-normal-$i')), isFalse);
        expect(queue.pendingCount, capacity);
        expect(queue.active, same(active));
      }

      for (final event in waiting) {
        expect(queue.advance(), same(event));
      }
      expect(queue.advance(), isNull);
      expect(queue.pendingCount, 0);
    });
  }

  test('因容量被拒绝的 ID 在释放位置后仍可入队', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 1);
    final waiting = _event('waiting', nominalTotalYb: 1000);
    final incoming = _event('incoming', nominalTotalYb: 1000);
    queue.enqueue(_event('active'));
    queue.enqueue(waiting);

    expect(queue.enqueue(incoming), isFalse);
    expect(queue.pendingCount, 1);
    expect(queue.advance(), same(waiting));
    expect(queue.enqueue(incoming), isFalse);
    expect(queue.pendingCount, 1);
    expect(queue.advance(), same(incoming));
    expect(queue.advance(), isNull);
  });

  test('队列满时高价值仅淘汰最早普通礼物且不改变同级顺序', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 3);
    final high1 = _event('high-1', nominalTotalYb: 1000);
    final high2 = _event('high-2', nominalTotalYb: 1000);
    final normal2 = _event('normal-2');

    queue.enqueue(_event('active'));
    queue.enqueue(_event('normal-1'));
    queue.enqueue(high1);
    queue.enqueue(normal2);
    expect(queue.enqueue(high2), isFalse);
    expect(queue.pendingCount, 3);

    expect(queue.advance(), same(high1));
    expect(queue.advance(), same(high2));
    expect(queue.advance(), same(normal2));
    expect(queue.advance(), isNull);
  });

  test('高价值礼物持续到达时不会插到已接收的同级礼物之前', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 2);
    queue.enqueue(_event('active'));
    queue.enqueue(_event('high-0', nominalTotalYb: 1000));

    for (var i = 1; i <= 20; i++) {
      queue.enqueue(_event('high-$i', nominalTotalYb: 1000));
      expect(queue.pendingCount, 2);
      expect(queue.advance()?.id, 'high-${i - 1}');
      expect(queue.pendingCount, 1);
    }
    expect(queue.advance()?.id, 'high-20');
    expect(queue.advance(), isNull);
  });

  test('重复 active ID 不占位、不淘汰 pending，也不累加数量', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 1);
    final active = _event('active', count: 2);
    final pending = _event('pending');
    queue.enqueue(active);
    queue.enqueue(pending);

    expect(
      queue.enqueue(_event('active', count: 99, nominalTotalYb: 1000)),
      isFalse,
    );
    expect(queue.active, same(active));
    expect(queue.active?.count, 2);
    expect(queue.pendingCount, 1);
    expect(queue.advance(), same(pending));
    expect(queue.advance(), isNull);
  });

  test('队列未满时重复 pending ID 也不会额外占位', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 3);
    final pending = _event('pending', count: 2);
    queue.enqueue(_event('active'));
    queue.enqueue(pending);

    for (var i = 0; i < 5; i++) {
      expect(
        queue.enqueue(_event('pending', count: 99, nominalTotalYb: 1000)),
        isFalse,
      );
      expect(queue.pendingCount, 1);
    }
    expect(queue.advance(), same(pending));
    expect(queue.active?.count, 2);
    expect(queue.advance(), isNull);
  });

  for (final isHighlight in [false, true]) {
    test('重复 pending ID 不占位、不重排或升级事件，高价值 $isHighlight', () {
      final queue = HuyaGiftDanmakuQueue(maxPending: 2);
      final first = _event(
        'first',
        count: 3,
        nominalTotalYb: isHighlight ? 1000 : 10,
      );
      final second = _event(
        'second',
        nominalTotalYb: isHighlight ? 1000 : 10,
      );
      queue.enqueue(_event('active'));
      queue.enqueue(first);
      queue.enqueue(second);

      expect(
        queue.enqueue(_event('second', count: 99, nominalTotalYb: 10000)),
        isFalse,
      );
      expect(
        queue.enqueue(_event('first', count: 99, nominalTotalYb: 10)),
        isFalse,
      );
      expect(queue.pendingCount, 2);
      expect(queue.advance(), same(first));
      expect(queue.active?.count, 3);
      expect(queue.advance(), same(second));
      expect(queue.active?.count, 1);
      expect(queue.advance(), isNull);
    });
  }

  test('不同 ID 的同名用户同名礼物仍是独立事件且不合并数量', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 2);
    final events = [
      _event('first', sender: '同名用户', count: 2),
      _event('second', sender: '同名用户', count: 3),
      _event('third', sender: '同名用户', count: 4),
    ];

    expect(queue.enqueue(events[0]), isTrue);
    expect(queue.enqueue(events[1]), isFalse);
    expect(queue.enqueue(events[2]), isFalse);
    expect(queue.pendingCount, 2);
    expect(queue.active, same(events[0]));
    expect(queue.active?.count, 2);
    expect(queue.advance(), same(events[1]));
    expect(queue.active?.count, 3);
    expect(queue.advance(), same(events[2]));
    expect(queue.active?.count, 4);
    expect(queue.advance(), isNull);
  });

  test('pending 晋升 active 后其重复 ID 仍不占位', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 1);
    final pending = _event('pending');
    queue.enqueue(_event('active'));
    queue.enqueue(pending);
    expect(queue.advance(), same(pending));

    expect(queue.enqueue(_event('pending')), isFalse);
    expect(queue.active, same(pending));
    expect(queue.pendingCount, 0);
    expect(queue.advance(), isNull);
  });

  test('clear 清空 active 和 pending，原 ID 可重新入队', () {
    final queue = HuyaGiftDanmakuQueue(maxPending: 1);
    final active = _event('active');
    final pending = _event('pending', nominalTotalYb: 1000);
    queue.enqueue(active);
    queue.enqueue(pending);

    queue.clear();
    expect(queue.active, isNull);
    expect(queue.pendingCount, 0);
    expect(queue.advance(), isNull);
    expect(queue.enqueue(active), isTrue);
    expect(queue.enqueue(pending), isFalse);
    expect(queue.active, same(active));
    expect(queue.pendingCount, 1);
    expect(queue.advance(), same(pending));
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
    expect(queue.advance()?.id, 'normal-1');
    expect(queue.advance()?.id, 'normal-2');
    expect(queue.advance(), isNull);
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

HuyaGiftDanmakuEvent _event(
  String id, {
  int? nominalTotalYb,
  String? sender,
  int count = 1,
}) {
  return HuyaGiftDanmakuEvent(
    id: id,
    sender: sender ?? id,
    senderIcon: '',
    giftName: '礼物',
    giftId: 1,
    count: count,
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
