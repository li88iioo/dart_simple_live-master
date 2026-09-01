import 'dart:typed_data';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

String _chat(String userName, String message) {
  return 'type@=chatmsg/if@=1/nn@=$userName/txt@=$message/col@=0/';
}

void main() {
  final originalLogState = CoreLog.enableLog;

  setUpAll(() {
    CoreLog.enableLog = false;
  });

  tearDownAll(() {
    CoreLog.enableLog = originalLogState;
  });

  test('一个 WebSocket frame 中的多个斗鱼逻辑包都会被解析', () {
    final messages = <LiveMessage>[];
    final danmaku = DouyuDanmaku()..onMessage = messages.add;
    final frame = <int>[
      ...danmaku.serializeDouyu(_chat('用户A', '第一条')),
      ...danmaku.serializeDouyu(_chat('用户B', '第二条')),
    ];

    danmaku.decodeMessage(frame);

    expect(messages.map((item) => item.userName), ['用户A', '用户B']);
    expect(messages.map((item) => item.message), ['第一条', '第二条']);
  });

  test('序列化长度按 UTF-8 字节数计算，中文正文可完整往返', () {
    final danmaku = DouyuDanmaku();
    final source = _chat('中文用户', '中文弹幕');

    final packets = danmaku.deserializeDouyuPackets(
      danmaku.serializeDouyu(source),
    );

    expect(packets, [source]);
  });

  test('双长度字段不一致时停止坏包，但保留此前完整包', () {
    final messages = <LiveMessage>[];
    final danmaku = DouyuDanmaku()..onMessage = messages.add;
    final malformed = Uint8List.fromList(
      danmaku.serializeDouyu(_chat('坏包', '不应出现')),
    );
    final secondLength = ByteData.sublistView(malformed, 4, 8);
    secondLength.setUint32(
      0,
      secondLength.getUint32(0, Endian.little) + 1,
      Endian.little,
    );

    expect(
      () => danmaku.decodeMessage([
        ...danmaku.serializeDouyu(_chat('正常包', '应保留')),
        ...malformed,
      ]),
      returnsNormally,
    );
    expect(messages.map((item) => item.message), ['应保留']);
  });

  test('被截断的 frame 不会造成越界异常', () {
    final danmaku = DouyuDanmaku();
    expect(() => danmaku.decodeMessage([1, 2, 3]), returnsNormally);
  });
}
