import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/web_socket_util.dart';
import 'package:simple_live_core/src/model/tars/huya_danmaku.dart';
import 'package:simple_live_core/src/platforms/huya/huya_gift_catalog.dart';
import 'package:simple_live_core/src/platforms/huya/huya_hysignal.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/tup/const.dart';
import 'package:tars_dart/tars/tup/tars_uni_packet.dart';

class HuyaDanmakuArgs {
  final int ayyuid;
  final int topSid;
  final int subSid;
  HuyaDanmakuArgs({
    required this.ayyuid,
    required this.topSid,
    required this.subSid,
  });
  @override
  String toString() {
    return json.encode({"ayyuid": ayyuid, "topSid": topSid, "subSid": subSid});
  }
}

class HuyaDanmaku implements LiveDanmaku {
  static const Duration _giftCatalogWait = Duration(milliseconds: 1200);
  static const int _maxPendingGifts = 100;
  static const int _giftDuplicateTtlMs = 2 * 60 * 1000;
  static const int _giftDuplicateCleanupInterval = 128;
  static const int _maxGiftDuplicateEntries = 4096;
  static const int _nobleDecorationAppId = 10200;
  static const int _fansBadgeDecorationAppId = 10400;

  final Duration registerAckTimeout;
  final int maxRegisterAttempts;
  final Duration socketReconnectInterval;

  HuyaDanmaku({
    this.registerAckTimeout = const Duration(seconds: 8),
    this.maxRegisterAttempts = 3,
    this.socketReconnectInterval = const Duration(seconds: 5),
  })  : assert(maxRegisterAttempts > 0),
        assert(!registerAckTimeout.isNegative),
        assert(!socketReconnectInterval.isNegative);

  @override
  int heartbeatTime = 60 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  String serverUrl = "wss://cdnws.api.huya.com";
  WebScoketUtils? webScoketUtils;

  final heartbeatData = _buildWebSocketCommand(
    HuyaHySignalCommandType.heartbeatRequest,
    const <int>[],
  );
  late HuyaDanmakuArgs danmakuArgs;

  final Map<int, HYPropsItem> _giftCatalog = <int, HYPropsItem>{};
  final List<_PendingHuyaGift> _pendingGifts = <_PendingHuyaGift>[];
  final Map<String, int> _giftDuplicateCache = <String, int>{};

  Timer? _giftCatalogTimer;
  Timer? _registerAckTimer;
  int _giftCatalogRequestId = 0;
  int _registerAttempt = 0;
  int _giftDuplicateChecks = 0;
  bool _giftCatalogRequested = false;
  bool _giftCatalogReady = false;
  bool _protocolReady = false;
  bool _stopped = true;

  String get _liveGroupId => "live:${danmakuArgs.ayyuid}";
  String get _chatGroupId => "chat:${danmakuArgs.ayyuid}";

  @override
  Future start(dynamic args) async {
    danmakuArgs = args as HuyaDanmakuArgs;
    _stopped = false;
    _protocolReady = false;
    _giftCatalogRequested = false;
    _giftCatalogReady = false;
    _giftCatalogRequestId = 0;
    _giftCatalog.clear();
    _pendingGifts.clear();
    _giftDuplicateCache.clear();
    _giftDuplicateChecks = 0;
    _giftCatalogTimer?.cancel();
    _registerAckTimer?.cancel();
    _registerAttempt = 0;

    if (danmakuArgs.ayyuid <= 0) {
      _stopped = true;
      onClose?.call("虎牙主播 UID 无效，无法订阅弹幕");
      return;
    }

    webScoketUtils = WebScoketUtils(
      url: serverUrl,
      heartBeatTime: heartbeatTime,
      onMessage: (e) {
        if (e is List<int>) {
          decodeMessage(e);
        }
      },
      onReady: _handleSocketReady,
      onHeartBeat: heartbeat,
      reconnectInterval: socketReconnectInterval,
      onReconnect: () {
        _protocolReady = false;
        _registerAckTimer?.cancel();
        _registerAckTimer = null;
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        onClose?.call("服务器连接失败$e");
      },
    );
    webScoketUtils?.connect();
  }

  void _handleSocketReady() {
    _protocolReady = false;
    _giftCatalogRequested = false;
    _giftCatalogRequestId = 0;
    _giftCatalogTimer?.cancel();
    _registerAckTimer?.cancel();
    _registerAttempt = 0;
    joinRoom();
  }

  void joinRoom() {
    if (_stopped || _protocolReady) return;

    final registerData = getJoinData(
      danmakuArgs.ayyuid,
      danmakuArgs.topSid,
      danmakuArgs.subSid,
    );
    if (registerData.isEmpty) {
      CoreLog.error("构造虎牙房间订阅请求失败");
      webScoketUtils?.reconnect();
      return;
    }

    _registerAttempt++;
    webScoketUtils?.sendMessage(registerData);
    _startRegisterAckWatchdog();
  }

  void _startRegisterAckWatchdog() {
    _registerAckTimer?.cancel();
    _registerAckTimer = Timer(registerAckTimeout, () {
      if (_stopped || _protocolReady) return;
      if (_registerAttempt < maxRegisterAttempts) {
        CoreLog.w(
          "虎牙房间订阅响应超时，正在第 ${_registerAttempt + 1} 次发送订阅请求",
        );
        joinRoom();
        return;
      }

      CoreLog.w("虎牙房间订阅连续超时，放弃当前连接并重连");
      webScoketUtils?.reconnect();
    });
  }

  /// 构造当前虎牙网页协议使用的 WSRegisterGroupReq。
  ///
  /// [tid] 与 [sid] 为保留参数，用于兼容既有调用；分组订阅只依赖主播 UID。
  List<int> getJoinData(int ayyuid, int tid, int sid) {
    return getRegisterGroupData(ayyuid);
  }

  List<int> getRegisterGroupData(int presenterUid) {
    try {
      final request = TarsOutputStream()
        ..write(<String>["live:$presenterUid", "chat:$presenterUid"], 0)
        ..write("", 1);

      return _buildWebSocketCommand(
        HuyaHySignalCommandType.registerGroupRequest,
        request.toUint8List(),
      );
    } catch (e) {
      CoreLog.error(e);
      return <int>[];
    }
  }

  /// 构造 PropsUIServer.getPropsList WUP 请求，用于把礼物 ID 映射为真实名称。
  List<int> getGiftCatalogRequestData(
    HuyaDanmakuArgs args, {
    required int requestId,
  }) {
    final userId = HYUserId();
    final request = HYGetPropsListReq()
      ..userId = userId
      ..templateType = 32
      ..presenterUid = args.ayyuid
      ..sid = args.topSid
      ..subSid = args.subSid;

    final packet = TarsUniPacket()
      ..setTarsVersion(Const.PACKET_TYPE_TUP3)
      ..requestId = requestId
      ..servantName = "PropsUIServer"
      ..funcName = "getPropsList";
    packet.put("tReq", request);

    return _buildWebSocketCommand(
      HuyaHySignalCommandType.wupRequest,
      packet.encode(),
    );
  }

  /// 当前网页 WebSocketCommand 完整结构（tag 0-6）。
  static List<int> _buildWebSocketCommand(
    int commandType,
    List<int> payload,
  ) {
    final command = TarsOutputStream()
      ..write(commandType, 0)
      ..write(Uint8List.fromList(payload), 1)
      ..write(0, 2)
      ..write("", 3)
      ..write(0, 4)
      ..write(0, 5)
      ..write("", 6);
    return command.toUint8List();
  }

  @override
  void heartbeat() {
    webScoketUtils?.sendMessage(heartbeatData);
  }

  @override
  Future stop() async {
    _stopped = true;
    _protocolReady = false;
    _giftCatalogTimer?.cancel();
    _giftCatalogTimer = null;
    _registerAckTimer?.cancel();
    _registerAckTimer = null;
    _registerAttempt = 0;
    _pendingGifts.clear();
    _giftDuplicateCache.clear();
    _giftDuplicateChecks = 0;
    onMessage = null;
    onClose = null;
    onReady = null;
    webScoketUtils?.close();
    webScoketUtils = null;
  }

  void decodeMessage(List<int> data) {
    try {
      final stream = TarsInputStream(Uint8List.fromList(data));
      final type = stream.read(0, 0, false);
      final payload = stream.readBytes(1, false);

      switch (type) {
        case HuyaHySignalCommandType.registerGroupResponse:
          _handleRegisterGroupResponse(payload);
          break;
        case HuyaHySignalCommandType.wupResponse:
          _handleWupResponse(payload);
          break;
        case HuyaHySignalCommandType.pushMessage:
          final pushMessage = HYPushMessage();
          pushMessage.readFrom(TarsInputStream(payload));
          _handlePushMessage(
            pushMessage.uri,
            pushMessage.msg,
            groupId: pushMessage.groupId,
            messageId: pushMessage.messageId,
          );
          break;
        case HuyaHySignalCommandType.pushMessageV2:
          final pushMessage = HYWSPushMessageV2();
          pushMessage.readFrom(TarsInputStream(payload));
          for (final item in pushMessage.items) {
            if (item.uri <= 0 || item.message.isEmpty) continue;
            _handlePushMessage(
              item.uri,
              item.message,
              groupId: pushMessage.groupId,
              messageId: item.messageId,
            );
          }
          break;
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }

  void _handleRegisterGroupResponse(Uint8List payload) {
    final response = HYWSRegisterGroupRsp();
    response.readFrom(TarsInputStream(payload));
    _registerAckTimer?.cancel();
    _registerAckTimer = null;
    if (response.resultCode != 0) {
      onClose?.call("虎牙房间订阅失败，错误码 ${response.resultCode}");
      webScoketUtils?.close();
      return;
    }

    if (!_protocolReady) {
      _protocolReady = true;
      _registerAttempt = 0;
      _requestGiftCatalog();
      onReady?.call();
    }
  }

  void _requestGiftCatalog() {
    if (_giftCatalogRequested || _stopped) return;
    _giftCatalogRequested = true;
    _giftCatalogRequestId = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    if (_giftCatalogRequestId == 0) {
      _giftCatalogRequestId = 1;
    }

    try {
      webScoketUtils?.sendMessage(
        getGiftCatalogRequestData(
          danmakuArgs,
          requestId: _giftCatalogRequestId,
        ),
      );
      _giftCatalogTimer?.cancel();
      _giftCatalogTimer = Timer(_giftCatalogWait, () {
        if (_stopped || _giftCatalogReady) return;
        _giftCatalogReady = true;
        CoreLog.w("虎牙礼物目录请求超时，未识别礼物将明确标记为未知");
        _flushPendingGifts();
      });
    } catch (e) {
      CoreLog.error("请求虎牙礼物目录失败: $e");
      _giftCatalogReady = true;
      _flushPendingGifts();
    }
  }

  void _handleWupResponse(Uint8List payload) {
    try {
      final packet = TarsUniPacket();
      packet.decode(payload);
      if (packet.funcName != "getPropsList") return;
      if (_giftCatalogRequestId > 0 &&
          packet.requestId > 0 &&
          packet.requestId != _giftCatalogRequestId) {
        return;
      }

      final response = packet.get("tRsp", HYGetPropsListRsp());
      final catalog = <int, HYPropsItem>{};
      for (final item in response.items) {
        // 图片、价格和效果资源不依赖礼物名；名称为空的合法条目也必须保留。
        if (item.propsId > 0) {
          catalog[item.propsId] = item;
        }
      }
      if (catalog.isEmpty) {
        CoreLog.w("虎牙礼物目录响应为空，等待超时后按未知礼物处理");
        return;
      }

      _giftCatalog
        ..clear()
        ..addAll(catalog);
      _giftCatalogReady = true;
      _giftCatalogTimer?.cancel();
      _giftCatalogTimer = null;
      _flushPendingGifts();
    } catch (e) {
      CoreLog.error("解析虎牙礼物目录失败: $e");
    }
  }

  void _handlePushMessage(
    int uri,
    List<int> msg, {
    required String groupId,
    required int messageId,
  }) {
    final isGiftUri =
        _isGiftTransactionUri(uri) || uri == HuyaPushUri.bigGiftEffect;
    if (!_isExpectedGroup(groupId) && !(isGiftUri && groupId.isEmpty)) return;

    switch (uri) {
      case HuyaPushUri.chat:
        _handleChatMessage(msg);
        break;
      case HuyaPushUri.attendeeCount:
        _handleOnlineCount(msg);
        break;
      case HuyaPushUri.giftSubChannel:
      case HuyaPushUri.giftTopChannel:
      case HuyaPushUri.giftGameBroadcast:
      case HuyaPushUri.giftOtherBroadcast:
        _handleGiftMessage(
          msg,
          uri: uri,
          groupId: groupId,
          messageId: messageId,
        );
        break;
      case HuyaPushUri.bigGiftEffect:
        _handleGiftEffectMessage(
          msg,
          uri: uri,
          groupId: groupId,
          messageId: messageId,
        );
        break;
      case HuyaPushUri.vipEnterBanner:
        _handleVipEnter(
          msg,
          uri: uri,
          groupId: groupId,
          messageId: messageId,
        );
        break;
      case HuyaPushUri.vipBarCount:
        _handleVipBarCount(msg, uri: uri);
        break;
    }
  }

  bool _isExpectedGroup(String groupId) {
    return groupId == _liveGroupId || groupId == _chatGroupId;
  }

  bool _isGiftTransactionUri(int uri) {
    return uri == HuyaPushUri.giftSubChannel ||
        uri == HuyaPushUri.giftTopChannel ||
        uri == HuyaPushUri.giftGameBroadcast ||
        uri == HuyaPushUri.giftOtherBroadcast;
  }

  bool _matchesGiftPresenter(HYSendItemSubBroadcastPacket gift) {
    // presenterUid 有值时它是更精确的当前收礼主播；仅旧包缺失该字段时
    // 才回退到 homeOwnerUid，避免把同公会/转播房间的礼物混入当前房间。
    if (gift.presenterUid > 0) {
      return gift.presenterUid == danmakuArgs.ayyuid;
    }
    return gift.homeOwnerUid == danmakuArgs.ayyuid;
  }

  int _resolvedGiftCount(HYSendItemSubBroadcastPacket gift) {
    if (gift.itemCount > 0) return gift.itemCount;
    if (gift.itemCountByGroup > 0) return gift.itemCountByGroup;
    return 1;
  }

  bool _matchesPresenter(int presenterUid) {
    return presenterUid == danmakuArgs.ayyuid;
  }

  void _handleChatMessage(List<int> msg) {
    final notice = HYMessage();
    notice.readFrom(TarsInputStream(Uint8List.fromList(msg)));
    if (notice.content.isEmpty) return;

    final color = notice.bulletFormat.fontColor;
    final fansBadge = _parseFansBadge(notice.decorationPrefix);
    final noble = _resolveChatNoble(notice);
    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.chat,
        data: {
          "kind": "chat",
          "uid": notice.userInfo.uid,
          "tid": notice.tid,
          "sid": notice.sid,
          "pid": notice.pid,
          "iconUrl": notice.iconUrl,
          if (fansBadge != null) "fanBadge": fansBadge,
          if (noble != null) ...noble,
        },
        color: color <= 0
            ? LiveMessageColor.white
            : LiveMessageColor.numberToColor(color),
        message: notice.content,
        userName: notice.userInfo.nickName,
      ),
    );
  }

  Map<String, dynamic>? _resolveChatNoble(HYMessage notice) {
    final directLevel = notice.userInfo.nobleLevel;
    final nestedLevel = notice.userInfo.nobleLevelInfo.nobleLevel;
    final hasDirectLevel = _nobleNameForLevel(directLevel).isNotEmpty;
    final hasNestedLevel = _nobleNameForLevel(nestedLevel).isNotEmpty;
    var level = hasDirectLevel
        ? directLevel
        : hasNestedLevel
            ? nestedLevel
            : 0;
    var name = "";
    var source = hasDirectLevel
        ? "sender"
        : hasNestedLevel
            ? "senderInfo"
            : "";

    if (level <= 0) {
      final legacy = _parseLegacyNoble(notice.decorationPrefix);
      if (legacy != null) {
        level = legacy.level;
        name = legacy.name.trim();
        source = "decoration";
      }
    }

    final canonicalName = _nobleNameForLevel(level);
    if (canonicalName.isEmpty) return null;
    return <String, dynamic>{
      "nobleName": name.isNotEmpty ? name : canonicalName,
      "nobleLevel": level,
      "nobleSource": source,
      if (notice.userInfo.nobleLevelInfo.attrType != 0)
        "nobleAttrType": notice.userInfo.nobleLevelInfo.attrType,
    };
  }

  HYLegacyNobleBase? _parseLegacyNoble(
    List<HYDecorationInfo> decorations,
  ) {
    for (final decoration in decorations) {
      if (decoration.appId != _nobleDecorationAppId ||
          decoration.data.isEmpty) {
        continue;
      }
      try {
        final noble = HYLegacyNobleBase()
          ..readFrom(TarsInputStream(decoration.data));
        if (_nobleNameForLevel(noble.level).isNotEmpty) return noble;
      } catch (_) {
        // 旧爵位装饰是兼容回退；异常时继续使用现代 SenderInfo 字段。
      }
    }
    return null;
  }

  String _nobleNameForLevel(int level) {
    return switch (level) {
      1 => "剑士",
      2 => "骑士",
      3 => "领主",
      4 => "公爵",
      5 => "君王",
      6 => "帝皇",
      _ => "",
    };
  }

  Map<String, dynamic>? _parseFansBadge(
    List<HYDecorationInfo> decorations,
  ) {
    for (final decoration in decorations) {
      if (decoration.appId != _fansBadgeDecorationAppId ||
          decoration.data.isEmpty) {
        continue;
      }
      try {
        final badge = HYFansBadgeInfo()
          ..readFrom(TarsInputStream(decoration.data));
        final badgeName = badge.badgeName.trim();
        if (badgeName.isEmpty || badge.badgeLevel <= 0) continue;
        return <String, dynamic>{
          "id": badge.badgeId,
          "name": badgeName,
          "level": badge.badgeLevel,
          "appId": decoration.appId,
          "viewType": decoration.viewType,
        };
      } catch (_) {
        // 装饰前缀是可选协议；单条异常不能影响普通聊天弹幕。
      }
    }
    return null;
  }

  void _handleOnlineCount(List<int> msg) {
    var online = 0;
    try {
      final notice = HYAttendeeCountNotice();
      notice.readFrom(TarsInputStream(Uint8List.fromList(msg)));
      online = notice.attendeeCount;
    } catch (_) {
      final stream = TarsInputStream(Uint8List.fromList(msg));
      online = stream.read(online, 0, false);
    }
    if (online < 0) return;

    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.online,
        data: online,
        color: LiveMessageColor.white,
        message: "",
        userName: "",
      ),
    );
  }

  void _handleGiftMessage(
    List<int> msg, {
    required int uri,
    required String groupId,
    required int messageId,
  }) {
    try {
      final gift = HYSendItemSubBroadcastPacket();
      gift.readFrom(TarsInputStream(Uint8List.fromList(msg)));
      if (gift.itemType <= 0) return;
      if (!_matchesGiftPresenter(gift)) return;
      if (_isDuplicateGift(gift, messageId)) return;

      final pending = _PendingHuyaGift(
        gift: gift,
        uri: uri,
        groupId: groupId,
        messageId: messageId,
      );
      final catalogItem = _giftCatalog[gift.itemType];
      // 目录不仅提供名称，还提供图片、价格和效果资源。任何缺少目录元数据的
      // 礼物都短暂等待目录，避免刚进房时永久退化成通用图标。
      if (catalogItem == null && _giftCatalogRequested && !_giftCatalogReady) {
        if (_pendingGifts.length >= _maxPendingGifts) {
          _emitGift(_pendingGifts.removeAt(0), catalogItem: null);
        }
        _pendingGifts.add(pending);
        return;
      }
      _emitGift(pending, catalogItem: catalogItem);
    } catch (e) {
      CoreLog.error("解析虎牙礼物消息($uri)失败: $e");
    }
  }

  bool _isDuplicateGift(
    HYSendItemSubBroadcastPacket gift,
    int messageId,
  ) {
    final normalizedPayId = gift.payId.trim();
    // 同一交易可能同时出现在 6501/6502/6507/6514，并拥有不同 messageId。
    // 支付号与连击分组优先用于跨 URI 去重；无支付号时再使用消息 ID。
    final key = normalizedPayId.isNotEmpty
        ? "pay:$normalizedPayId:${gift.itemGroup}"
        : messageId > 0
            ? "message:$messageId"
            : "";
    return key.isNotEmpty && _rememberGiftDuplicateKey(key);
  }

  bool _rememberGiftDuplicateKey(String key) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = _giftDuplicateCache[key];
    if (expiresAt != null && expiresAt > now) return true;
    if (expiresAt != null) {
      _giftDuplicateCache.remove(key);
    }

    _giftDuplicateCache[key] = now + _giftDuplicateTtlMs;
    _giftDuplicateChecks++;
    if (_giftDuplicateChecks >= _giftDuplicateCleanupInterval ||
        _giftDuplicateCache.length > _maxGiftDuplicateEntries) {
      _giftDuplicateChecks = 0;
      _giftDuplicateCache.removeWhere((_, expiry) => expiry <= now);
      while (_giftDuplicateCache.length > _maxGiftDuplicateEntries) {
        _giftDuplicateCache.remove(_giftDuplicateCache.keys.first);
      }
    }
    return false;
  }

  void _flushPendingGifts() {
    if (_pendingGifts.isEmpty) return;
    final pending = List<_PendingHuyaGift>.from(_pendingGifts);
    _pendingGifts.clear();
    for (final item in pending) {
      _emitGift(item, catalogItem: _giftCatalog[item.gift.itemType]);
    }
  }

  void _emitGift(
    _PendingHuyaGift pending, {
    required HYPropsItem? catalogItem,
  }) {
    final gift = pending.gift;
    final count = _resolvedGiftCount(gift);
    final sender = gift.senderNick.trim().isNotEmpty
        ? gift.senderNick.trim()
        : gift.senderUid > 0
            ? "UID ${gift.senderUid}"
            : "虎牙用户";
    final embeddedGiftName = gift.propsName.trim();
    final catalogGiftName = catalogItem?.propsName.trim() ?? "";
    final giftName = embeddedGiftName.isNotEmpty
        ? embeddedGiftName
        : catalogGiftName.isNotEmpty
            ? catalogGiftName
            : "未知礼物（ID ${gift.itemType}）";
    final catalogUnitPriceYb = catalogItem?.propsYb;
    final catalogNominalTotalYb =
        catalogUnitPriceYb == null ? null : catalogUnitPriceYb * count;
    final sendContent = gift.sendContent.trim();
    final customText = gift.customText.trim();

    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.gift,
        data: {
          "kind": "giftTransaction",
          "uri": pending.uri,
          "groupId": pending.groupId,
          "messageId": pending.messageId,
          "sender": sender,
          "senderUid": gift.senderUid,
          "senderIcon": gift.senderIcon,
          "presenter": gift.presenterNick,
          "presenterUid": gift.presenterUid,
          "giftName": giftName,
          "giftId": gift.itemType,
          "count": count,
          "itemCount": gift.itemCount,
          "itemCountByGroup": gift.itemCountByGroup,
          "itemGroup": gift.itemGroup,
          "payId": gift.payId,
          "catalogUnitPriceYb": catalogUnitPriceYb,
          "catalogNominalTotalYb": catalogNominalTotalYb,
          "giftImageUrls": catalogItem?.imageCandidates ?? const <String>[],
          "giftEffectUrls": catalogItem?.effectCandidates ?? const <String>[],
          "payType": gift.payType,
          "payTotal": gift.payTotal,
          "roomId": gift.roomId,
          "homeOwnerUid": gift.homeOwnerUid,
          "effectType": gift.effectType,
          "comboScore": gift.comboScore,
          "comboSeqId": gift.comboSeqId,
          "comboStatus": gift.comboStatus,
          "displayInfo": gift.displayInfo,
          "templateType": gift.templateType,
          "business": gift.business,
          "colorEffectType": gift.colorEffectType,
          "eventType": gift.eventType,
          "accept": gift.accept,
          "superPurpleLevel": gift.superPurpleLevel,
          "nobleLevel": gift.nobleLevel,
          "vFanLevel": gift.vFanLevel,
          "upgradeLevel": gift.upgradeLevel,
          "multiSend": gift.multiSend,
          "expand": gift.expand,
          "effectInfo": {
            "priceLevel": gift.effectInfo.priceLevel,
            "streamDuration": gift.effectInfo.streamDuration,
            "showType": gift.effectInfo.showType,
            "streamId": gift.effectInfo.streamId,
            "showAsStream": gift.effectInfo.showAsStream,
            "showAsBigEffect": gift.effectInfo.showAsBigEffect,
          },
          "bizData": gift.bizData
              .map(
                (item) => {
                  "type": item.type,
                  "dataBase64": base64Encode(item.data),
                  "text": _tryDecodeGiftBizText(item.data),
                },
              )
              .toList(growable: false),
          "resourceUrl": gift.diyEffect.resourceUrl,
          "resourceAttr": gift.diyEffect.resourceAttr,
          "webResourceUrl": gift.diyEffect.webResourceUrl,
          "pcResourceUrl": gift.diyEffect.pcResourceUrl,
          // 两个字段均来自 URI 6501 广播包，不能用礼物名或本地文案代替。
          "sendContent": sendContent,
          "customText": customText,
          // 保留旧字段供现有调用方兼容；其值仍严格等于服务端 sendContent。
          "content": sendContent,
        },
        color: LiveMessageColor.white,
        message: "🎁 $sender 送出 $giftName x$count",
        userName: sender,
      ),
    );
  }

  String _tryDecodeGiftBizText(Uint8List data) {
    if (data.isEmpty) return "";
    try {
      final text = utf8.decode(data, allowMalformed: false).trim();
      if (text.isEmpty || text.contains("\u0000")) return "";
      return text.length > 2048 ? text.substring(0, 2048) : text;
    } catch (_) {
      return "";
    }
  }

  int _effectParamInt(Map<String, String> params) {
    const keys = <String>{
      "paytotal",
      "totalprice",
      "price",
      "value",
      "yb",
    };
    for (final entry in params.entries) {
      if (!keys.contains(entry.key.trim().toLowerCase())) continue;
      final parsed = int.tryParse(entry.value.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
    return 0;
  }

  void _handleGiftEffectMessage(
    List<int> msg, {
    required int uri,
    required String groupId,
    required int messageId,
  }) {
    try {
      final effect = HYLiveRoomLargeConsumptionEffectNotice();
      effect.readFrom(TarsInputStream(Uint8List.fromList(msg)));
      if (effect.presenterUid != danmakuArgs.ayyuid) return;

      final sender = effect.customerNick.trim().isNotEmpty
          ? effect.customerNick.trim()
          : effect.customerUid > 0
              ? "UID ${effect.customerUid}"
              : "虎牙用户";
      final itemName =
          effect.itemName.trim().isNotEmpty ? effect.itemName.trim() : "高价值礼物";
      final duplicateKey =
          "effect:${effect.effectId}:${effect.customerUid}:$itemName";
      if (_rememberGiftDuplicateKey(duplicateKey)) return;

      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.gift,
          data: {
            "kind": "giftEffectNotice",
            "uri": uri,
            "groupId": groupId,
            "messageId": messageId,
            "effectId": effect.effectId,
            "presenterUid": effect.presenterUid,
            "sender": sender,
            "senderUid": effect.customerUid,
            "senderIcon": effect.customerAvatar,
            "recipientUid": effect.recipientUid,
            "recipientNick": effect.recipientNick,
            "recipientAvatar": effect.recipientAvatar,
            "giftName": itemName,
            "giftId": effect.effectId,
            "count": 1,
            "itemCount": 1,
            "payTotal": _effectParamInt(effect.effectParams),
            "isBigEffect": true,
            "effectParams": effect.effectParams,
            "giftEffectUrls": effect.effectParams.values
                .where((value) => value.trim().isNotEmpty)
                .toList(growable: false),
          },
          color: LiveMessageColor.white,
          message: "🎁 $sender 送出 $itemName",
          userName: sender,
        ),
      );
    } catch (e) {
      CoreLog.error("解析虎牙大额礼物特效消息($uri)失败: $e");
    }
  }

  void _handleVipEnter(
    List<int> msg, {
    required int uri,
    required String groupId,
    required int messageId,
  }) {
    try {
      final banner = HYVipEnterBanner();
      banner.readFrom(TarsInputStream(Uint8List.fromList(msg)));
      if (!_matchesPresenter(banner.pid)) return;
      final nickName = banner.nickName.trim().isNotEmpty
          ? banner.nickName.trim()
          : banner.uid > 0
              ? "UID ${banner.uid}"
              : "";
      if (nickName.isEmpty) return;

      final nobleName = banner.nobleInfo.name.trim();
      final nobleLevel = banner.nobleInfo.level;
      final hasNoble = nobleName.isNotEmpty && nobleLevel > 0;

      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.vipEnter,
          data: {
            "kind": "vipEnter",
            "uri": uri,
            "groupId": groupId,
            "messageId": messageId,
            "uid": banner.uid,
            "pid": banner.pid,
            "nickName": nickName,
            "logoUrl": banner.logoUrl,
            if (hasNoble) "nobleName": nobleName,
            if (hasNoble) "nobleLevel": nobleLevel,
          },
          color: LiveMessageColor.white,
          message: "$nickName 进入直播间",
          userName: nickName,
        ),
      );
    } catch (e) {
      CoreLog.error("解析虎牙贵宾进场消息($uri)失败: $e");
    }
  }

  void _handleVipBarCount(List<int> msg, {required int uri}) {
    try {
      final stat = HYVipBarListStatInfo();
      stat.readFrom(TarsInputStream(Uint8List.fromList(msg)));
      if (stat.total < 0 || !_matchesPresenter(stat.pid)) return;

      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.vipCount,
          data: {
            "kind": "vipCountSnapshot",
            "uri": uri,
            "count": stat.total,
            "pid": stat.pid,
          },
          color: LiveMessageColor.white,
          message: "",
          userName: "",
        ),
      );
    } catch (e) {
      CoreLog.error("解析虎牙贵宾数量消息($uri)失败: $e");
    }
  }
}

class _PendingHuyaGift {
  final HYSendItemSubBroadcastPacket gift;
  final int uri;
  final String groupId;
  final int messageId;

  const _PendingHuyaGift({
    required this.gift,
    required this.uri,
    required this.groupId,
    required this.messageId,
  });
}
