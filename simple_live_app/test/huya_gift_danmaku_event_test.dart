import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_event.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  test('从虎牙礼物消息提取播放器特效数据', () {
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
        },
      ),
      sequence: 1,
    );

    expect(event.id, 'message-42');
    expect(event.sender, '送礼用户');
    expect(event.senderIcon, '//example.com/avatar.png');
    expect(event.giftName, '星光');
    expect(event.count, 6);
    expect(event.nominalTotalYb, 1800);
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
    expect(event.count, 1);
    expect(event.id, endsWith('-8'));
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

  test('播放器礼物特效同时受平台、总弹幕、礼物开关和生命周期约束', () {
    bool visible({
      bool isHuya = true,
      bool giftEnabled = true,
      bool isLive = true,
      bool isBackground = false,
      bool showDanmaku = true,
    }) {
      return shouldShowHuyaGiftDanmakuEffect(
        isHuya: isHuya,
        giftDanmakuEnabled: giftEnabled,
        isLive: isLive,
        isBackground: isBackground,
        showDanmaku: showDanmaku,
      );
    }

    expect(visible(), isTrue);
    expect(visible(isHuya: false), isFalse);
    expect(visible(giftEnabled: false), isFalse);
    expect(visible(isLive: false), isFalse);
    expect(visible(isBackground: true), isFalse);
    expect(visible(showDanmaku: false), isFalse);
  });
}

HuyaGiftDanmakuEvent _event(String id) {
  return HuyaGiftDanmakuEvent(
    id: id,
    sender: id,
    senderIcon: '',
    giftName: '礼物',
    count: 1,
    effectType: 0,
    colorEffectType: 0,
    comboScore: 0,
  );
}
