import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:brotli/brotli.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/convert_helper.dart';
import 'package:simple_live_core/src/common/web_socket_util.dart';

import '../../common/binary_writer.dart';

class BiliBiliDanmakuArgs {
  final int roomId;
  final String token;
  final String buvid;
  final String serverHost;
  final int uid;
  final String cookie;
  BiliBiliDanmakuArgs({
    required this.roomId,
    required this.token,
    required this.serverHost,
    required this.buvid,
    required this.uid,
    required this.cookie,
  });
  @override
  String toString() {
    return json.encode({
      "roomId": roomId,
      "token": token,
      "serverHost": serverHost,
      "buvid": buvid,
      "uid": uid,
      "cookie": cookie,
    });
  }
}

class BiliBiliDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 60 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  //String serverUrl = "wss://broadcastlv.chat.bilibili.com/sub";

  WebScoketUtils? webScoketUtils;
  late BiliBiliDanmakuArgs danmakuArgs;
  @override
  Future start(dynamic args) async {
    danmakuArgs = args as BiliBiliDanmakuArgs;
    webScoketUtils = WebScoketUtils(
      url: "wss://${args.serverHost}/sub",
      heartBeatTime: heartbeatTime,
      readTimeout: const Duration(seconds: 150),
      headers: args.cookie.isEmpty
          ? null
          : {
              "cookie": args.cookie,
            },
      onMessage: (e) {
        decodeMessage(e);
      },
      onReady: () {
        onReady?.call();
        joinRoom(danmakuArgs);
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

  void joinRoom(BiliBiliDanmakuArgs args) {
    var joinData = encodeData(
      json.encode({
        "uid": args.uid,
        "roomid": args.roomId,
        "protover": 3,
        "buvid": args.buvid,
        "platform": "web",
        "type": 2,
        "key": args.token,
      }),
      7,
    );
    webScoketUtils?.sendMessage(joinData);
  }

  @override
  void heartbeat() {
    webScoketUtils?.sendMessage(encodeData(
      "",
      2,
    ));
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    webScoketUtils?.close();
  }

  List<int> encodeData(String msg, int action) {
    var data = utf8.encode(msg);
    //头部长度固定16
    var length = data.length + 16;
    var buffer = Uint8List(length);

    var writer = BinaryWriter([]);

    //数据包长度
    writer.writeInt(buffer.length, 4);
    //数据包头部长度,固定16
    writer.writeInt(16, 2);

    //协议版本，0=JSON,1=Int32,2=Buffer
    writer.writeInt(0, 2);

    //操作类型
    writer.writeInt(action, 4);

    //数据包头部长度,固定1

    writer.writeInt(1, 4);

    writer.writeBytes(data);

    return writer.buffer;
  }

  static const int _packetHeaderLength = 16;
  static const int _maxPacketNesting = 8;
  static const int _maxDecodedFrameLength = 32 * 1024 * 1024;

  void decodeMessage(List<int> data) {
    try {
      if (data.length > _maxDecodedFrameLength) {
        throw const FormatException('Bilibili WebSocket frame 过大');
      }
      _decodePackets(Uint8List.fromList(data), depth: 0);
    } catch (e) {
      CoreLog.error('Bilibili WebSocket frame 解析失败: $e');
    }
  }

  void _decodePackets(Uint8List data, {required int depth}) {
    if (depth > _maxPacketNesting) {
      throw const FormatException('Bilibili 压缩包嵌套层级过深');
    }

    var offset = 0;
    while (offset < data.length) {
      final remaining = data.length - offset;
      if (remaining < _packetHeaderLength) {
        throw FormatException('Bilibili 包头不完整: remaining=$remaining');
      }

      final header = ByteData.sublistView(
        data,
        offset,
        offset + _packetHeaderLength,
      );
      final packetLength = header.getUint32(0, Endian.big);
      final headerLength = header.getUint16(4, Endian.big);
      final protocolVersion = header.getUint16(6, Endian.big);
      final operation = header.getUint32(8, Endian.big);

      if (headerLength < _packetHeaderLength ||
          packetLength < headerLength ||
          packetLength > remaining) {
        throw FormatException(
          'Bilibili 包长度非法: packet=$packetLength, '
          'header=$headerLength, remaining=$remaining',
        );
      }

      final bodyStart = offset + headerLength;
      final packetEnd = offset + packetLength;
      final body = Uint8List.sublistView(data, bodyStart, packetEnd);
      _decodePacket(
        body,
        protocolVersion: protocolVersion,
        operation: operation,
        depth: depth,
      );
      offset = packetEnd;
    }
  }

  void _decodePacket(
    Uint8List body, {
    required int protocolVersion,
    required int operation,
    required int depth,
  }) {
    if (operation == 3) {
      if (body.length < 4) {
        throw const FormatException('Bilibili 人气包长度不足 4 字节');
      }
      final online = ByteData.sublistView(body, 0, 4).getUint32(0, Endian.big);
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.online,
          data: online,
          color: LiveMessageColor.white,
          message: '',
          userName: '',
        ),
      );
      return;
    }

    if (operation != 5) return;

    switch (protocolVersion) {
      case 0:
      case 1:
        if (body.isEmpty) return;
        parseMessage(utf8.decode(body, allowMalformed: true));
        return;
      case 2:
        _decodeCompressedPackets(zlib.decode(body), depth: depth + 1);
        return;
      case 3:
        _decodeCompressedPackets(brotli.decode(body), depth: depth + 1);
        return;
      default:
        CoreLog.w('忽略未知 Bilibili 协议版本: $protocolVersion');
    }
  }

  void _decodeCompressedPackets(List<int> decoded, {required int depth}) {
    if (decoded.length > _maxDecodedFrameLength) {
      throw const FormatException('Bilibili 解压后 frame 过大');
    }
    _decodePackets(Uint8List.fromList(decoded), depth: depth);
  }

  void parseMessage(String jsonMessage) {
    try {
      var obj = json.decode(jsonMessage);
      var cmd = obj["cmd"].toString();
      if (cmd.contains("DANMU_MSG")) {
        if (obj["info"] != null && obj["info"].length != 0) {
          var message = obj["info"][1].toString();
          var color = asT<int?>(obj["info"][0][3]) ?? 0;
          if (obj["info"][2] != null && obj["info"][2].length != 0) {
            var username = obj["info"][2][1].toString();
            var liveMsg = LiveMessage(
              type: LiveMessageType.chat,
              userName: username,
              message: message,
              color: color == 0
                  ? LiveMessageColor.white
                  : LiveMessageColor.numberToColor(color),
            );
            onMessage?.call(liveMsg);
          }
        }
      } else if (cmd == "SUPER_CHAT_MESSAGE") {
        if (obj["data"] == null) {
          return;
        }
        LiveSuperChatMessage sc = LiveSuperChatMessage(
          backgroundBottomColor:
              obj["data"]["background_bottom_color"].toString(),
          backgroundColor: obj["data"]["background_color"].toString(),
          endTime: DateTime.fromMillisecondsSinceEpoch(
            obj["data"]["end_time"] * 1000,
          ),
          face: "${obj["data"]["user_info"]["face"]}@200w.jpg",
          message: obj["data"]["message"].toString(),
          price: obj["data"]["price"],
          startTime: DateTime.fromMillisecondsSinceEpoch(
            obj["data"]["start_time"] * 1000,
          ),
          userName: obj["data"]["user_info"]["uname"].toString(),
        );
        var liveMsg = LiveMessage(
          type: LiveMessageType.superChat,
          userName: "SUPER_CHAT_MESSAGE",
          message: "SUPER_CHAT_MESSAGE",
          color: LiveMessageColor.white,
          data: sc,
        );
        onMessage?.call(liveMsg);
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }

  int readInt(List<int> buffer, int start, int len) {
    if (start < 0 || len <= 0 || start + len > buffer.length) {
      throw RangeError.range(start + len, 0, buffer.length, 'end');
    }
    final bytes = Uint8List.fromList(buffer);
    final data = ByteData.sublistView(bytes, start, start + len);
    switch (len) {
      case 1:
        return data.getUint8(0);
      case 2:
        return data.getUint16(0, Endian.big);
      case 4:
        return data.getUint32(0, Endian.big);
      case 8:
        return data.getUint64(0, Endian.big);
      default:
        throw ArgumentError.value(len, 'len', '只支持 1/2/4/8 字节整数');
    }
  }
}
