import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:simple_live_core/simple_live_core.dart';

const int huyaGiftHighlightThresholdYb = 1000;

const Set<String> _huyaGiftImageExtensions = <String>{
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.gif',
};

@immutable
class HuyaGiftDanmakuEvent {
  const HuyaGiftDanmakuEvent({
    required this.id,
    required this.sender,
    required this.senderIcon,
    required this.giftName,
    required this.giftId,
    required this.count,
    required this.effectType,
    required this.colorEffectType,
    required this.comboScore,
    required this.effectResourceUrl,
    required this.effectWebResourceUrl,
    required this.effectPcResourceUrl,
    required this.effectResourceAttr,
    this.giftImageUrl,
    this.giftEffectImageUrl,
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
    final resourceUrl = _asText(data['resourceUrl']);
    final webResourceUrl = _asText(data['webResourceUrl']);
    final pcResourceUrl = _asText(data['pcResourceUrl']);
    final catalogImageUrls = _asStringList(data['giftImageUrls']);
    final catalogEffectUrls = _asStringList(data['giftEffectUrls']);
    final giftImageUrl = selectHuyaGiftImageUrl(
      catalogUrls: catalogImageUrls,
      resourceUrl: resourceUrl,
      webResourceUrl: webResourceUrl,
      pcResourceUrl: pcResourceUrl,
    );
    final selectedEffectImageUrl = selectHuyaGiftEffectImageUrl(
      catalogUrls: catalogEffectUrls,
      resourceUrl: resourceUrl,
      webResourceUrl: webResourceUrl,
      pcResourceUrl: pcResourceUrl,
    );
    final giftEffectImageUrl = _sameHuyaGiftImageResource(
      giftImageUrl,
      selectedEffectImageUrl,
    )
        ? null
        : selectedEffectImageUrl;

    return HuyaGiftDanmakuEvent(
      id: messageId > 0
          ? 'message-$messageId'
          : 'gift-$giftId-$senderUid-$sequence',
      sender: _asText(data['sender'], fallback: message.userName),
      senderIcon: _asText(data['senderIcon']),
      giftName: _asText(data['giftName'], fallback: '礼物'),
      giftId: giftId,
      count: _clampCount(_asInt(data['count'])),
      effectType: _asInt(data['effectType']),
      colorEffectType: _asInt(data['colorEffectType']),
      comboScore: _asInt(data['comboScore']),
      effectResourceUrl: resourceUrl,
      effectWebResourceUrl: webResourceUrl,
      effectPcResourceUrl: pcResourceUrl,
      effectResourceAttr: _asText(data['resourceAttr']),
      giftImageUrl: giftImageUrl,
      giftEffectImageUrl: giftEffectImageUrl,
      nominalTotalYb: _asNullableInt(data['catalogNominalTotalYb']),
    );
  }

  final String id;
  final String sender;
  final String senderIcon;
  final String giftName;
  final int giftId;
  final int count;
  final int effectType;
  final int colorEffectType;
  final int comboScore;
  final String effectResourceUrl;
  final String effectWebResourceUrl;
  final String effectPcResourceUrl;
  final String effectResourceAttr;

  /// 礼物目录中的静态/动态图标，仅包含可交给图片解码器的 URL。
  final String? giftImageUrl;

  /// 礼物目录或广播中的光效图，仅接收 PNG/WebP/GIF 等安全图片资源。
  final String? giftEffectImageUrl;
  final int? nominalTotalYb;

  bool get isHighlight {
    // 协议中的 effectType/colorEffectType/comboScore 并不代表实际价值，
    // 虎粮等普通礼物也可能携带这些效果位。只有目录明确给出总价值且达到
    // 阈值时，才允许使用稍加强调的边缘卡；价格未知一律按普通礼物展示。
    final nominalValue = nominalTotalYb;
    return nominalValue != null && nominalValue >= huyaGiftHighlightThresholdYb;
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

enum GiftMessageUiAction {
  appendText,
  showHuyaEffect,
  discard,
}

GiftMessageUiAction resolveGiftMessageUiAction({
  required bool isHuya,
  required bool giftDanmakuEnabled,
  required bool isLive,
  required bool isBackground,
}) {
  if (!isHuya) return GiftMessageUiAction.appendText;
  return shouldShowHuyaGiftDanmakuEffect(
    isHuya: true,
    giftDanmakuEnabled: giftDanmakuEnabled,
    isLive: isLive,
    isBackground: isBackground,
  )
      ? GiftMessageUiAction.showHuyaEffect
      : GiftMessageUiAction.discard;
}

bool shouldShowHuyaGiftDanmakuEffect({
  required bool isHuya,
  required bool giftDanmakuEnabled,
  required bool isLive,
  required bool isBackground,
}) {
  return isHuya && giftDanmakuEnabled && isLive && !isBackground;
}

/// 只允许明确的 HTTP(S) 图片资源进入 NetImage，避免把 SVGA、ZIP、
/// Web 动画或未知二进制资源误交给图片解码器。
bool isSafeHuyaGiftImageUrl(String? value) {
  final normalized = _normalizeHuyaGiftImageUrl(value);
  if (normalized == null) return false;

  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;

  final path = uri.path.toLowerCase();
  return _huyaGiftImageExtensions.any(path.endsWith);
}

String? selectHuyaGiftImageUrl({
  Iterable<String> catalogUrls = const <String>[],
  required String resourceUrl,
  required String webResourceUrl,
  required String pcResourceUrl,
}) {
  return _selectSafeHuyaGiftImageUrl(<String>[
    ...catalogUrls,
    webResourceUrl,
    resourceUrl,
    pcResourceUrl,
  ]);
}

String? selectHuyaGiftEffectImageUrl({
  Iterable<String> catalogUrls = const <String>[],
  required String resourceUrl,
  required String webResourceUrl,
  required String pcResourceUrl,
}) {
  return _selectSafeHuyaGiftImageUrl(<String>[
    ...catalogUrls,
    webResourceUrl,
    resourceUrl,
    pcResourceUrl,
  ]);
}

String? _selectSafeHuyaGiftImageUrl(Iterable<String> candidates) {
  for (final candidate in candidates) {
    final normalized = _normalizeHuyaGiftImageUrl(candidate);
    if (isSafeHuyaGiftImageUrl(normalized)) return normalized;
  }
  return null;
}

String? _normalizeHuyaGiftImageUrl(String? value) {
  final url = value?.trim() ?? '';
  if (url.isEmpty) return null;
  return url.startsWith('//') ? 'https:$url' : url;
}

bool _sameHuyaGiftImageResource(String? first, String? second) {
  final firstUrl = _normalizeHuyaGiftImageUrl(first);
  final secondUrl = _normalizeHuyaGiftImageUrl(second);
  if (firstUrl == null || secondUrl == null) return false;

  final firstUri = Uri.tryParse(firstUrl);
  final secondUri = Uri.tryParse(secondUrl);
  if (firstUri == null || secondUri == null) return firstUrl == secondUrl;

  // CDN 同一资源常只在协议、查询参数或缓存签名上不同。播放器不应因此
  // 把同一张礼物图同时当成主图与效果图绘制两次。
  return firstUri.host.toLowerCase() == secondUri.host.toLowerCase() &&
      firstUri.path == secondUri.path;
}

List<String> _asStringList(dynamic value) {
  if (value is! Iterable) return const <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
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
