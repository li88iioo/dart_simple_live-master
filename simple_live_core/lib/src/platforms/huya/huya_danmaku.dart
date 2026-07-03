import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/web_socket_util.dart';
import 'package:simple_live_core/src/platforms/huya/huya_hysignal.dart';
import 'package:simple_live_core/src/model/tars/huya_danmaku.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';

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
    return json.encode({
      "ayyuid": ayyuid,
      "topSid": topSid,
      "subSid": subSid,
    });
  }
}

class HuyaDanmaku implements LiveDanmaku {
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

  final heartbeatData = base64.decode("ABQdAAwsNgBM");

  late HuyaDanmakuArgs danmakuArgs;

  final Set<String> _giftCache = {};

  bool _isDuplicateGift(
    String sender,
    String giftName,
    int count, {
    String id = "",
  }) {
    if (sender.isEmpty || giftName.isEmpty) return false;
    final key = id.isNotEmpty ? id : "$sender-$giftName-$count";
    if (_giftCache.contains(key)) {
      return true;
    }
    _giftCache.add(key);
    Future.delayed(const Duration(seconds: 3), () {
      _giftCache.remove(key);
    });
    return false;
  }

  @override
  Future start(dynamic args) async {
    danmakuArgs = args as HuyaDanmakuArgs;
    webScoketUtils = WebScoketUtils(
      url: serverUrl,
      heartBeatTime: heartbeatTime,
      onMessage: (e) {
        decodeMessage(e);
      },
      onReady: () {
        onReady?.call();
        joinRoom();
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        onClose?.call("服务器连接失败$e");
      },
    );
    webScoketUtils?.connect();
  }

  void joinRoom() {
    var joinData =
        getJoinData(danmakuArgs.ayyuid, danmakuArgs.topSid, danmakuArgs.subSid);
    webScoketUtils?.sendMessage(joinData);
  }

  List<int> getJoinData(int ayyuid, int tid, int sid) {
    try {
      var oos = TarsOutputStream();
      oos.write(ayyuid, 0);
      oos.write(true, 1);
      oos.write("", 2);
      oos.write("", 3);
      oos.write(tid, 4);
      oos.write(sid, 5);
      oos.write(0, 6);
      oos.write(0, 7);

      var wscmd = TarsOutputStream();
      wscmd.write(1, 0);
      wscmd.write(oos.toUint8List(), 1);
      return wscmd.toUint8List();
    } catch (e) {
      CoreLog.error(e);
      return [];
    }
  }

  @override
  void heartbeat() {
    webScoketUtils?.sendMessage(heartbeatData);
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    webScoketUtils?.close();
  }

  void decodeMessage(List<int> data) {
    try {
      var stream = TarsInputStream(Uint8List.fromList(data));
      var type = stream.read(0, 0, false);
      var payload = stream.readBytes(1, false);

      if (type == HuyaHySignalCommandType.pushMessage) {
        var pushMessage = HYPushMessage();
        pushMessage.readFrom(TarsInputStream(payload));
        _handlePushMessage(pushMessage.uri, pushMessage.msg);
      } else if (type == HuyaHySignalCommandType.pushMessageV2) {
        var pushMessageV2 = HYWSPushMessageV2();
        pushMessageV2.readFrom(TarsInputStream(payload));
        for (var item in pushMessageV2.items) {
          if (item.uri == 0 || item.message.isEmpty) continue;
          _handlePushMessage(item.uri, item.message);
        }
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }

  void _handlePushMessage(int uri, List<int> msg) {
    if (uri == 1400) {
      _handleChatMessage(msg);
    } else if (uri == HuyaPushUri.attendeeCount) {
      _handleOnlineCount(msg);
    } else if (uri == 1020001) {
      _handleLegacyGift(msg);
    } else if (uri == 6291) {
      _handleLegacyGiftMap(msg);
    } else if (_isHySignalGiftUri(uri)) {
      _handleHySignalGift(uri, msg);
    } else if (uri == HuyaPushUri.bigGiftEffect) {
      _handleGiftEffect(uri, msg);
    } else if (uri == 1010 || uri == 1020) {
      _handleLegacyVipEnter(msg);
    } else if (uri == HuyaPushUri.vipBarList) {
      _handleVipBarList(uri, msg);
    } else if (uri == HuyaPushUri.vipBarCount) {
      _handleVipBarCount(uri, msg);
    } else if (uri == HuyaPushUri.vipBarSimpleList) {
      _handleVipBarSimpleList(uri, msg);
    }
  }

  bool _isHySignalGiftUri(int uri) {
    return uri == HuyaPushUri.giftSubChannel ||
        uri == HuyaPushUri.giftTopChannel ||
        uri == HuyaPushUri.giftGameBroadcast ||
        uri == HuyaPushUri.giftOtherBroadcast;
  }

  void _handleChatMessage(List<int> msg) {
    var messageNotice = HYMessage();
    messageNotice.readFrom(TarsInputStream(Uint8List.fromList(msg)));
    var color = messageNotice.bulletFormat.fontColor;
    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.chat,
        color: color <= 0
            ? LiveMessageColor.white
            : LiveMessageColor.numberToColor(color),
        message: messageNotice.content,
        userName: messageNotice.userInfo.nickName,
      ),
    );
  }

  void _handleOnlineCount(List<int> msg) {
    var online = 0;
    try {
      var notice = HYAttendeeCountNotice();
      notice.readFrom(TarsInputStream(Uint8List.fromList(msg)));
      online = notice.attendeeCount;
    } catch (_) {
      var stream = TarsInputStream(Uint8List.fromList(msg));
      online = stream.read(online, 0, false);
    }
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

  void _handleLegacyGift(List<int> msg) {
    try {
      var giftNotice = HYGiftNotice();
      giftNotice.readFrom(TarsInputStream(Uint8List.fromList(msg)));
      var giftName = giftNotice.sGiftName;
      var sender = giftNotice.sSenderNick;
      var count = giftNotice.iGiftCount;
      if (count <= 0) count = 1;
      if (_isDuplicateGift(sender, giftName, count)) {
        return;
      }
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.gift,
          data: {
            "kind": "legacyGift",
            "sender": sender,
            "giftName": giftName,
            "count": count,
            "price": giftNotice.iPrice,
          },
          color: LiveMessageColor.white,
          message: _giftMessage(sender, giftName, count, giftNotice.iPrice),
          userName: sender,
        ),
      );
    } catch (e) {
      CoreLog.error('解析礼物消息(1020001)失败: $e');
    }
  }

  void _handleLegacyGiftMap(List<int> msg) {
    try {
      var giftData = _parseGiftKvMap(Uint8List.fromList(msg));
      if (giftData == null) return;
      var sender = giftData["sender"]?.toString() ?? "";
      var giftName = giftData["giftName"]?.toString() ?? "";
      var count = _readIntValue(giftData["count"], defaultValue: 1);
      if (_isDuplicateGift(sender, giftName, count)) {
        return;
      }
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.gift,
          data: {
            "kind": "legacyGiftMap",
            ...giftData,
          },
          color: LiveMessageColor.white,
          message: _giftMessage(sender, giftName, count, 0),
          userName: sender,
        ),
      );
    } catch (e) {
      CoreLog.error('解析礼物消息(6291)失败: $e');
    }
  }

  void _handleHySignalGift(int uri, List<int> msg) {
    try {
      var gift = HYSendItemSubBroadcastPacket();
      gift.readFrom(TarsInputStream(Uint8List.fromList(msg)));
      var giftName = gift.propsName.isNotEmpty
          ? gift.propsName
          : gift.sendContent.isNotEmpty
              ? gift.sendContent
              : "礼物${gift.itemType}";
      var sender = gift.senderNick;
      var count = gift.itemCount > 0 ? gift.itemCount : gift.itemCountByGroup;
      if (count <= 0) count = 1;
      var duplicateId = gift.payId.isNotEmpty
          ? gift.payId
          : "$uri-${gift.senderUid}-${gift.itemType}-${gift.comboSeqId}-${gift.payTotal}-$count";
      if (_isDuplicateGift(sender, giftName, count, id: duplicateId)) {
        return;
      }
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.gift,
          data: {
            "kind": "hySignalGift",
            "uri": uri,
            "sender": sender,
            "senderUid": gift.senderUid,
            "presenter": gift.presenterNick,
            "presenterUid": gift.presenterUid,
            "giftName": giftName,
            "giftId": gift.itemType,
            "count": count,
            "itemCount": gift.itemCount,
            "itemCountByGroup": gift.itemCountByGroup,
            "payId": gift.payId,
            "payTotal": gift.payTotal,
            "effectType": gift.effectType,
            "comboScore": gift.comboScore,
            "comboSeqId": gift.comboSeqId,
            "effect": {
              "priceLevel": gift.effectInfo.priceLevel,
              "streamDuration": gift.effectInfo.streamDuration,
              "showType": gift.effectInfo.showType,
              "streamId": gift.effectInfo.streamId,
              "showAsStream": gift.effectInfo.showAsStream,
              "showAsBigEffect": gift.effectInfo.showAsBigEffect,
            },
            "diyEffect": {
              "resourceUrl": gift.diyEffect.resourceUrl,
              "resourceAttr": gift.diyEffect.resourceAttr,
              "webResourceUrl": gift.diyEffect.webResourceUrl,
              "pcResourceUrl": gift.diyEffect.pcResourceUrl,
            },
          },
          color: LiveMessageColor.white,
          message: _giftMessage(sender, giftName, count, gift.payTotal),
          userName: sender,
        ),
      );
    } catch (e) {
      CoreLog.error('解析礼物消息($uri)失败: $e');
    }
  }

  void _handleGiftEffect(int uri, List<int> msg) {
    try {
      var effect = HYLiveRoomLargeConsumptionEffectNotice();
      effect.readFrom(TarsInputStream(Uint8List.fromList(msg)));
      var sender = effect.customerNick;
      var itemName = effect.itemName.isNotEmpty ? effect.itemName : "礼物";
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.gift,
          data: {
            "kind": "hySignalGiftEffect",
            "uri": uri,
            "effectId": effect.effectId,
            "presenterUid": effect.presenterUid,
            "customerUid": effect.customerUid,
            "customerNick": effect.customerNick,
            "customerAvatar": effect.customerAvatar,
            "recipientUid": effect.recipientUid,
            "recipientNick": effect.recipientNick,
            "recipientAvatar": effect.recipientAvatar,
            "itemName": effect.itemName,
            "effectParams": effect.effectParams,
          },
          color: LiveMessageColor.white,
          message: "✨ $sender 触发 $itemName 特效",
          userName: sender,
        ),
      );
    } catch (e) {
      CoreLog.error('解析礼物特效消息($uri)失败: $e');
    }
  }

  void _handleLegacyVipEnter(List<int> msg) {
    try {
      var vipNotice = HYVipEnterNotice();
      vipNotice.readFrom(TarsInputStream(Uint8List.fromList(msg)));
      var nickName = vipNotice.sNickName;
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.vipEnter,
          data: {
            "kind": "vipEnter",
            "nickName": nickName,
            "badgeType": vipNotice.iBadgeType,
          },
          color: LiveMessageColor.white,
          message: "⭐ $nickName 进入直播间",
          userName: nickName,
        ),
      );
    } catch (e) {
      CoreLog.error('解析贵宾进场消息失败: $e');
    }
  }

  void _handleVipBarList(int uri, List<int> msg) {
    try {
      var rsp = HYVipBarListRsp();
      rsp.readFrom(TarsInputStream(Uint8List.fromList(msg)));
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.vipEnter,
          data: {
            "kind": "vipList",
            "uri": uri,
            "count": rsp.displayTotal,
            "items": rsp.items.map((e) => e.toJson()).toList(),
          },
          color: LiveMessageColor.white,
          message: "",
          userName: "",
        ),
      );
    } catch (e) {
      CoreLog.error('解析贵宾列表消息($uri)失败: $e');
    }
  }

  void _handleVipBarCount(int uri, List<int> msg) {
    try {
      var stat = HYVipBarListStatInfo();
      stat.readFrom(TarsInputStream(Uint8List.fromList(msg)));
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.vipEnter,
          data: {
            "kind": "vipCount",
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
      CoreLog.error('解析贵宾数量消息($uri)失败: $e');
    }
  }

  void _handleVipBarSimpleList(int uri, List<int> msg) {
    try {
      var rsp = HYGetVipBarSimpleListRsp();
      rsp.readFrom(TarsInputStream(Uint8List.fromList(msg)));
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.vipEnter,
          data: {
            "kind": "vipSimpleList",
            "uri": uri,
            "count": rsp.totalNum,
            "items": rsp.items.map((e) => e.toJson()).toList(),
          },
          color: LiveMessageColor.white,
          message: "",
          userName: "",
        ),
      );
    } catch (e) {
      CoreLog.error('解析贵宾简表消息($uri)失败: $e');
    }
  }

  String _giftMessage(String sender, String giftName, int count, int value) {
    var name = giftName.isNotEmpty ? giftName : "礼物";
    var message = "🎁 $sender 送出 $name x$count";
    if (value > 0) {
      message = "$message 价值$value";
    }
    return message;
  }

  int _readIntValue(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// 解析礼物 KV Map (iUri=6291)
  /// 格式: 01 02 XX 18 00 count [06 key_len key 16 val_len val]...
  Map<String, dynamic>? _parseGiftKvMap(Uint8List data) {
    try {
      var result = <String, String>{};
      var pos = 0;

      // 跳过头部: 01 02 XX 18 00
      if (data.length > 6 && data[0] == 0x01 && data[1] == 0x02) {
        bool found = false;
        for (var i = 2; i < data.length && i < 10; i++) {
          if (data[i] == 0x18 && i + 1 < data.length && data[i + 1] == 0x00) {
            pos = i + 2;
            found = true;
            break;
          }
        }
        if (!found) return null;
      } else {
        return null;
      }

      // 读取 count
      if (pos >= data.length) return null;
      var count = data[pos];
      pos++;

      // 解析 key-value 对
      for (var i = 0; i < count; i++) {
        if (pos >= data.length) break;
        var keyType = data[pos];
        pos++;
        if (keyType != 0x06) break;
        if (pos >= data.length) break;
        var keyLen = data[pos];
        pos++;
        if (pos + keyLen > data.length) break;
        var key = String.fromCharCodes(data.sublist(pos, pos + keyLen));
        pos += keyLen;

        if (pos >= data.length) break;
        var valType = data[pos];
        pos++;
        if (valType == 0x16) {
          // string value
          if (pos >= data.length) break;
          var valLen = data[pos];
          pos++;
          if (pos + valLen > data.length) break;
          var val = String.fromCharCodes(data.sublist(pos, pos + valLen));
          pos += valLen;
          result[key] = val;
        } else if (valType == 0x02) {
          // int32 value
          if (pos + 4 > data.length) break;
          var bd = ByteData.sublistView(data, pos, pos + 4);
          var val = bd.getInt32(0, Endian.big);
          pos += 4;
          result[key] = val.toString();
        } else {
          break;
        }
      }

      // 只有包含礼物信息的才返回
      if (result.containsKey("skname") ||
          (result.containsKey("ct") && result.containsKey("mt"))) {
        return {
          "sender": result["ct"] ?? "",
          "presenter": result["mt"] ?? "",
          "count": int.tryParse(result["num"] ?? "1") ?? 1,
          "giftName": result["skname"] ?? "",
          "orderId": result["oid"] ?? "",
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
