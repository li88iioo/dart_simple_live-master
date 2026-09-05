import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/model/tars/huya_danmaku.dart';
import 'package:simple_live_core/src/platforms/huya/huya_hysignal.dart';
import 'package:simple_live_core/src/platforms/huya/huya_tars_utils.dart';
import 'package:tars_dart/tars/codec/tars_decode_exception.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';
import 'package:test/test.dart';

const _presenter = 2272316519;
const _sender = 5000000001;
const _liveGroup = 'live:$_presenter';

void main() {
  setUp(() => CoreLog.enableLog = false);
  tearDown(() => CoreLog.enableLog = true);

  group('Huya gift signed readers', () {
    for (final value in [-128, -1, 0, 127, 128, 255]) {
      test('6501 全部整数保留 wire 值 $value，不误判正数 SHORT', () {
        final tags = _giftIntegers(HYSendItemSubBroadcastPacket()).keys;
        final expected = {for (final tag in tags) tag: value};
        final packet = HYSendItemSubBroadcastPacket()
          ..readFrom(TarsInputStream(_wire(expected)));
        expect(_giftIntegers(packet), expected);
      });
    }

    test('6501 缺少 payType 时保持 -1，显式 ZERO_TAG 保持 0', () {
      for (final tail in [false, true]) {
        final packet = HYSendItemSubBroadcastPacket()
          ..readFrom(TarsInputStream(_wire({0: 4, 3: _presenter}, tail: tail)));
        expect(packet.payType, -1);
      }
      final packet = HYSendItemSubBroadcastPacket()
        ..readFrom(TarsInputStream(_wire({27: 0})));
      expect(packet.payType, 0);
      // reader 对象复用也不能把上次支付类型当成协议默认值。
      packet.readFrom(TarsInputStream(_wire({0: 4})));
      expect(packet.payType, -1);
    });

    test('signed helper 仅在 optional 缺失时应用默认值', () {
      expect(
        readHuyaSignedInt(TarsInputStream(Uint8List(0)), 27, false,
            defaultValue: -1),
        -1,
      );
      expect(
        readHuyaSignedInt(TarsInputStream(_wire({28: 1})), 27, false,
            defaultValue: -1),
        -1,
      );
      expect(
        readHuyaSignedInt(TarsInputStream(_wire({27: 0})), 27, false,
            defaultValue: -1),
        0,
      );
      expect(
        () => readHuyaSignedInt(TarsInputStream(_wire({28: 1})), 27, true,
            defaultValue: -1),
        throwsA(isA<TarsDecodeException>()),
      );
    });

    test('6501 Int64 UID、交易序号及支付总额不截为 32 位', () {
      final expected = <int, int>{
        3: _presenter,
        4: _sender,
        24: 5000000002,
        25: _presenter,
        39: 9007199254740993,
        41: 5000000003,
      };
      final packet = HYSendItemSubBroadcastPacket()
        ..readFrom(TarsInputStream(_wire(expected)));
      final actual = _giftIntegers(packet);
      for (final entry in expected.entries) {
        expect(actual[entry.key], entry.value, reason: 'tag ${entry.key}');
      }
    });

    test('6501 嵌套效果字段和业务类型也恢复 signed BYTE', () {
      final effect = HYItemEffectInfo()
        ..readFrom(TarsInputStream(_wire({0: -1, 1: -128, 2: -1, 3: -1})));
      expect(
        [
          effect.priceLevel,
          effect.streamDuration,
          effect.showType,
          effect.streamId
        ],
        [-1, -128, -1, -1],
      );
      final biz = HYItemEffectBizData()
        ..readFrom(TarsInputStream(_wire({0: -1, 1: Uint8List(0)})));
      expect(biz.type, -1);
    });

    test('6541 关键字段只检查存在，全部整数字段按真实宽度保留符号', () {
      for (final value in [-128, -1, 0, 127, 128, 255, _sender]) {
        final effect = HYLiveRoomLargeConsumptionEffectNotice()
          ..readFrom(
              TarsInputStream(_wire({0: value, 1: value, 2: value, 5: value})));
        expect(
          [
            effect.presenterUid,
            effect.effectId,
            effect.customerUid,
            effect.recipientUid
          ],
          [value, value, value, value],
        );
      }
    });

    for (final tag in [0, 1, 2]) {
      test('6541 缺少关键 tag $tag 时拒绝解码', () {
        final fields = <int, Object>{0: _presenter, 1: 70001, 2: _sender}
          ..remove(tag);
        expect(
          () => HYLiveRoomLargeConsumptionEffectNotice()
            ..readFrom(TarsInputStream(_wire(fields))),
          throwsA(isA<TarsDecodeException>()),
        );
      });
      test('6541 关键 tag $tag 类型错误时拒绝解码', () {
        final fields = <int, Object>{0: _presenter, 1: 70001, 2: _sender}
          ..[tag] = 'not-an-integer';
        expect(
          () => HYLiveRoomLargeConsumptionEffectNotice()
            ..readFrom(TarsInputStream(_wire(fields))),
          throwsA(isA<TarsDecodeException>()),
        );
      });
    }
  });

  group('Huya gift integrity', () {
    test('R1 6501 负数量不能变为 255，也不能兜底成一次交易', () {
      final messages = <LiveMessage>[];
      _decoder(messages)
          .decodeMessage(_push(6501, _gift(count: -1, byGroup: 0)));
      expect(messages, isEmpty);
    });

    test('R1b 6501 负道具 ID 不能变为正数礼物', () {
      final messages = <LiveMessage>[];
      _decoder(messages).decodeMessage(_push(6501, _gift(item: -1)));
      expect(messages, isEmpty);
    });

    for (final uri in [6502, 6507]) {
      for (final transactionFirst in [true, false]) {
        test('R2 相同 mid 的 6501/$uri 只输出一次，transactionFirst=$transactionFirst',
            () {
          final messages = <LiveMessage>[];
          final decoder = _decoder(messages);
          final transaction = _push(6501, _gift(count: 3), mid: 901);
          final broadcast = _push(uri, _broadcast(count: 3), mid: 901);
          decoder.decodeMessage(transactionFirst ? transaction : broadcast);
          decoder.decodeMessage(transactionFirst ? broadcast : transaction);
          // 同 mid 的交易/广播是同一事实，不需要 effect replacement 回调。
          expect(messages, hasLength(1));
          expect(_data(messages.single)['count'], 3);
        });
      }
    }

    test('R3 先到的整单特效不能吞掉同支付号不同分组，真实数量 2+3=5', () {
      final messages = <LiveMessage>[];
      final decoder = _decoder(messages);
      decoder.decodeMessage(_push(6541, _effect(), mid: 10));
      decoder.decodeMessage(_push(6501, _gift(count: 2, group: 1), mid: 11));
      decoder.decodeMessage(_push(6501, _gift(count: 3, group: 2), mid: 12));
      final transactions = _logicalEvents(messages)
          .where((message) => _data(message)['kind'] == 'giftTransaction')
          .toList();
      expect(transactions, hasLength(2));
      expect(
          transactions.map((message) => _data(message)['itemGroup']), [1, 2]);
      expect(transactions.map((message) => _data(message)['count']), [2, 3]);
      expect(_count(transactions), 5);
    });

    for (final effectFirst in [true, false]) {
      test('精确 6541/6514 明细可以升级替换，但不得丢真实绘图，effectFirst=$effectFirst', () {
        final messages = <LiveMessage>[];
        final decoder = _decoder(messages);
        final drawing = _push(6514, _drawing(), mid: 61);
        final effect = _push(6541, _effect(item: 4, count: 5), mid: 62);
        decoder.decodeMessage(effectFirst ? effect : drawing);
        decoder.decodeMessage(effectFirst ? drawing : effect);
        final logical = _logicalEvents(messages);
        expect(logical, hasLength(2));
        final byItem = {
          for (final message in logical)
            _data(message)['giftId']: _data(message)
        };
        expect(byItem[4]?['count'], 5);
        expect(byItem[9]?['count'], 6);
        expect(byItem[4]?['kind'], 'giftDrawing');
        expect(byItem[9]?['kind'], 'giftDrawing');
        expect(_count(logical), 11);
      });
    }

    test('R4 无 mid 但支付号不同的同款 6541 不能被误合并', () {
      final messages = <LiveMessage>[];
      final decoder = _decoder(messages);
      decoder.decodeMessage(_push(6541, _effect(payment: 'P1'), mid: 0));
      decoder.decodeMessage(_push(6541, _effect(payment: 'P2'), mid: 0));
      expect(messages, hasLength(2));
      expect(messages.map((message) => _data(message)['payId']), ['P1', 'P2']);
    });

    test('R4b 同支付号相同 6541 的不同 mid 重传只输出一次', () {
      final messages = <LiveMessage>[];
      final decoder = _decoder(messages);
      decoder.decodeMessage(_push(6541, _effect(), mid: 101));
      decoder.decodeMessage(_push(6541, _effect(), mid: 102));
      expect(messages, hasLength(1));
    });

    for (final uri in [6501, 6541]) {
      test('无强 ID 的 $uri 即使 wire 相同也不按名称/用户/时间猜测合并', () {
        final messages = <LiveMessage>[];
        final decoder = _decoder(messages);
        final payload = uri == 6501 ? _gift(payment: '') : _effect(payment: '');
        final push = _push(uri, payload, mid: 0);
        decoder.decodeMessage(push);
        decoder.decodeMessage(push);
        expect(messages, hasLength(2));
        expect(_logicalEvents(messages), hasLength(2));
      });
    }

    test('没有共同强 ID 的交易和特效不靠相同内容合并', () {
      final messages = <LiveMessage>[];
      final decoder = _decoder(messages);
      decoder.decodeMessage(_push(6501, _gift(count: 3), mid: 21));
      decoder.decodeMessage(
          _push(6541, _effect(payment: '', item: 4, count: 3), mid: 22));
      expect(messages, hasLength(2));
      expect(_logicalEvents(messages), hasLength(2));
    });

    test('仅有不同 mid 的同款 6541 保留两次，相同 mid 重传仍去重', () {
      final messages = <LiveMessage>[];
      final decoder = _decoder(messages);
      final payload = _effect(payment: '');
      decoder.decodeMessage(_push(6541, payload, mid: 960));
      decoder.decodeMessage(_push(6541, payload, mid: 960));
      decoder.decodeMessage(_push(6541, payload, mid: 961));
      expect(messages, hasLength(2));
    });

    test('R5 仅含当前主播的 6541 不能虚构大额礼物', () {
      final messages = <LiveMessage>[];
      _decoder(messages).decodeMessage(_push(6541, _wire({0: _presenter})));
      expect(messages, isEmpty);
    });

    for (final value in [-1, 0]) {
      test('6541 handler 拒绝非正 effectId=$value', () {
        final messages = <LiveMessage>[];
        _decoder(messages).decodeMessage(_push(6541, _effect(effectId: value)));
        expect(messages, isEmpty);
      });
      test('6541 handler 拒绝非正 customerUid=$value', () {
        final messages = <LiveMessage>[];
        _decoder(messages)
            .decodeMessage(_push(6541, _effect(customerUid: value)));
        expect(messages, isEmpty);
      });
    }

    test('R6 V2 单项畸形不能吞掉后续合法礼物', () {
      final messages = <LiveMessage>[];
      final packet = HYWSPushMessageV2()
        ..groupId = _liveGroup
        ..items = [
          HYWSMsgItem()
            ..uri = 1400
            ..message = Uint8List.fromList([0x06, 0x01, 0x78])
            ..messageId = 100,
          HYWSMsgItem()
            ..uri = 6501
            ..message = _gift()
            ..messageId = 101,
        ];
      _decoder(messages).decodeMessage(_command(22, _encode(packet)));
      expect(messages, hasLength(1));
      expect(_data(messages.single)['count'], 1);
    });

    test('R10 被去重的特效仍须将新 mid 关联到已知支付号', () {
      final messages = <LiveMessage>[];
      final decoder = _decoder(messages);
      decoder.decodeMessage(_push(6501, _gift(count: 3), mid: 11));
      decoder.decodeMessage(_push(6541, _effect(item: 4, count: 3), mid: 22));
      decoder.decodeMessage(_push(6507, _broadcast(count: 3), mid: 22));
      expect(messages, hasLength(1));
      expect(_data(messages.single)['count'], 3);
    });
  });

  test('R10b 支付号与 mid 桥接已有两个 entry 时不能丢已登记的交易明细', () {
    final messages = <LiveMessage>[];
    final decoder = _decoder(messages);
    // 起初没有共同强 ID，不能猜测它们相同：mid11 是真实交易，P/mid22 是特效。
    decoder.decodeMessage(_push(6507, _broadcast(count: 3), mid: 11));
    decoder.decodeMessage(_push(6541, _effect(), mid: 22));
    // 这一条才证明两组别名属于同一订单；即使自身被去重，也必须合并历史事实。
    decoder.decodeMessage(_push(6541, _effect(), mid: 11));
    decoder.decodeMessage(_push(6507, _broadcast(count: 3), mid: 22));
    final real = _logicalEvents(messages)
        .where((message) => _data(message)['kind'] == 'giftBroadcast')
        .toList();
    expect(real, hasLength(1));
    expect(_count(real), 3);
  });

  group('Huya gift lifecycle', () {
    test('R3b 等待目录的先到交易不能被特效抢占，数量保持 9', () async {
      final room = await _openRoom();
      room.decoder.decodeMessage(_push(6501, _gift(count: 9), mid: 70));
      room.decoder.decodeMessage(_push(6541, _effect(), mid: 71));
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      final logical = _logicalEvents(room.messages);
      expect(logical, hasLength(1));
      expect(_data(logical.single)['kind'], 'giftTransaction');
      expect(_data(logical.single)['count'], 9);
    });

    test('R9 重连 ACK 延迟不能取消已接收礼物的原目录兜底期限', () async {
      final room = await _openRoom();
      room.decoder.decodeMessage(_push(6501, _gift(count: 7), mid: 90));
      expect(room.messages, isEmpty);
      room.server.acknowledge = false;
      await room.server.sockets.first.close();
      await _waitUntil(() => room.server.registrations >= 2);
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      expect(room.messages, hasLength(1));
      expect(_data(room.messages.single)['count'], 7);
    });

    test('C1 正常重连后相同支付号、不同 mid 的回放不重复', () async {
      final room = await _openRoom();
      room.decoder.decodeMessage(_push(6501, _gift(), mid: 31));
      await _waitUntil(() => room.messages.isNotEmpty);
      await room.server.sockets.first.close();
      await _waitUntil(() => room.readyCount == 2);
      room.decoder.decodeMessage(_push(6501, _gift(), mid: 32));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(room.messages, hasLength(1));
    });

    test('R7 重复 start 后 stop 不得遗留旧 WebSocket', () async {
      final room = await _openRoom();
      final firstClient = room.decoder.webScoketUtils;
      // 即使主线尚未修复，也由测试显式关闭遗留客户端，避免重连 timer 泄漏。
      addTearDown(() => firstClient?.close());
      await room.decoder.start(_args());
      await _waitUntil(() => room.readyCount == 2);
      await room.decoder.stop();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(room.server.activeConnections, 0);
    });
  });

  // 当前实现直接使用 DateTime.now；fake_async 不能推进它，且本子任务不改主线/依赖。
  // 四种组合共用一次真实等待，常规测试默认跳过；设置环境变量即可完整运行。
  test(
    'R8 精确支付号或 mid 的跨类型关联在 15 秒后仍有效',
    () async {
      final cases = <({
        String name,
        HuyaDanmaku decoder,
        List<LiveMessage> messages,
        Uint8List delayed
      })>[];
      for (final paymentKey in [true, false]) {
        for (final transactionFirst in [true, false]) {
          final messages = <LiveMessage>[];
          final decoder = _decoder(messages);
          final payment = paymentKey ? 'P' : '';
          final transaction =
              _push(6501, _gift(payment: payment, count: 3), mid: 81);
          final effect = _push(
              6541, _effect(payment: payment, item: 4, count: 3),
              mid: paymentKey ? 82 : 81);
          decoder.decodeMessage(transactionFirst ? transaction : effect);
          cases.add((
            name: 'payment=$paymentKey transactionFirst=$transactionFirst',
            decoder: decoder,
            messages: messages,
            delayed: transactionFirst ? effect : transaction,
          ));
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 15200));
      for (final entry in cases) {
        entry.decoder.decodeMessage(entry.delayed);
      }
      // effect-first 允许两次 callback，但 replacement 后只能有一个逻辑事件。
      for (final entry in cases) {
        final logical = _logicalEvents(entry.messages);
        expect(logical, hasLength(1), reason: entry.name);
        expect(_data(logical.single)['giftId'], 4, reason: entry.name);
        expect(_count(logical), 3, reason: entry.name);
      }
    },
    timeout: const Timeout(Duration(seconds: 25)),
    skip: Platform.environment['HUYA_RUN_SLOW_TESTS'] != '1'
        ? '设置 HUYA_RUN_SLOW_TESTS=1 运行单项真实 15.2 秒 TTL 回归'
        : false,
  );
}

HuyaDanmakuArgs _args() => HuyaDanmakuArgs(
      ayyuid: _presenter,
      topSid: 12345,
      subSid: 67890,
    );

HuyaDanmaku _decoder(List<LiveMessage> messages) => HuyaDanmaku()
  ..danmakuArgs = _args()
  ..onMessage = messages.add;

Map<dynamic, dynamic> _data(LiveMessage message) => message.data as Map;

/// 仅消费明确的替换关系，不拿用户、名称、数量或时间猜测逻辑身份。
List<LiveMessage> _logicalEvents(List<LiveMessage> callbacks) {
  final active = <LiveMessage>[];
  final seenIds = <Object>{};
  for (final message in callbacks) {
    final data = _data(message);
    final replacement = data['replacesEventId'];
    if (replacement != null && replacement != '') {
      expect(seenIds, contains(replacement),
          reason: 'replacement 必须指向已发出的 eventId');
      active.removeWhere((old) => _data(old)['eventId'] == replacement);
    }
    active.add(message);
    final eventId = data['eventId'];
    if (eventId != null && eventId != '') seenIds.add(eventId as Object);
  }
  return active;
}

int _count(Iterable<LiveMessage> messages) => messages.fold(0, (sum, message) {
      final data = _data(message);
      expect(data['countKnown'], isNot(false), reason: '未知数量不能参与真实数量累计');
      return sum + (data['count'] as int);
    });

/// 按外部协议的 tag 编码，不用待测 gift/effect 模型的 writeTo 自证。
Uint8List _wire(Map<int, Object> fields, {bool tail = true}) {
  final output = TarsOutputStream();
  final tags = fields.keys.toList()..sort();
  for (final tag in tags) {
    output.write(fields[tag], tag);
  }
  // 合法未知尾字段避免 vendored reader 对正常 optional EOF 打印冗余诊断。
  if (tail) output.writeInt(0, 250);
  return output.toUint8List();
}

Uint8List _gift({
  String payment = 'P',
  int count = 1,
  int group = 0,
  int item = 4,
  int? byGroup,
}) =>
    _wire({
      0: item,
      1: payment,
      2: count,
      3: _presenter,
      4: _sender,
      5: '测试主播',
      6: '测试用户',
      8: byGroup ?? count,
      9: group,
      20: '测试礼物',
    });

Uint8List _broadcast({int count = 1}) => _wire({
      0: 4,
      1: count,
      3: _sender,
      4: '测试用户',
      5: _presenter,
      6: '测试主播',
    });

Uint8List _effect({
  String payment = 'P',
  int? item,
  int? count,
  int effectId = 70001,
  int customerUid = _sender,
}) =>
    _wire({
      0: _presenter,
      1: effectId,
      2: customerUid,
      3: '测试用户',
      8: '测试礼物',
      9: <String, String>{
        if (payment.isNotEmpty) 'PAYID': payment,
        if (item != null) 'giftId': '$item',
        if (count != null) 'count': '$count',
      },
    });

Uint8List _drawing() => _wire({
      0: _sender,
      1: _presenter,
      4: 'P',
      5: '测试用户',
      6: '测试主播',
      8: [
        _WireItem(4, 3),
        _WireItem(4, 2),
        _WireItem(9, 6),
      ],
    });

Uint8List _encode(TarsStruct value) {
  final output = TarsOutputStream();
  value.writeTo(output);
  return output.toUint8List();
}

Uint8List _command(int type, Uint8List payload) =>
    _wire({0: type, 1: payload}, tail: false);

Uint8List _push(int uri, Uint8List payload, {int mid = 1}) => _command(
      HuyaHySignalCommandType.pushMessage,
      _encode(HYPushMessage()
        ..uri = uri
        ..msg = payload
        ..groupId = _liveGroup
        ..messageId = mid),
    );

Map<int, int> _giftIntegers(HYSendItemSubBroadcastPacket gift) => {
      0: gift.itemType,
      2: gift.itemCount,
      3: gift.presenterUid,
      4: gift.senderUid,
      8: gift.itemCountByGroup,
      9: gift.itemGroup,
      10: gift.superPurpleLevel,
      11: gift.comboScore,
      12: gift.displayInfo,
      13: gift.effectType,
      16: gift.templateType,
      19: gift.colorEffectType,
      21: gift.accept,
      22: gift.eventType,
      24: gift.roomId,
      25: gift.homeOwnerUid,
      27: gift.payType,
      28: gift.nobleLevel,
      32: gift.comboStatus,
      33: gift.pidColorType,
      34: gift.multiSend,
      35: gift.vFanLevel,
      36: gift.upgradeLevel,
      39: gift.comboSeqId,
      41: gift.payTotal,
    };

class _WireItem extends TarsStruct {
  _WireItem(this.id, this.count);
  final int id;
  final int count;

  @override
  void writeTo(TarsOutputStream output) {
    output.writeInt(id, 0);
    output.writeInt(count, 1);
  }

  @override
  void readFrom(TarsInputStream input) => throw UnsupportedError('仅用于独立编码');
  @override
  Object deepCopy() => _WireItem(id, count);
  @override
  void displayAsString(StringBuffer sb, int level) {}
}

Future<void> _waitUntil(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('本地 WebSocket 条件未满足');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<_LocalRoom> _openRoom() async {
  final server =
      _LocalServer(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
  final room = _LocalRoom(server);
  addTearDown(() async {
    await room.decoder.stop();
    await server.close();
  });
  await room.decoder.start(_args());
  await _waitUntil(() => room.readyCount == 1);
  return room;
}

class _LocalRoom {
  _LocalRoom(this.server) {
    decoder = HuyaDanmaku(
      registerAckTimeout: const Duration(seconds: 5),
      socketReconnectInterval: const Duration(milliseconds: 15),
    )
      ..serverUrl = server.url
      ..onMessage = messages.add
      ..onReady = () => readyCount++;
  }
  final _LocalServer server;
  final messages = <LiveMessage>[];
  late final HuyaDanmaku decoder;
  int readyCount = 0;
}

class _LocalServer {
  _LocalServer(this.server) {
    subscription = server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      activeConnections++;
      socket.listen((raw) {
        if (raw is! List<int>) return;
        final input = TarsInputStream(Uint8List.fromList(raw));
        if (input.readInt(0, false) !=
            HuyaHySignalCommandType.registerGroupRequest) {
          return;
        }
        registrations++;
        if (!acknowledge) return;
        socket.add(_command(
          HuyaHySignalCommandType.registerGroupResponse,
          _wire({0: 0, 1: <String>[]}, tail: false),
        ));
        // 故意不响应礼物目录，用于验证 1.2s 兜底及重连时序。
      }, onDone: () => activeConnections--);
    });
  }
  final HttpServer server;
  late final StreamSubscription<HttpRequest> subscription;
  final sockets = <WebSocket>[];
  bool acknowledge = true;
  int registrations = 0;
  int activeConnections = 0;
  String get url => 'ws://${server.address.address}:${server.port}';

  Future<void> close() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await subscription.cancel();
    await server.close(force: true);
  }
}
