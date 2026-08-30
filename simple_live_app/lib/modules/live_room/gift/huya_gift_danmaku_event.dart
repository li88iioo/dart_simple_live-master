import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:simple_live_core/simple_live_core.dart';

@immutable
class HuyaGiftDanmakuEvent {
  const HuyaGiftDanmakuEvent({
    required this.id,
    required this.sender,
    required this.senderIcon,
    required this.giftName,
    required this.count,
    required this.effectType,
    required this.colorEffectType,
    required this.comboScore,
    this.nominalTotalYb,
  });

  factory HuyaGiftDanmakuEvent.fromMessage(
    LiveMessage message, {
    required int sequence,
  }) {
    final data = message.data is Map
        ? Map<String, dynamic>.from(message.data as Map)
        : const <String, dynamic>{};
    final messageId = _asInt(data['messageId']);
    final giftId = _asInt(data['giftId']);
    final senderUid = _asInt(data['senderUid']);

    return HuyaGiftDanmakuEvent(
      id: messageId > 0
          ? 'message-$messageId'
          : 'gift-$giftId-$senderUid-$sequence',
      sender: _asText(data['sender'], fallback: message.userName),
      senderIcon: _asText(data['senderIcon']),
      giftName: _asText(data['giftName'], fallback: '礼物'),
      count: _clampCount(_asInt(data['count'])),
      effectType: _asInt(data['effectType']),
      colorEffectType: _asInt(data['colorEffectType']),
      comboScore: _asInt(data['comboScore']),
      nominalTotalYb: _asNullableInt(data['catalogNominalTotalYb']),
    );
  }

  final String id;
  final String sender;
  final String senderIcon;
  final String giftName;
  final int count;
  final int effectType;
  final int colorEffectType;
  final int comboScore;
  final int? nominalTotalYb;

  bool get isHighlight {
    return effectType > 0 ||
        colorEffectType > 0 ||
        comboScore >= 100 ||
        (nominalTotalYb ?? 0) >= 1000;
  }

  String get semanticsLabel => '$sender 送出 $giftName，共 $count 个';
}

class HuyaGiftDanmakuQueue {
  HuyaGiftDanmakuQueue({this.maxPending = 3}) : assert(maxPending > 0);

  final int maxPending;
  final ListQueue<HuyaGiftDanmakuEvent> _pending = ListQueue();

  HuyaGiftDanmakuEvent? active;

  int get pendingCount => _pending.length;

  bool enqueue(HuyaGiftDanmakuEvent event) {
    if (active == null) {
      active = event;
      return true;
    }

    if (_pending.length >= maxPending) {
      _pending.removeFirst();
    }
    _pending.addLast(event);
    return false;
  }

  HuyaGiftDanmakuEvent? advance() {
    active = _pending.isEmpty ? null : _pending.removeFirst();
    return active;
  }

  void clear() {
    active = null;
    _pending.clear();
  }
}

bool shouldShowHuyaGiftDanmakuEffect({
  required bool isHuya,
  required bool giftDanmakuEnabled,
  required bool isLive,
  required bool isBackground,
  required bool showDanmaku,
}) {
  return isHuya && giftDanmakuEnabled && isLive && !isBackground && showDanmaku;
}

String _asText(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _clampCount(int value) {
  if (value < 1) return 1;
  if (value > 999999) return 999999;
  return value;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  final parsed = _asInt(value);
  return parsed > 0 ? parsed : null;
}
