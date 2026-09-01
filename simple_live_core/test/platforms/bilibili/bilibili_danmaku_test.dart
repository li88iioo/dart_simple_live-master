import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

List<int> _packet(
  List<int> body, {
  int protocolVersion = 0,
  int operation = 5,
}) {
  final result = Uint8List(16 + body.length);
  ByteData.sublistView(result, 0, 16)
    ..setUint32(0, result.length, Endian.big)
    ..setUint16(4, 16, Endian.big)
    ..setUint16(6, protocolVersion, Endian.big)
    ..setUint32(8, operation, Endian.big)
    ..setUint32(12, 1, Endian.big);
  result.setRange(16, result.length, body);
  return result;
}

List<int> _chatPacket(String userName, String message) {
  return _packet(
    utf8.encode(
      json.encode({
        'cmd': 'DANMU_MSG',
        'info': [
          [0, 0, 0, 0],
          message,
          [0, userName],
        ],
      }),
    ),
  );
}

void main() {
  final originalLogState = CoreLog.enableLog;

  setUpAll(() {
    CoreLog.enableLog = false;
  });

  tearDownAll(() {
    CoreLog.enableLog = originalLogState;
  });

  test('一个 WebSocket frame 中的多个逻辑包都会被解析', () {
    final messages = <LiveMessage>[];
    final danmaku = BiliBiliDanmaku()..onMessage = messages.add;
    final frame = <int>[
      ..._chatPacket('用户A', '第一条'),
      ..._chatPacket('用户B', '第二条'),
    ];

    danmaku.decodeMessage(frame);

    expect(messages.map((item) => item.userName), ['用户A', '用户B']);
    expect(messages.map((item) => item.message), ['第一条', '第二条']);
  });

  test('压缩包解压后按嵌套逻辑包逐条解析', () {
    final messages = <LiveMessage>[];
    final danmaku = BiliBiliDanmaku()..onMessage = messages.add;
    final nested = <int>[
      ..._chatPacket('用户A', '压缩一'),
      ..._chatPacket('用户B', '压缩二'),
    ];
    final frame = _packet(
      zlib.encode(nested),
      protocolVersion: 2,
    );

    danmaku.decodeMessage(frame);

    expect(messages.map((item) => item.message), ['压缩一', '压缩二']);
  });

  test('畸形长度不会越界，且不会吞掉此前已完成的逻辑包', () {
    final messages = <LiveMessage>[];
    final danmaku = BiliBiliDanmaku()..onMessage = messages.add;
    final malformed = Uint8List.fromList(_chatPacket('坏包', '不应出现'));
    ByteData.sublistView(malformed, 0, 4).setUint32(
      0,
      malformed.length + 100,
      Endian.big,
    );

    expect(
      () => danmaku.decodeMessage([
        ..._chatPacket('正常包', '应保留'),
        ...malformed,
      ]),
      returnsNormally,
    );
    expect(messages.map((item) => item.message), ['应保留']);
  });
}
