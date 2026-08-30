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
  static const Duration _giftCatalogWait = Duration(seconds: 3);
  static const int _maxPendingGifts = 100;
  static const int _giftDuplicateTtlMs = 2 * 60 * 1000;
  static const int _giftDuplicateCleanupInterval = 128;
  static const int _maxGiftDuplicateEntries = 4096;

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
        final name = item.propsName.trim();
        if (item.propsId > 0 && name.isNotEmpty) {
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
    if (!_isExpectedGroup(groupId)) return;

    switch (uri) {
      case HuyaPushUri.chat:
        _handleChatMessage(msg);
        break;
      case HuyaPushUri.attendeeCount:
        _handleOnlineCount(msg);
        break;
      case HuyaPushUri.giftSubChannel:
        _handleGiftMessage(
          msg,
          uri: uri,
          groupId: groupId,
          messageId: messageId,
        );
        break;
      case HuyaPushUri.vipEnterBanner:
        _handleVipEnter(msg, uri: uri);
        break;
      case HuyaPushUri.vipBarCount:
        _handleVipBarCount(msg, uri: uri);
        break;
    }
  }

  bool _isExpectedGroup(String groupId) {
    return groupId == _liveGroupId || groupId == _chatGroupId;
  }

  bool _matchesPresenter(int presenterUid) {
    return presenterUid == danmakuArgs.ayyuid;
  }

  void _handleChatMessage(List<int> msg) {
    final notice = HYMessage();
    notice.readFrom(TarsInputStream(Uint8List.fromList(msg)));
    if (notice.content.isEmpty) return;

    final color = notice.bulletFormat.fontColor;
    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.chat,
        color: color <= 0
            ? LiveMessageColor.white
            : LiveMessageColor.numberToColor(color),
        message: notice.content,
        userName: notice.userInfo.nickName,
      ),
    );
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
      if (gift.itemType <= 0 || gift.itemCount <= 0) return;
      if (!_matchesPresenter(gift.presenterUid)) return;
      if (gift.senderUid <= 0 && gift.senderNick.trim().isEmpty) return;
      if (_isDuplicateGift(gift, messageId)) return;

      final pending = _PendingHuyaGift(
        gift: gift,
        uri: uri,
        groupId: groupId,
        messageId: messageId,
      );
      final catalogItem = _giftCatalog[gift.itemType];
      final hasEmbeddedName = gift.propsName.trim().isNotEmpty;
      if (!hasEmbeddedName && catalogItem == null && !_giftCatalogReady) {
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
    // 服务端消息 ID 是单次广播的事实标识，应优先于可能跨连击分组复用的支付号。
    final key = messageId > 0
        ? "message:$messageId"
        : normalizedPayId.isNotEmpty
            ? "pay:$normalizedPayId:${gift.itemGroup}"
            : "";
    if (key.isEmpty) return false;

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
    final count = gift.itemCount;
    final sender = gift.senderNick.trim().isNotEmpty
        ? gift.senderNick.trim()
        : "UID ${gift.senderUid}";
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
          "templateType": gift.templateType,
          "business": gift.business,
          "colorEffectType": gift.colorEffectType,
          "resourceUrl": gift.diyEffect.resourceUrl,
          "resourceAttr": gift.diyEffect.resourceAttr,
          "webResourceUrl": gift.diyEffect.webResourceUrl,
          "pcResourceUrl": gift.diyEffect.pcResourceUrl,
          "content": gift.sendContent,
        },
        color: LiveMessageColor.white,
        message: "🎁 $sender 送出 $giftName x$count",
        userName: sender,
      ),
    );
  }

  void _handleVipEnter(List<int> msg, {required int uri}) {
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

      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.vipEnter,
          data: {
            "kind": "vipEnter",
            "uri": uri,
            "uid": banner.uid,
            "pid": banner.pid,
            "nickName": nickName,
            "logoUrl": banner.logoUrl,
          },
          color: LiveMessageColor.white,
          message: "⭐ $nickName 进入直播间",
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
