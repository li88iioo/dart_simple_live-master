import 'dart:typed_data';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/model/tars/huya_danmaku.dart';
import 'package:simple_live_core/src/platforms/huya/huya_gift_catalog.dart';
import 'package:simple_live_core/src/platforms/huya/huya_gift_broadcast.dart';
import 'package:simple_live_core/src/platforms/huya/huya_hysignal.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';
import 'package:tars_dart/tars/tup/const.dart';
import 'package:tars_dart/tars/tup/tars_uni_packet.dart';
import 'package:test/test.dart';

const _pid = 2272316519;
const _uid = 5000000001;

void main() {
  setUp(() => CoreLog.enableLog = false);
  tearDown(() => CoreLog.enableLog = true);

  test('6514 按真实多项绘图布局解析，保留 Int64 数量，不以路径坐标计算', () {
    final payload = _drawing();
    final packet = HYSendItemOtherBroadcastPacket()
      ..readFrom(TarsInputStream(payload));
    expect(packet.senderUid, _uid);
    expect(packet.items.last.itemCount, 2147483648);
    final messages = <LiveMessage>[];
    final danmaku = _danmaku(messages);
    _catalog(danmaku);
    for (var i = 0; i < 2; i++) {
      _push(danmaku, 6514, payload, messageId: 6514001 + i);
    }
    expect(messages, hasLength(2)); // 同支付交易重传，各道具仍恰好一次。
    final first = messages.first.data as Map;
    final second = messages.last.data as Map;
    expect(first['kind'], 'giftDrawing');
    expect(first['giftId'], 4);
    expect(first['count'], 5); // 3 + 2，同一种道具合并。
    expect(first['giftName'], '测试道具 A');
    expect(second['giftId'], 9);
    expect(second['count'], 2147483648);
    expect(second['giftName'], '测试道具 B');
    expect(first['messageId'], second['messageId']);
  });

  test('6514 多项数量 Int64 溢出时拒绝整个包，不虚构数量', () {
    final messages = <LiveMessage>[];
    final payload = (TarsOutputStream()
          ..writeInt(_uid, 0)
          ..writeInt(_pid, 1)
          ..writeString('overflow', 4)
          ..write(
              [_IndependentItem(4, 0x7fffffffffffffff), _IndependentItem(4, 1)],
              8))
        .toUint8List();
    _push(_danmaku(messages), 6514, payload);
    expect(messages, isEmpty);
  });

  for (final sharedPayment in [true, false]) {
    test('先到的整单 6541 不吞掉 6514 多道具（sharedPayment=$sharedPayment）', () {
      final messages = <LiveMessage>[];
      final danmaku = _danmaku(messages);
      final effect = HYLiveRoomLargeConsumptionEffectNotice()
        ..presenterUid = _pid
        ..customerUid = _uid
        ..customerNick = '绘图用户'
        ..effectId = 70001
        ..itemName = '绘图特效'
        ..effectParams = {if (sharedPayment) 'PAYID': 'drawing-payment'};
      final out = TarsOutputStream();
      effect.writeTo(out);
      _push(danmaku, 6541, out.toUint8List(), messageId: 70);
      _push(danmaku, 6514, _drawing(), messageId: sharedPayment ? 71 : 70);
      expect(messages, hasLength(3));
      expect(messages.skip(1).map((m) => (m.data as Map)['giftId']), [4, 9]);
    });
  }

  test('真实绘图明细原位接管精确匹配的特效卡片，不丢未覆盖项', () {
    final messages = <LiveMessage>[];
    final danmaku = _danmaku(messages);
    final effect = HYLiveRoomLargeConsumptionEffectNotice()
      ..presenterUid = _pid
      ..customerUid = _uid
      ..customerNick = '绘图用户'
      ..effectId = 70001
      ..itemName = 'A特效'
      ..effectParams = {
        'PAYID': 'drawing-payment',
        'giftId': '4',
        'count': '5'
      };
    final out = TarsOutputStream();
    effect.writeTo(out);
    _push(danmaku, 6541, out.toUint8List(), messageId: 70);
    _push(danmaku, 6514, _drawing(), messageId: 71);
    expect(messages, hasLength(3));
    final replacement = messages[1].data as Map;
    expect(replacement['replacesEventId'],
        (messages.first.data as Map)['eventId']);
    expect(replacement['giftId'], 4);
    expect(replacement['count'], 5);
    expect((messages.last.data as Map)['replacesEventId'], isNull);
    expect((messages.last.data as Map)['giftId'], 9);
  });

  test('6514 接收者不匹配时整个绘图不进入当前房间', () {
    final messages = <LiveMessage>[];
    _push(_danmaku(messages), 6514, _drawing(presenter: 9, sender: _pid));
    expect(messages, isEmpty);
  });

  test('6508 是活动特效，不把 effectId 或 frames 假设为 giftId 或 count', () {
    final messages = <LiveMessage>[];
    final danmaku = _danmaku(messages);
    final payload = (TarsOutputStream()
          ..writeInt(99001, 0)
          ..writeInt(123, 1)
          ..writeInt(456, 2)
          ..writeInt(_uid, 3)
          ..writeInt(_pid, 4)
          ..writeString('活动用户', 5)
          ..writeString('测试主播', 6)
          ..writeString('//cdn.example.com/activity.webp', 7)
          ..writeInt(60, 8))
        .toUint8List();
    _push(danmaku, 6508, payload, messageId: 50);
    _push(danmaku, 6508, payload, messageId: 50);
    expect(messages, hasLength(1));
    final data = messages.single.data as Map;
    expect(data['kind'], 'giftActivityEffect');
    expect(data['effectId'], 99001);
    expect(data['giftId'], 0);
    expect(data['countKnown'], isFalse);
    expect(data['effectFrames'], 60);
    expect(data['giftEffectUrls'], ['https://cdn.example.com/activity.webp']);
  });

  test('1020001 NEW 守护通知进入统一展示；ENTER/状态/人数不冒充购买', () {
    final messages = <LiveMessage>[];
    final danmaku = _danmaku(messages);
    _push(danmaku, 1020001, _guardian(noticeType: 0), messageId: 10);
    _push(danmaku, 1020001, _guardian(noticeType: 0), messageId: 10);
    _push(danmaku, 1020001, _guardian(noticeType: 1), messageId: 11);
    _push(danmaku, 1020001, _guardian(noticeType: 99), messageId: 12);
    _push(danmaku, 1020003, _guardian(noticeType: 0), messageId: 13);
    _push(danmaku, 6249, (TarsOutputStream()..writeInt(8, 0)).toUint8List());
    expect(messages, hasLength(1));
    final data = messages.single.data as Map;
    expect(data['kind'], 'guardianOpen');
    expect(data['senderUid'], _uid);
    expect(data['sender'], '守护用户');
    expect(data['guardianLevel'], 5);
    expect(data['guardianOpenDays'], 93);
    expect(data['guardianType'], 17); // 未证实枚举仅原样保留。
    expect(data['giftId'], 0);
    expect(data['countKnown'], false);
    expect(data['count'], isNull);
    expect(messages.single.message, contains('开通'));
    expect(messages.single.message, contains('93天'));
    expect(data['giftImageUrls'], isNull); // 不把用户头像当守护图标。
  });

  test('守护更新保留未知操作类型，不猜测年费/续费/升级文案', () {
    final messages = <LiveMessage>[];
    _push(_danmaku(messages), 1020001, _guardian(noticeType: 0, lastLevel: 4));
    expect(messages.single.message, contains('更新'));
    expect(messages.single.message, isNot(contains('续费')));
    expect((messages.single.data as Map)['guardianOpType'], 88);
  });

  test('守护通知错误房间、缺失关键类型字段或负天数不能伪造开通', () {
    final messages = <LiveMessage>[];
    final danmaku = _danmaku(messages);
    _push(danmaku, 1020001, _guardian(noticeType: 0, presenter: 9));
    _push(danmaku, 1020001, _guardian(noticeType: null));
    _push(danmaku, 1020001, _guardian(noticeType: 0, days: -1));
    expect(messages, isEmpty);
  });

  test('负数广播数量不被 Uint8 误读为 255 次送礼', () {
    final messages = <LiveMessage>[];
    final payload = (TarsOutputStream()
          ..writeInt(4, 0)
          ..writeInt(-1, 1)
          ..writeInt(_uid, 3)
          ..writeString('用户', 4)
          ..writeInt(_pid, 5))
        .toUint8List();
    _push(_danmaku(messages), 6507, payload);
    expect(messages, isEmpty);
  });
}

HuyaDanmaku _danmaku(List<LiveMessage> output) => HuyaDanmaku()
  ..danmakuArgs = HuyaDanmakuArgs(ayyuid: _pid, topSid: 123, subSid: 456)
  ..onMessage = output.add;

void _command(HuyaDanmaku danmaku, int type, List<int> bytes) {
  final command = TarsOutputStream()
    ..writeInt(type, 0)
    ..write(Uint8List.fromList(bytes), 1);
  danmaku.decodeMessage(command.toUint8List());
}

void _push(HuyaDanmaku danmaku, int uri, Uint8List bytes, {int messageId = 1}) {
  final push = HYPushMessage()
    ..uri = uri
    ..msg = bytes
    ..groupId = ''
    ..messageId = messageId;
  final output = TarsOutputStream();
  push.writeTo(output);
  _command(danmaku, HuyaHySignalCommandType.pushMessage, output.toUint8List());
}

void _catalog(HuyaDanmaku danmaku) {
  final rsp = HYGetPropsListRsp()
    ..items = [
      HYPropsItem()
        ..propsId = 4
        ..propsName = '测试道具 A',
      HYPropsItem()
        ..propsId = 9
        ..propsName = '测试道具 B',
    ];
  final packet = TarsUniPacket()
    ..setTarsVersion(Const.PACKET_TYPE_TUP3)
    ..servantName = 'PropsUIServer'
    ..funcName = 'getPropsList';
  packet.put('tRsp', rsp);
  _command(danmaku, HuyaHySignalCommandType.wupResponse, packet.encode());
}

Uint8List _guardian(
    {required int? noticeType,
    int presenter = _pid,
    int lastLevel = 0,
    int days = 93}) {
  final output = TarsOutputStream()
    ..writeInt(presenter, 0)
    ..writeString('主播', 1)
    ..writeInt(5, 2)
    ..writeInt(_uid, 3)
    ..writeString('守护用户', 4);
  if (noticeType != null) output.writeInt(noticeType, 5);
  output
    ..writeInt(days, 6)
    ..writeInt(lastLevel, 7)
    ..writeInt(6, 8)
    ..writeString('https://cdn.example.com/user-avatar.png', 9)
    ..writeInt(7, 10)
    ..writeInt(17, 11)
    ..writeString('守护', 16)
    ..writeInt(88, 17);
  return output.toUint8List();
}

Uint8List _drawing({int presenter = _pid, int sender = _uid}) =>
    (TarsOutputStream()
          ..writeInt(sender, 0)
          ..writeInt(presenter, 1)
          ..writeInt(1780000000, 3)
          ..writeString('drawing-payment', 4)
          ..writeString('绘图用户', 5)
          ..writeString('主播', 6)
          ..writeString('//cdn.example.com/avatar.png', 7)
          ..write([
            _IndependentItem(4, 3),
            _IndependentItem(4, 2),
            _IndependentItem(9, 2147483648)
          ], 8)
          ..write(<int>[], 9))
        .toUint8List();

// Fixture-only independent writer，不调用待测模型的 writeTo。
class _IndependentItem extends TarsStruct {
  _IndependentItem(this.id, this.count);
  final int id;
  final int count;
  @override
  void writeTo(TarsOutputStream output) {
    output
      ..writeInt(id, 0)
      ..writeInt(count, 1);
  }

  @override
  void readFrom(TarsInputStream input) =>
      throw UnsupportedError('fixture writer only');
  @override
  Object deepCopy() => _IndependentItem(id, count);
  @override
  void displayAsString(StringBuffer sb, int level) {}
}
