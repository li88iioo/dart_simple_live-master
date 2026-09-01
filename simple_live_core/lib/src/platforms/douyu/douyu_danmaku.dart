import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/web_socket_util.dart';

import '../../common/binary_writer.dart';

class DouyuDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 45 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;
  String serverUrl = "wss://danmuproxy.douyu.com:8506";

  WebScoketUtils? webScoketUtils;

  @override
  Future start(dynamic args) async {
    webScoketUtils = WebScoketUtils(
      url: serverUrl,
      heartBeatTime: heartbeatTime,
      readTimeout: const Duration(seconds: 150),
      onMessage: (e) {
        decodeMessage(e);
      },
      onReady: () {
        onReady?.call();
        joinRoom(args);
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

  void joinRoom(String roomId) {
    webScoketUtils
        ?.sendMessage(serializeDouyu("type@=loginreq/roomid@=$roomId/"));
    webScoketUtils?.sendMessage(
        serializeDouyu("type@=joingroup/rid@=$roomId/gid@=-9999/"));
  }

  @override
  void heartbeat() {
    var data = serializeDouyu("type@=mrkl/");
    webScoketUtils?.sendMessage(data);
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    webScoketUtils?.close();
  }

  void decodeMessage(List<int> data) {
    for (final packet in deserializeDouyuPackets(data)) {
      _decodeLogicalMessage(packet);
    }
  }

  void _decodeLogicalMessage(String result) {
    try {
      final jsonData = sttToJObject(result);
      if (jsonData is! Map) return;

      var type = jsonData["type"]?.toString();
      var fans = jsonData["if"]?.toString() ?? '0';
      // 斗鱼好像不会返回人气值。
      // 有些直播间存在异常弹幕，沿用原逻辑仅显示粉丝发言。
      LiveMessage? liveMsg;
      if (type == "chatmsg" && fans == '1') {
        var col = int.tryParse(jsonData["col"].toString()) ?? 0;
        liveMsg = LiveMessage(
          type: LiveMessageType.chat,
          userName: jsonData["nn"].toString(),
          message: jsonData["txt"].toString(),
          color: getColor(col),
        );
      } else if (type == "comm_chatmsg") {
        DateTime curTimestamp = DateTime.fromMillisecondsSinceEpoch(
          int.parse(jsonData["now"]),
        );
        var face = "";
        try {
          // 疑似换接口了
          face = jsonData["chatmsg"]["ic"];
        } catch (e) {
          CoreLog.error("DouyuSuperChat-face:$e");
        }
        LiveSuperChatMessage sc = LiveSuperChatMessage(
          // 斗鱼没有颜色，调整配色方案为偏紫色系。
          backgroundBottomColor: "#292a60",
          backgroundColor: "#c1c1ff",
          endTime:
              curTimestamp.add(Duration(seconds: int.parse(jsonData["cet"]))),
          face: "https://apic.douyucdn.cn/upload/${face}_small.jpg",
          message: jsonData["chatmsg"]["txt"].toString(),
          price: int.parse(jsonData["cprice"]) ~/ 100,
          startTime: curTimestamp,
          userName: jsonData["chatmsg"]["nn"].toString(),
        );
        liveMsg = LiveMessage(
          type: LiveMessageType.superChat,
          userName: "SUPER_CHAT_MESSAGE",
          message: "SUPER_CHAT_MESSAGE",
          color: LiveMessageColor.white,
          data: sc,
        );
      } else if (type == "voice_trlt") {
        // 高能弹幕2
        var scData = jsonData["list"][0];
        LiveSuperChatMessage sc2 = LiveSuperChatMessage(
          backgroundBottomColor: "#246488",
          backgroundColor: "#ffffff",
          endTime: DateTime.fromMillisecondsSinceEpoch(
            int.parse(scData["etime"]) * 1000,
          ),
          face: "https://${scData["uat"][1]}",
          message: scData["content"].toString(),
          price: int.parse(scData["realPrice"]) ~/ 100,
          startTime: DateTime.fromMillisecondsSinceEpoch(
            int.parse(scData["acptime"]) * 1000,
          ),
          userName: scData["un"].toString(),
        );
        liveMsg = LiveMessage(
          type: LiveMessageType.superChat,
          userName: "SUPER_CHAT_MESSAGE",
          message: "SUPER_CHAT_MESSAGE",
          color: LiveMessageColor.white,
          data: sc2,
        );
      }
      if (liveMsg != null) {
        onMessage?.call(liveMsg);
      }
    } catch (e) {
      CoreLog.error("Douyu logical packet 解析失败: $e");
    }
  }

  List<int> serializeDouyu(String body) {
    try {
      const int clientSendToServer = 689;
      const int encrypted = 0;
      const int reserved = 0;

      List<int> buffer = utf8.encode(body);

      var writer = BinaryWriter([]);
      writer.writeInt(4 + 4 + buffer.length + 1, 4, endian: Endian.little);
      writer.writeInt(4 + 4 + buffer.length + 1, 4, endian: Endian.little);
      writer.writeInt(clientSendToServer, 2, endian: Endian.little);
      writer.writeInt(encrypted, 1, endian: Endian.little);
      writer.writeInt(reserved, 1, endian: Endian.little);
      writer.writeBytes(buffer);
      writer.writeInt(0, 1, endian: Endian.little);
      return writer.buffer;
    } catch (e) {
      CoreLog.error(e);
      return [];
    }
  }

  String? deserializeDouyu(List<int> buffer) {
    final packets = deserializeDouyuPackets(buffer);
    return packets.isEmpty ? null : packets.first;
  }

  List<String> deserializeDouyuPackets(List<int> buffer) {
    const minimumPacketLength = 13;
    final data = Uint8List.fromList(buffer);
    final packets = <String>[];
    var offset = 0;

    while (offset < data.length) {
      final remaining = data.length - offset;
      if (remaining < minimumPacketLength) {
        CoreLog.w('Douyu frame 尾部不足一个完整包: remaining=$remaining');
        break;
      }

      final header = ByteData.sublistView(data, offset, offset + 12);
      final fullMessageLength = header.getUint32(0, Endian.little);
      final repeatedLength = header.getUint32(4, Endian.little);
      if (fullMessageLength != repeatedLength || fullMessageLength < 9) {
        CoreLog.w(
          'Douyu 包长度非法: first=$fullMessageLength, '
          'second=$repeatedLength',
        );
        break;
      }

      final packetLength = fullMessageLength + 4;
      if (packetLength > remaining) {
        CoreLog.w(
          'Douyu 包被截断: packet=$packetLength, remaining=$remaining',
        );
        break;
      }

      final bodyLength = fullMessageLength - 9;
      final bodyStart = offset + 12;
      final packetEnd = offset + packetLength;
      if (data[packetEnd - 1] != 0) {
        CoreLog.w('Douyu 包缺少结尾的 NUL 字节');
        break;
      }

      try {
        packets.add(
          utf8.decode(
            Uint8List.sublistView(data, bodyStart, bodyStart + bodyLength),
          ),
        );
      } on FormatException catch (e) {
        CoreLog.w('Douyu 包正文不是有效 UTF-8: $e');
      }
      offset = packetEnd;
    }

    return packets;
  }

  //辣鸡STT
  dynamic sttToJObject(String str) {
    if (str.contains("//")) {
      var result = [];
      for (var field in str.split("//")) {
        if (field.isEmpty) {
          continue;
        }
        result.add(sttToJObject(field));
      }
      return result;
    }
    if (str.contains("@=")) {
      var result = {};
      for (var field in str.split('/')) {
        if (field.isEmpty) {
          continue;
        }
        var tokens = field.split("@=");
        var k = tokens[0];
        var v = unscapeSlashAt(tokens[1]);
        result[k] = sttToJObject(v);
      }
      return result;
    } else if (str.contains("@A=")) {
      return sttToJObject(unscapeSlashAt(str));
    } else {
      return unscapeSlashAt(str);
    }
  }

  String unscapeSlashAt(String str) {
    return str.replaceAll("@S", "/").replaceAll("@A", "@");
  }

  LiveMessageColor getColor(int type) {
    switch (type) {
      case 1:
        return LiveMessageColor(255, 0, 0);
      case 2:
        return LiveMessageColor(30, 135, 240);
      case 3:
        return LiveMessageColor(122, 200, 75);
      case 4:
        return LiveMessageColor(255, 127, 0);
      case 5:
        return LiveMessageColor(155, 57, 244);
      case 6:
        return LiveMessageColor(255, 105, 180);
      default:
        return LiveMessageColor.white;
    }
  }
}
