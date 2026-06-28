import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/web_socket_util.dart';
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
        getJoinData(danmakuArgs.ayyuid, danmakuArgs.topSid, danmakuArgs.topSid);
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
      if (type == 7) {
        stream = TarsInputStream(stream.readBytes(1, false));
        HYPushMessage wSPushMessage = HYPushMessage();
        wSPushMessage.readFrom(stream);
        if (wSPushMessage.uri == 1400) {
          HYMessage messageNotice = HYMessage();
          messageNotice
              .readFrom(TarsInputStream(Uint8List.fromList(wSPushMessage.msg)));
          var uname = messageNotice.userInfo.nickName;
          var content = messageNotice.content;

          var color = messageNotice.bulletFormat.fontColor;

          onMessage?.call(
            LiveMessage(
              type: LiveMessageType.chat,
              color: color <= 0
                  ? LiveMessageColor.white
                  : LiveMessageColor.numberToColor(color),
              message: content,
              userName: uname,
            ),
          );
        } else if (wSPushMessage.uri == 8006) {
          int online = 0;
          var s = TarsInputStream(Uint8List.fromList(wSPushMessage.msg));
          online = s.read(online, 0, false);
          onMessage?.call(
            LiveMessage(
              type: LiveMessageType.online,
              data: online,
              color: LiveMessageColor.white,
              message: "",
              userName: "",
            ),
          );
        } else if (wSPushMessage.uri == 1020001) {
          // 礼物通知 (Tars 结构体)
          try {
            HYGiftNotice giftNotice = HYGiftNotice();
            giftNotice.readFrom(
                TarsInputStream(Uint8List.fromList(wSPushMessage.msg)));
            var giftName = giftNotice.sGiftName;
            var sender = giftNotice.sSenderNick;
            var count = giftNotice.iGiftCount;
            if (count <= 0) count = 1;
            onMessage?.call(
              LiveMessage(
                type: LiveMessageType.gift,
                data: {
                  "sender": sender,
                  "giftName": giftName,
                  "count": count,
                  "price": giftNotice.iPrice,
                },
                color: LiveMessageColor.white,
                message: giftName.isNotEmpty
                    ? "🎁 $sender 送出 $giftName x$count"
                    : "🎁 $sender 送出礼物 x$count",
                userName: sender,
              ),
            );
          } catch (e) {
            CoreLog.error('解析礼物消息(1020001)失败: $e');
          }
        } else if (wSPushMessage.uri == 6291) {
          // 礼物详情 (Tars Map 格式)
          try {
            var giftData =
                _parseGiftKvMap(Uint8List.fromList(wSPushMessage.msg));
            if (giftData != null) {
              var sender = giftData["sender"] ?? "";
              var giftName = giftData["giftName"] ?? "";
              var count = giftData["count"] ?? 1;
              onMessage?.call(
                LiveMessage(
                  type: LiveMessageType.gift,
                  data: giftData,
                  color: LiveMessageColor.white,
                  message: giftName.isNotEmpty
                      ? "🎁 $sender 送出 $giftName x$count"
                      : "🎁 $sender 送出礼物 x$count",
                  userName: sender,
                ),
              );
            }
          } catch (e) {
            CoreLog.error('解析礼物消息(6291)失败: $e');
          }
        } else if (wSPushMessage.uri == 1010 || wSPushMessage.uri == 1020) {
          // 贵宾进场
          try {
            HYVipEnterNotice vipNotice = HYVipEnterNotice();
            vipNotice.readFrom(
                TarsInputStream(Uint8List.fromList(wSPushMessage.msg)));
            var nickName = vipNotice.sNickName;
            onMessage?.call(
              LiveMessage(
                type: LiveMessageType.vipEnter,
                data: nickName,
                color: LiveMessageColor.white,
                message: "⭐ $nickName 进入直播间",
                userName: nickName,
              ),
            );
          } catch (e) {
            CoreLog.error('解析贵宾进场消息失败: $e');
          }
        }
      }
    } catch (e) {
      CoreLog.error(e);
    }
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
    } catch (e) {
      return null;
    }
  }
}
