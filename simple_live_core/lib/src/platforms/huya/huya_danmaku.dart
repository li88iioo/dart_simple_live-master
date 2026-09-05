import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/web_socket_util.dart';
import 'package:simple_live_core/src/model/tars/huya_danmaku.dart';
import 'package:simple_live_core/src/platforms/huya/huya_gift_catalog.dart';
import 'package:simple_live_core/src/platforms/huya/huya_gift_broadcast.dart';
import 'package:simple_live_core/src/platforms/huya/huya_gift_resources.dart';
import 'package:simple_live_core/src/platforms/huya/huya_guardian_notice.dart';
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

/// 礼物附加数据中的 eventId 标识临时特效卡片；后到的真实交易若携带
/// replacesEventId，消费者应原位替换该事件，不将两次回调的数量累加或重播。
/// 不同道具/分组的交易仍为独立事件，没有共同强 ID 时不猜测关联。
class HuyaDanmaku implements LiveDanmaku {
  static const Duration _giftCatalogWait = Duration(milliseconds: 1200);
  static const int _maxPendingGifts = 100;
  static const int _giftDuplicateTtlMs = 2 * 60 * 1000;
  static const int _giftDuplicateCleanupInterval = 128;
  static const int _maxGiftDuplicateEntries = 4096;
  // 6540 的活动资源尚未接入；6249/1020003 是人数/状态更新，不冒充购买。
  static const Set<int> _unhandledGiftUris = {6540, 6249, 1020003};
  static const int _maxGiftExtensionBytes = 128 * 1024;
  final Set<String> _reportedGiftIssues = <String>{};
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
  final Map<String, _HuyaGiftCrossKindEntry> _giftCrossKindDuplicateCache =
      <String, _HuyaGiftCrossKindEntry>{};

  Timer? _giftCatalogTimer;
  Timer? _registerAckTimer;
  int _giftCatalogRequestId = 0;
  int _registerAttempt = 0;
  int _giftDuplicateChecks = 0;
  bool _giftCatalogRequested = false;
  bool _giftCatalogReady = false;
  bool _protocolReady = false;
  bool _stopped = true;
  int _socketGeneration = 0;
  int _effectEventSequence = 0;

  String get _liveGroupId => "live:${danmakuArgs.ayyuid}";
  String get _chatGroupId => "chat:${danmakuArgs.ayyuid}";

  @override
  Future start(dynamic args) async {
    // 同实例重启先关闭旧连接，保留业务回调；旧连接的迟到回调不能操作新房间。
    final generation = ++_socketGeneration;
    webScoketUtils?.close();
    webScoketUtils = null;
    _effectEventSequence = 0;
    danmakuArgs = args as HuyaDanmakuArgs;
    _stopped = false;
    _protocolReady = false;
    _giftCatalogRequested = false;
    _giftCatalogReady = false;
    _giftCatalogRequestId = 0;
    _giftCatalog.clear();
    _reportedGiftIssues.clear();
    _pendingGifts.clear();
    _giftDuplicateCache.clear();
    _giftCrossKindDuplicateCache.clear();
    _giftDuplicateChecks = 0;
    _giftCatalogTimer?.cancel();
    _giftCatalogTimer = null;
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
      readTimeout: const Duration(minutes: 3),
      onMessage: (e) {
        if (_stopped || generation != _socketGeneration) return;
        if (e is List<int>) {
          decodeMessage(e);
        }
      },
      onReady: () {
        if (_stopped || generation != _socketGeneration) return;
        _handleSocketReady();
      },
      onHeartBeat: heartbeat,
      reconnectInterval: socketReconnectInterval,
      onReconnect: () {
        if (_stopped || generation != _socketGeneration) return;
        _protocolReady = false;
        _registerAckTimer?.cancel();
        _registerAckTimer = null;
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        if (_stopped || generation != _socketGeneration) return;
        onClose?.call("服务器连接失败$e");
      },
    );
    webScoketUtils?.connect();
  }

  void _handleSocketReady() {
    _reportedGiftIssues.clear();
    _protocolReady = false;
    _giftCatalogRequested = false;
    _giftCatalogRequestId = 0;
    // 保留首次目录等待的截止时间；重连 ACK 延迟也不能卡住已接收的礼物。
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
    _socketGeneration++;
    _stopped = true;
    _protocolReady = false;
    _giftCatalogTimer?.cancel();
    _giftCatalogTimer = null;
    _registerAckTimer?.cancel();
    _registerAckTimer = null;
    _registerAttempt = 0;
    _pendingGifts.clear();
    _giftDuplicateCache.clear();
    _giftCrossKindDuplicateCache.clear();
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
            try {
              _handlePushMessage(
                item.uri,
                item.message,
                groupId: pushMessage.groupId,
                messageId: item.messageId,
              );
            } catch (_) {
              // 批内一条损坏的聊天/礼物不应吞掉其后的合法通知。
              _reportGiftIssue(
                  'batch-item:${item.uri}', item.uri, item.message.length);
            }
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
      _giftCatalogTimer ??= Timer(_giftCatalogWait, () {
        _giftCatalogTimer = null;
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
    final isGiftUri = _isGiftTransactionUri(uri) ||
        uri == HuyaPushUri.bigGiftEffect ||
        uri == HuyaPushUri.giftOtherBroadcast ||
        uri == HuyaPushUri.giftActivityBroadcast ||
        uri == HuyaPushUri.guardianNotice;
    if (!_isExpectedGroup(groupId) &&
        !((isGiftUri || _unhandledGiftUris.contains(uri)) && groupId.isEmpty)) {
      return;
    }

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
        _handleGiftMessage(
          msg,
          uri: uri,
          groupId: groupId,
          messageId: messageId,
        );
        break;
      case HuyaPushUri.giftOtherBroadcast:
        _handleDrawingGift(msg, groupId: groupId, messageId: messageId);
        break;
      case HuyaPushUri.giftActivityBroadcast:
        _handleActivityGift(msg, groupId: groupId, messageId: messageId);
        break;
      case HuyaPushUri.guardianNotice:
        _handleGuardianNotice(msg, groupId: groupId, messageId: messageId);
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
      default:
        if (_unhandledGiftUris.contains(uri)) {
          _reportGiftIssue('unsupported:$uri', uri, msg.length);
        }
    }
  }

  bool _isExpectedGroup(String groupId) {
    return groupId == _liveGroupId || groupId == _chatGroupId;
  }

  bool _isGiftTransactionUri(int uri) {
    return uri == HuyaPushUri.giftSubChannel ||
        uri == HuyaPushUri.giftTopChannel ||
        uri == HuyaPushUri.giftGameBroadcast;
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
    return 0;
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
      final input = TarsInputStream(Uint8List.fromList(msg));
      // URI 不只是来源标记，它决定 TARS 字段布局。先独立解码，再统一事实。
      final HYSendItemSubBroadcastPacket gift;
      switch (uri) {
        case HuyaPushUri.giftSubChannel:
          gift = HYSendItemSubBroadcastPacket()..readFrom(input);
          break;
        case HuyaPushUri.giftTopChannel:
          gift =
              (HYSendItemNoticeWordBroadcastPacket()..readFrom(input)).toGift();
          break;
        case HuyaPushUri.giftGameBroadcast:
          gift =
              (HYSendItemNoticeGameBroadcastPacket()..readFrom(input)).toGift();
          break;
        default:
          return;
      }
      if (uri != HuyaPushUri.giftSubChannel && gift.itemCount <= 0) return;
      _acceptGift(gift, uri: uri, groupId: groupId, messageId: messageId);
    } catch (_) {
      _reportGiftIssue('decode:$uri', uri, msg.length);
    }
  }

  void _acceptGift(
    HYSendItemSubBroadcastPacket gift, {
    required int uri,
    required String groupId,
    required int messageId,
  }) {
    if (!_matchesGiftPresenter(gift)) return;
    if (gift.itemCount < 0 || _resolvedGiftCount(gift) <= 0) return;
    final resources = _readGiftResources(gift, uri);
    if (gift.itemType <= 0 &&
        (resources == null ||
            resources.propsId.isEmpty ||
            gift.propsName.trim().isEmpty)) {
      return;
    }
    // 广播缺少交易号，不能拿用户/名称猜测相同交易；只按可用的服务端 ID 去重。
    // 先登记真实数量，再等待目录。特效先到/后到都不能抵消交易明细。
    final receipt = _registerGiftTransaction(gift, messageId);
    if (receipt.isDuplicate) return;

    final pending = _PendingHuyaGift(
      gift: gift,
      resources: resources,
      replacesEventId: receipt.replacesEventId,
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
  }

  void _reportGiftIssue(String reason, int uri, int length) {
    // 仅记录协议号/原因/长度，既不输出原始 payload、用户名，也不输出签名 URL。
    if (_reportedGiftIssues.length >= 32 || !_reportedGiftIssues.add(reason)) {
      return;
    }
    CoreLog.w('虎牙礼物诊断 reason=$reason uri=$uri bytes=$length');
  }

  HYNonResourceItemEffect? _readGiftResources(
    HYSendItemSubBroadcastPacket gift,
    int uri,
  ) {
    for (final item in gift.bizData.take(32)) {
      if (item.type != 16 || item.data.isEmpty) continue;
      if (item.data.length > _maxGiftExtensionBytes) {
        _reportGiftIssue('extension-too-large:16', uri, item.data.length);
        continue;
      }
      try {
        return HYNonResourceItemEffect()..readFrom(TarsInputStream(item.data));
      } catch (_) {
        // 可选扩展损坏不能吞掉已经成功解码的送礼事实。
        _reportGiftIssue('extension-decode:16', uri, item.data.length);
      }
    }
    return null;
  }

  void _handleDrawingGift(
    List<int> payload, {
    required String groupId,
    required int messageId,
  }) {
    const uri = HuyaPushUri.giftOtherBroadcast;
    try {
      final packet = HYSendItemOtherBroadcastPacket()
        ..readFrom(TarsInputStream(Uint8List.fromList(payload)));
      if (packet.presenterUid != danmakuArgs.ayyuid) return;
      if (packet.items.length > 64) {
        _reportGiftIssue('drawing-too-many-items', uri, payload.length);
        return;
      }
      final counts = <int, int>{};
      for (final item in packet.items) {
        if (item.itemType <= 0 || item.itemCount <= 0) continue;
        final previous = counts[item.itemType] ?? 0;
        if (previous > 0x7fffffffffffffff - item.itemCount) {
          _reportGiftIssue('drawing-count-overflow', uri, payload.length);
          return;
        }
        counts[item.itemType] = previous + item.itemCount;
      }
      // 同一张绘图内同类道具合并，只用 vItemInfo 的数量，不计图案坐标。
      for (final item in counts.entries) {
        final gift = HYSendItemSubBroadcastPacket()
          ..itemType = item.key
          ..itemCount = item.value
          ..presenterUid = packet.presenterUid
          ..senderUid = packet.senderUid
          ..presenterNick = packet.presenterNick
          ..senderNick = packet.senderNick
          ..senderIcon = packet.senderAvatar
          ..payId = packet.payId;
        _acceptGift(gift, uri: uri, groupId: groupId, messageId: messageId);
      }
    } catch (_) {
      _reportGiftIssue('decode:$uri', uri, payload.length);
    }
  }

  void _handleActivityGift(
    List<int> payload, {
    required String groupId,
    required int messageId,
  }) {
    const uri = HuyaPushUri.giftActivityBroadcast;
    try {
      final packet = HYSendItemActivityNoticeBroadcastPacket()
        ..readFrom(TarsInputStream(Uint8List.fromList(payload)));
      if (packet.presenterUid != danmakuArgs.ayyuid || packet.senderUid <= 0) {
        return;
      }
      if (packet.effectId <= 0 && packet.effectUrl.isEmpty) return;
      if (messageId > 0 && _rememberGiftDuplicateKey('activity:$messageId')) {
        return;
      }
      final sender = packet.senderNick.trim().isNotEmpty
          ? packet.senderNick.trim()
          : 'UID ${packet.senderUid}';
      onMessage?.call(LiveMessage(
        type: LiveMessageType.gift,
        userName: sender,
        color: LiveMessageColor.white,
        message: '$sender 触发活动礼物特效',
        data: {
          'kind': 'giftActivityEffect',
          'uri': uri,
          'groupId': groupId,
          'messageId': messageId,
          'sender': sender,
          'senderUid': packet.senderUid,
          'presenterUid': packet.presenterUid,
          'giftName': '活动礼物特效',
          'giftId': 0,
          'effectId': packet.effectId,
          'effectFrames': packet.frames,
          'countKnown': false,
          'giftEffectUrls':
              normalizeHuyaGiftResourceCandidates([packet.effectUrl]),
          'isBigEffect': true,
        },
      ));
    } catch (_) {
      _reportGiftIssue('decode:$uri', uri, payload.length);
    }
  }

  void _handleGuardianNotice(
    List<int> payload, {
    required String groupId,
    required int messageId,
  }) {
    const uri = HuyaPushUri.guardianNotice;
    try {
      final notice = HYGuardianPresenterInfoNotice()
        ..readFrom(TarsInputStream(Uint8List.fromList(payload)));
      // NEW=0 / ENTER=1；进场、人数及状态刷新绝不能冒充开通。
      if (notice.presenterUid != danmakuArgs.ayyuid ||
          notice.guardianUid <= 0 ||
          notice.noticeType != HYGuardianPresenterInfoNotice.NEW ||
          notice.level <= 0 ||
          notice.openDays <= 0) {
        return;
      }
      if (messageId > 0 && _rememberGiftDuplicateKey('guardian:$messageId')) {
        return;
      }
      final sender = notice.guardianNick.trim().isNotEmpty
          ? notice.guardianNick.trim()
          : 'UID ${notice.guardianUid}';
      final name =
          notice.guardName.trim().isNotEmpty ? notice.guardName.trim() : '守护';
      // 官方播放器/公屏对旧等级非零的文案不同。保留 raw opType，
      // 未证实枚举之前只显示“更新”，不擅自断言续费/升级或换算月份。
      final action = notice.lastLevel == 0 ? '开通' : '更新';
      onMessage?.call(LiveMessage(
        type: LiveMessageType.gift,
        userName: sender,
        color: LiveMessageColor.white,
        message: '$sender $action$name V${notice.level} · ${notice.openDays}天',
        data: {
          'kind': 'guardianOpen',
          'uri': uri,
          'groupId': groupId,
          'messageId': messageId,
          'sender': sender,
          'senderUid': notice.guardianUid,
          'senderIcon': notice.guardianLogo,
          'presenterUid': notice.presenterUid,
          'giftName': name,
          'giftId': 0,
          'countKnown': false,
          'guardianLevel': notice.level,
          'guardianOpenDays': notice.openDays,
          'guardianLastLevel': notice.lastLevel,
          'guardianType': notice.guardType,
          'guardianNoticeType': notice.noticeType,
          'guardianOpType': notice.opType,
        },
      ));
    } catch (_) {
      _reportGiftIssue('decode:$uri', uri, payload.length);
    }
  }

  _HuyaGiftReceipt _registerGiftTransaction(
    HYSendItemSubBroadcastPacket gift,
    int messageId,
  ) {
    final paymentId = gift.payId.trim();
    final keys = _giftOrderKeys(paymentId, messageId).toList();
    final entry = _findGiftOrder(keys);
    final signature = '${gift.itemType}:${_resolvedGiftCount(gift)}';
    final duplicate = _rememberGiftDuplicateKeys([
          if (paymentId.isNotEmpty)
            'pay:$paymentId:${gift.itemGroup}:${gift.itemType}',
          if (messageId > 0) 'message:$messageId:${gift.itemType}',
        ]) ||
        (paymentId.isEmpty && entry.transactionItems.contains(signature));

    String? replacesEventId;
    if (!duplicate &&
        entry.effectEventId != null &&
        (entry.effectItemType <= 0 || entry.effectItemType == gift.itemType) &&
        (entry.effectCount == null ||
            entry.effectCount == _resolvedGiftCount(gift))) {
      replacesEventId = entry.effectEventId;
      // 一张整单特效卡只由第一项匹配明细接管，其余 itemGroup/道具独立保留。
      entry.effectEventId = null;
    }
    entry.hasTransactions = true;
    entry.transactionItems.add(signature);
    if (entry.transactionItems.length > 64) {
      entry.transactionItems.remove(entry.transactionItems.first);
    }
    // 命中重复也要记录新 mid 别名（6501 → 被抑制6541 → 6507）。
    _bindGiftOrder(keys, entry);
    return _HuyaGiftReceipt(duplicate, replacesEventId);
  }

  bool _rememberGiftDuplicateKeys(Iterable<String> keys) {
    var duplicate = false;
    for (final key in keys) {
      if (_rememberGiftDuplicateKey(key)) duplicate = true;
    }
    return duplicate;
  }

  bool _rememberGiftDuplicateKey(
    String key, {
    int ttlMs = _giftDuplicateTtlMs,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = _giftDuplicateCache[key];
    if (expiresAt != null && expiresAt > now) return true;
    if (expiresAt != null) {
      _giftDuplicateCache.remove(key);
    }

    _giftDuplicateCache[key] = now + ttlMs;
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

  Iterable<String> _giftOrderKeys(String paymentId, int messageId) sync* {
    // 支付号是不透明且区分大小写的 ID；只去空白，不能 lower-case 合并订单。
    if (paymentId.isNotEmpty) yield 'payment:$paymentId';
    if (messageId > 0) yield 'message:$messageId';
  }

  _HuyaGiftCrossKindEntry _findGiftOrder(List<String> keys) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _HuyaGiftCrossKindEntry? result;
    for (final key in keys) {
      final entry = _giftCrossKindDuplicateCache[key];
      if (entry == null) continue;
      if (entry.expiresAt <= now) {
        _giftCrossKindDuplicateCache.remove(key);
        continue;
      }
      final current = result;
      if (current == null) {
        result = entry;
      } else if (!identical(current, entry)) {
        // 一条迟到通知可能把已存在的 payment 与 mid 两棵别名关联起来。
        // 必须合并已知事实，并重定向旧别名；不能只选择第一项覆盖另一项。
        current.hasTransactions |= entry.hasTransactions;
        current.transactionItems.addAll(entry.transactionItems);
        while (current.transactionItems.length > 64) {
          current.transactionItems.remove(current.transactionItems.first);
        }
        if (current.effectEventId == null && entry.effectEventId != null) {
          current.effectEventId = entry.effectEventId;
          current.effectItemType = entry.effectItemType;
          current.effectCount = entry.effectCount;
        }
        if (entry.expiresAt > current.expiresAt) {
          current.expiresAt = entry.expiresAt;
        }
        for (final alias in _giftCrossKindDuplicateCache.keys.toList()) {
          if (identical(_giftCrossKindDuplicateCache[alias], entry)) {
            _giftCrossKindDuplicateCache[alias] = current;
          }
        }
      }
    }
    return result ?? _HuyaGiftCrossKindEntry(now + _giftDuplicateTtlMs);
  }

  void _bindGiftOrder(List<String> keys, _HuyaGiftCrossKindEntry entry) {
    for (final key in keys) {
      _giftCrossKindDuplicateCache[key] = entry;
    }
    if (_giftCrossKindDuplicateCache.length > _maxGiftDuplicateEntries) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _giftCrossKindDuplicateCache
          .removeWhere((_, entry) => entry.expiresAt <= now);
      while (_giftCrossKindDuplicateCache.length > _maxGiftDuplicateEntries) {
        _giftCrossKindDuplicateCache
            .remove(_giftCrossKindDuplicateCache.keys.first);
      }
    }
  }

  String? _registerGiftEffect(
      String paymentId, int messageId, int giftId, int? count) {
    final keys = _giftOrderKeys(paymentId, messageId).toList();
    final entry = _findGiftOrder(keys);
    final duplicate = _rememberGiftDuplicateKeys([
      if (paymentId.isNotEmpty) 'effect-payment:$paymentId',
      if (messageId > 0) 'effect-message:$messageId',
    ]);
    _bindGiftOrder(keys, entry);
    if (duplicate || entry.hasTransactions) return null;
    // 无强 ID 时不按用户/名称/金额/特效 ID 猜测合并。
    final eventId = 'huya-effect-${++_effectEventSequence}';
    entry.effectEventId = eventId;
    entry.effectItemType = giftId;
    entry.effectCount = count;
    return eventId;
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
    final resources = pending.resources;
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
          "kind": pending.uri == HuyaPushUri.giftSubChannel
              ? "giftTransaction"
              : pending.uri == HuyaPushUri.giftOtherBroadcast
                  ? "giftDrawing"
                  : "giftBroadcast",
          if (pending.replacesEventId != null)
            "replacesEventId": pending.replacesEventId,
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
          "giftImageUrls": normalizeHuyaGiftResourceCandidates([
            ...?resources?.imageCandidates,
            ...?catalogItem?.imageCandidates,
          ]),
          "giftEffectUrls": normalizeHuyaGiftResourceCandidates([
            ...?resources?.effectCandidates,
            ...?catalogItem?.effectCandidates,
          ]),
          if (resources != null) "resourcePropsId": resources.propsId,
          if (resources != null && resources.propsYb > 0)
            "resourceNominalTotalYb": resources.propsYb * count,
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
                  // type16 是 Tars 资源结构；即使字节恰好能解码为 UTF-8，
                  // 也不是用户文案。保留原始字节供兼容调用方使用。
                  "text":
                      item.type == 16 ? "" : _tryDecodeGiftBizText(item.data),
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

  int _effectGiftId(Map<String, String> params) {
    for (final entry in params.entries) {
      if (!const {'giftid', 'propsid', 'itemtype', 'iitemtype'}
          .contains(entry.key.toLowerCase())) {
        continue;
      }
      final id = int.tryParse(entry.value);
      if (id != null && id > 0) return id;
    }
    return 0;
  }

  String _effectPaymentId(Map<String, String> params) {
    const keys = <String>{
      "payid",
      "paymentid",
      "orderid",
      "transactionid",
      "billno",
      "payno",
    };
    for (final entry in params.entries) {
      if (!keys.contains(entry.key.trim().toLowerCase())) continue;
      final value = entry.value.trim();
      if (value.isNotEmpty) return value;
    }
    return "";
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
      if (effect.presenterUid != danmakuArgs.ayyuid ||
          effect.effectId <= 0 ||
          effect.customerUid <= 0) {
        return;
      }

      final giftId = _effectGiftId(effect.effectParams);
      int? count;
      for (final entry in effect.effectParams.entries) {
        if (!const {'count', 'itemcount', 'iitemcount'}
            .contains(entry.key.toLowerCase())) {
          continue;
        }
        final value = int.tryParse(entry.value);
        if (value != null && value > 0) {
          count = value;
          break;
        }
      }
      final catalogItem = giftId > 0 ? _giftCatalog[giftId] : null;
      final sender = effect.customerNick.trim().isNotEmpty
          ? effect.customerNick.trim()
          : effect.customerUid > 0
              ? "UID ${effect.customerUid}"
              : "虎牙用户";
      final itemName =
          effect.itemName.trim().isNotEmpty ? effect.itemName.trim() : "高价值礼物";
      final payTotal = _effectParamInt(effect.effectParams);
      final paymentId = _effectPaymentId(effect.effectParams);
      final eventId = _registerGiftEffect(paymentId, messageId, giftId, count);
      if (eventId == null) return;

      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.gift,
          data: {
            "kind": "giftEffectNotice",
            "eventId": eventId,
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
            "giftId": giftId,
            "giftImageUrls": catalogItem?.imageCandidates ?? const <String>[],
            "count": count ?? 1,
            "itemCount": count,
            "countKnown": count != null,
            "payTotal": payTotal,
            if (paymentId.isNotEmpty) "payId": paymentId,
            "isBigEffect": true,
            "effectParams": effect.effectParams,
            "giftEffectUrls": [
              ...?catalogItem?.effectCandidates,
              for (final entry in effect.effectParams.entries)
                if (const {
                  'iconurl',
                  'animationurl',
                  'resourceurl',
                  'webresourceurl',
                  'giftimageurl'
                }.contains(entry.key.toLowerCase()))
                  entry.value,
            ],
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
  final HYNonResourceItemEffect? resources;
  final String? replacesEventId;
  final int uri;
  final String groupId;
  final int messageId;

  const _PendingHuyaGift({
    required this.gift,
    this.resources,
    this.replacesEventId,
    required this.uri,
    required this.groupId,
    required this.messageId,
  });
}

/// 强标识只关联同一订单，不能把订单内所有明细当作重复。
class _HuyaGiftCrossKindEntry {
  int expiresAt;
  bool hasTransactions = false;
  final Set<String> transactionItems = <String>{};
  String? effectEventId;
  int effectItemType = 0;
  int? effectCount;

  _HuyaGiftCrossKindEntry(this.expiresAt);
}

class _HuyaGiftReceipt {
  final bool isDuplicate;
  final String? replacesEventId;

  const _HuyaGiftReceipt(this.isDuplicate, this.replacesEventId);
}
