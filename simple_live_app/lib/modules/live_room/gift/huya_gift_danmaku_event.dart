import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:simple_live_core/simple_live_core.dart';

const int huyaGiftHighlightThresholdYb = 1000;

const Set<String> _huyaGiftImageExtensions = <String>{
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.gif',
  '.avif',
};

const Set<String> _huyaGiftNonImageExtensions = <String>{
  '.svga',
  '.zip',
  '.mp4',
  '.webm',
  '.json',
  '.vap',
  '.lottie',
  '.bin',
};

const Set<String> _huyaInteractionTextKeys = <String>{
  'text',
  'content',
  'message',
  'msg',
  'usertext',
  'customtext',
  'sendcontent',
  'blessing',
  'wish',
  'slogan',
  'title',
  'subtitle',
  'desc',
  'description',
  'word',
  'copy',
  'copywriting',
  'interactiontext',
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
    this.interactionText = '',
    this.giftImageUrl,
    this.giftEffectImageUrl,
    this.giftImageUrls = const <String>[],
    this.giftEffectImageUrls = const <String>[],
    this.giftAnimationUrls = const <String>[],
    this.nominalTotalYb,
    this.isBigEffect = false,
    this.effectShowType = 0,
    this.effectStreamDuration = 0,
  });

  factory HuyaGiftDanmakuEvent.fromMessage(
    LiveMessage message, {
    required int sequence,
  }) {
    final data = message.data is Map
        ? Map<String, dynamic>.from(message.data as Map)
        : const <String, dynamic>{};
    final kind = _asText(data['kind']);
    final messageId = _asInt(data['messageId']);
    final giftId = _asInt(data['giftId']);
    final senderUid = _asInt(data['senderUid']);
    final resourceUrl = _asText(data['resourceUrl']);
    final webResourceUrl = _asText(data['webResourceUrl']);
    final pcResourceUrl = _asText(data['pcResourceUrl']);
    final catalogImageUrls = _asStringList(data['giftImageUrls']);
    final catalogEffectUrls = _asStringList(data['giftEffectUrls']);
    final effectParamUrls = _collectHttpUrls(data['effectParams']);

    final giftImageUrls = collectHuyaGiftImageUrls(<String>[
      ...catalogImageUrls,
      resourceUrl,
      webResourceUrl,
      pcResourceUrl,
    ]);
    final giftEffectImageUrls = collectHuyaGiftImageUrls(<String>[
      ...catalogEffectUrls,
      ...effectParamUrls,
      webResourceUrl,
      resourceUrl,
      pcResourceUrl,
    ]).where((url) => !giftImageUrls.contains(url)).toList(growable: false);
    final giftAnimationUrls = collectHuyaGiftAnimationUrls(<String>[
      ...catalogEffectUrls,
      ...effectParamUrls,
      webResourceUrl,
      resourceUrl,
      pcResourceUrl,
    ]);

    final giftName = _asText(data['giftName'], fallback: '礼物');
    final interactionText = extractHuyaGiftInteractionText(
      <dynamic>[
        data['customText'],
        data['sendContent'],
        data['content'],
        data['expand'],
        data['effectParams'],
        data['bizData'],
      ],
      giftName: giftName,
    );
    final effectInfo = data['effectInfo'] is Map
        ? Map<dynamic, dynamic>.from(data['effectInfo'] as Map)
        : const <dynamic, dynamic>{};
    final catalogNominalTotalYb = _asNullableInt(data['catalogNominalTotalYb']);
    final serverPayTotalYb = _asNullableInt(data['payTotal']);
    final isEffectNotice = kind == 'giftEffectNotice';
    final effectId = _asInt(data['effectId']);

    return HuyaGiftDanmakuEvent(
      id: messageId > 0
          ? kind.isEmpty
              ? 'message-$messageId'
              : '$kind-message-$messageId'
          : isEffectNotice && effectId > 0
              ? 'effect-$effectId-$senderUid-$sequence'
              : 'gift-$giftId-$senderUid-$sequence',
      sender: _asText(data['sender'], fallback: message.userName),
      senderIcon: _asText(data['senderIcon']),
      giftName: giftName,
      giftId: giftId,
      count: _clampCount(_asInt(data['count'])),
      effectType: _asInt(data['effectType']),
      colorEffectType: _asInt(data['colorEffectType']),
      comboScore: _asInt(data['comboScore']),
      effectResourceUrl: resourceUrl,
      effectWebResourceUrl: webResourceUrl,
      effectPcResourceUrl: pcResourceUrl,
      effectResourceAttr: _asText(data['resourceAttr']),
      interactionText: interactionText,
      giftImageUrl: giftImageUrls.firstOrNull,
      giftEffectImageUrl: giftEffectImageUrls.firstOrNull,
      giftImageUrls: giftImageUrls,
      giftEffectImageUrls: giftEffectImageUrls,
      giftAnimationUrls: giftAnimationUrls,
      nominalTotalYb: _maxNullableInt(catalogNominalTotalYb, serverPayTotalYb),
      isBigEffect: isEffectNotice || _asBool(data['isBigEffect']),
      effectShowType: _asInt(effectInfo['showType']),
      effectStreamDuration: _asInt(effectInfo['streamDuration']),
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

  /// 服务端随互动礼物下发的真实文案，例如告白灯牌内容。
  final String interactionText;

  /// 兼容旧调用方的首个静态图标。
  final String? giftImageUrl;

  /// 兼容旧调用方的首个可解码效果图。
  final String? giftEffectImageUrl;

  /// 按优先级排列的静态图标候选。首个失败时 UI 会自动尝试下一项。
  final List<String> giftImageUrls;

  /// 按优先级排列的 PNG/WebP/GIF 等效果图候选。
  final List<String> giftEffectImageUrls;

  /// SVGA/ZIP/MP4/JSON/VAP 等复杂动画资源。当前至少用于识别高价值
  /// 礼物并保证降级卡片可见，后续原生动画渲染可直接复用。
  final List<String> giftAnimationUrls;

  final int? nominalTotalYb;
  final bool isBigEffect;
  final int effectShowType;
  final int effectStreamDuration;

  List<String> get presentationImageUrls => _uniqueUrls(<String>[
        ...giftImageUrls,
        if (giftImageUrl != null) giftImageUrl!,
        ...giftEffectImageUrls,
        if (giftEffectImageUrl != null) giftEffectImageUrl!,
      ]);

  bool get isHighlight {
    final nominalValue = nominalTotalYb;
    return isBigEffect ||
        (effectShowType & 2) != 0 ||
        giftAnimationUrls.isNotEmpty ||
        (nominalValue != null && nominalValue >= huyaGiftHighlightThresholdYb);
  }

  String get semanticsLabel {
    final base = '$sender 送出 $giftName，共 $count 个';
    return interactionText.isEmpty ? base : '$base，$interactionText';
  }
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

    if (event.isHighlight) {
      if (_pending.length >= maxPending && !_removeOldestNormal()) {
        _pending.removeLast();
      }
      // 高价值礼物优先成为下一条，但不打断当前正在展示的礼物。
      _pending.addFirst(event);
      return false;
    }

    if (_pending.length >= maxPending && !_removeOldestNormal()) {
      // 队列已全部是高价值礼物时，普通礼物不再覆盖它们。
      return false;
    }
    _pending.addLast(event);
    return false;
  }

  bool _removeOldestNormal() {
    HuyaGiftDanmakuEvent? candidate;
    for (final event in _pending) {
      if (!event.isHighlight) {
        candidate = event;
        break;
      }
    }
    if (candidate == null) return false;
    _pending.remove(candidate);
    return true;
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

/// 普通礼物短暂提示；复杂或高价值礼物多停留少量时间，但不长期遮挡画面。
Duration resolveHuyaGiftDisplayDuration(HuyaGiftDanmakuEvent event) {
  if (event.isBigEffect || event.giftAnimationUrls.isNotEmpty) {
    final serverDuration = event.effectStreamDuration;
    if (serverDuration > 0) {
      return Duration(milliseconds: serverDuration.clamp(2600, 4200));
    }
    return const Duration(milliseconds: 3200);
  }
  return event.isHighlight
      ? const Duration(milliseconds: 2700)
      : const Duration(milliseconds: 2200);
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

/// 允许明确图片格式以及无扩展名的 HTTP(S) CDN 地址；已知动画/压缩格式
/// 不会交给 Flutter 图片解码器，而是保留在 animationUrls 中做安全降级。
bool isSafeHuyaGiftImageUrl(String? value) {
  final normalized = _normalizeHuyaGiftUrl(value);
  if (normalized == null) return false;

  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;

  final path = uri.path.toLowerCase();
  if (_huyaGiftNonImageExtensions.any(path.endsWith)) return false;
  if (_huyaGiftImageExtensions.any(path.endsWith)) return true;

  final lastSegment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  // 虎牙部分 CDN 通过 query/响应 MIME 决定格式，路径没有扩展名。
  return lastSegment.isNotEmpty && !lastSegment.contains('.');
}

String? selectHuyaGiftImageUrl({
  Iterable<String> catalogUrls = const <String>[],
  required String resourceUrl,
  required String webResourceUrl,
  required String pcResourceUrl,
}) {
  return collectHuyaGiftImageUrls(<String>[
    ...catalogUrls,
    webResourceUrl,
    resourceUrl,
    pcResourceUrl,
  ]).firstOrNull;
}

String? selectHuyaGiftEffectImageUrl({
  Iterable<String> catalogUrls = const <String>[],
  required String resourceUrl,
  required String webResourceUrl,
  required String pcResourceUrl,
}) {
  return collectHuyaGiftImageUrls(<String>[
    ...catalogUrls,
    webResourceUrl,
    resourceUrl,
    pcResourceUrl,
  ]).firstOrNull;
}

List<String> collectHuyaGiftImageUrls(Iterable<String> candidates) {
  return _uniqueUrls(
    candidates.where((candidate) => isSafeHuyaGiftImageUrl(candidate)),
  );
}

List<String> collectHuyaGiftAnimationUrls(Iterable<String> candidates) {
  return _uniqueUrls(
    candidates.where((candidate) {
      final normalized = _normalizeHuyaGiftUrl(candidate);
      if (normalized == null || isSafeHuyaGiftImageUrl(normalized)) {
        return false;
      }
      final uri = Uri.tryParse(normalized);
      return uri != null &&
          uri.hasAuthority &&
          (uri.scheme == 'http' || uri.scheme == 'https');
    }),
  );
}

@visibleForTesting
String extractHuyaGiftInteractionText(
  Iterable<dynamic> candidates, {
  String giftName = '',
}) {
  for (final candidate in candidates) {
    final extracted = _extractInteractionValue(candidate, depth: 0);
    final cleaned = _cleanInteractionText(extracted, giftName: giftName);
    if (cleaned.isNotEmpty) return cleaned;
  }
  return '';
}

String _extractInteractionValue(dynamic value, {required int depth}) {
  if (value == null || depth > 4) return '';

  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return '';
    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'))) {
      try {
        return _extractInteractionValue(jsonDecode(text), depth: depth + 1);
      } catch (_) {
        return '';
      }
    }
    return text;
  }

  if (value is Map) {
    final normalized = <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString().toLowerCase(): entry.value,
    };
    for (final key in _huyaInteractionTextKeys) {
      if (!normalized.containsKey(key)) continue;
      final result = _extractInteractionValue(
        normalized[key],
        depth: depth + 1,
      );
      if (result.isNotEmpty) return result;
    }
    for (final nested in normalized.values) {
      if (nested is! Map && nested is! Iterable) continue;
      final result = _extractInteractionValue(nested, depth: depth + 1);
      if (result.isNotEmpty) return result;
    }
    return '';
  }

  if (value is Iterable) {
    for (final item in value) {
      final result = _extractInteractionValue(item, depth: depth + 1);
      if (result.isNotEmpty) return result;
    }
  }
  return '';
}

String _cleanInteractionText(String value, {required String giftName}) {
  var text = value
      .replaceAll(RegExp(r'[\u0000-\u001F]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty || _normalizeHuyaGiftUrl(text) != null) return '';
  if (text.length > 160) text = '${text.substring(0, 157)}…';

  final normalized = text.replaceAll(RegExp(r'\s+'), '');
  final normalizedGift = giftName.replaceAll(RegExp(r'\s+'), '');
  if (normalizedGift.isNotEmpty &&
      (normalized == normalizedGift ||
          normalized == '送出$normalizedGift' ||
          normalized == '赠送$normalizedGift')) {
    return '';
  }
  return text;
}

List<String> _collectHttpUrls(dynamic value, {int depth = 0}) {
  if (value == null || depth > 4) return const <String>[];
  if (value is String) {
    final trimmed = value.trim();
    final direct = _normalizeHuyaGiftUrl(trimmed);
    if (direct != null) return <String>[direct];
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        return _collectHttpUrls(jsonDecode(trimmed), depth: depth + 1);
      } catch (_) {
        return const <String>[];
      }
    }
    return const <String>[];
  }
  if (value is Map) {
    return _uniqueUrls(
      value.values.expand((item) => _collectHttpUrls(item, depth: depth + 1)),
    );
  }
  if (value is Iterable) {
    return _uniqueUrls(
      value.expand((item) => _collectHttpUrls(item, depth: depth + 1)),
    );
  }
  return const <String>[];
}

String? _normalizeHuyaGiftUrl(String? value) {
  final url = value?.trim() ?? '';
  if (url.isEmpty) return null;
  final normalized = url.startsWith('//') ? 'https:$url' : url;
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return normalized;
}

List<String> _uniqueUrls(Iterable<String> candidates) {
  final result = <String>[];
  final seen = <String>{};
  for (final candidate in candidates) {
    final normalized = _normalizeHuyaGiftUrl(candidate);
    if (normalized == null) continue;
    final uri = Uri.parse(normalized);
    final key = uri.replace(fragment: '').toString();
    if (seen.add(key)) result.add(normalized);
  }
  return result;
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

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().toLowerCase() == 'true';
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

int? _maxNullableInt(int? first, int? second) {
  if (first == null) return second;
  if (second == null) return first;
  return first >= second ? first : second;
}
