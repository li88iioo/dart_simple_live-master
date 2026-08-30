import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/model/tars/huya_danmaku.dart';
import 'package:simple_live_core/src/platforms/huya/huya_gift_catalog.dart';
import 'package:simple_live_core/src/platforms/huya/huya_hysignal.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';
import 'package:tars_dart/tars/tup/const.dart';
import 'package:tars_dart/tars/tup/tars_uni_packet.dart';
import 'package:test/test.dart';

const int _presenterUid = 2272316519;
const String _chatGroup = 'chat:2272316519';
const String _liveGroup = 'live:2272316519';

const String _capturedGiftFixtureBase64 =
    'AAQWACABMwAAAACHcMxnQwAAARdQJeU/VhblsI/lsI/lsI/phbflk6Ut57uE57uHZg/lsLHn'
    'iLHlgZrlgZrlj6R2AIABkAGsvMAI3OZhaHR0cHM6Ly9odXlhaW1nLm1zc3RhdGljLmNvbS9h'
    'dmF0YXIvMTAxNy9iZC81NTcwMWUwZTAyZDEyMWZiODU3ZDc5YzZkNzc4MmRfMTgwXzEzNS5q'
    'cGc/MTc1MDA5MTYwMfYPAPAQBfYRAPwS/BP2FAbomY7nsq78FfwW+hcJAAEKASvAHC0AAA4D'
    'AAABF1Al5T8QASwwATxMCxkMC/EYB8vzGQAAAACHcMxn+hoAARwgAQv8G/wc+h0MHAv6HgwQ'
    'Aiw8C/kfDPwg/CH8Ivwj/CT2JQD6JgYAFgAmADYAC/MnAAABoFGfI/j8KfkqDAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

final HuyaDanmakuArgs _args = HuyaDanmakuArgs(
  ayyuid: _presenterUid,
  topSid: 12345,
  subSid: 67890,
);

Uint8List _encodeStruct(TarsStruct value) {
  final output = TarsOutputStream();
  value.writeTo(output);
  return output.toUint8List();
}

List<int> _wrapCommand(int commandType, List<int> payload) {
  final output = TarsOutputStream()
    ..write(commandType, 0)
    ..write(Uint8List.fromList(payload), 1);
  return output.toUint8List();
}

List<int> _wrapPush({
  required int uri,
  required List<int> payload,
  String groupId = _chatGroup,
  int messageId = 1,
}) {
  final push = HYPushMessage()
    ..uri = uri
    ..msg = payload
    ..groupId = groupId
    ..messageId = messageId;
  return _wrapCommand(HuyaHySignalCommandType.pushMessage, _encodeStruct(push));
}

List<int> _wrapPushV2({
  required int uri,
  required List<int> payload,
  String groupId = _liveGroup,
  int messageId = 1,
}) {
  final push = HYWSPushMessageV2()
    ..groupId = groupId
    ..items = <HYWSMsgItem>[
      HYWSMsgItem()
        ..uri = uri
        ..message = Uint8List.fromList(payload)
        ..messageId = messageId,
    ];
  return _wrapCommand(
    HuyaHySignalCommandType.pushMessageV2,
    _encodeStruct(push),
  );
}

List<int> _wrapCatalogResponse(List<HYPropsItem> items) {
  final response = HYGetPropsListRsp()..items = items;
  final packet = TarsUniPacket()
    ..setTarsVersion(Const.PACKET_TYPE_TUP3)
    ..requestId = 7
    ..servantName = 'PropsUIServer'
    ..funcName = 'getPropsList';
  packet.put('tRsp', response);
  return _wrapCommand(HuyaHySignalCommandType.wupResponse, packet.encode());
}

HuyaDanmaku _createDanmaku(List<LiveMessage> messages) {
  return HuyaDanmaku()
    ..danmakuArgs = _args
    ..onMessage = messages.add;
}

HYSendItemSubBroadcastPacket _gift({
  int itemType = 4,
  int itemCount = 1,
  int presenterUid = _presenterUid,
  int senderUid = 10001,
  String senderNick = '测试用户',
  String propsName = '虎粮',
  String payId = 'pay-1',
}) {
  return HYSendItemSubBroadcastPacket()
    ..itemType = itemType
    ..itemCount = itemCount
    ..itemCountByGroup = itemCount + 10
    ..presenterUid = presenterUid
    ..senderUid = senderUid
    ..senderNick = senderNick
    ..presenterNick = '测试主播'
    ..propsName = propsName
    ..payId = payId
    ..roomId = 1995
    ..homeOwnerUid = _presenterUid
    ..payType = 0
    ..payTotal = 0;
}

void main() {
  group('虎牙注册与礼物目录协议', () {
    test('使用 WSRegisterGroupReq 精确订阅 live/chat 分组', () {
      final danmaku = HuyaDanmaku();
      final data = danmaku.getRegisterGroupData(_presenterUid);

      expect(
        base64.encode(data),
        'ABAdAAAnCQACBg9saXZlOjIyNzIzMTY1MTkGD2NoYXQ6MjI3MjMxNjUxORYALDYATFxmAA==',
      );

      final command = TarsInputStream(Uint8List.fromList(data));
      expect(
        command.read(0, 0, false),
        HuyaHySignalCommandType.registerGroupRequest,
      );
      final payload = command.readBytes(1, false);
      expect(command.read(0, 2, false), 0);
      expect(command.read('', 3, false), isEmpty);
      expect(command.read(0, 4, false), 0);
      expect(command.read(0, 5, false), 0);
      expect(command.read('', 6, false), isEmpty);
      final request = TarsInputStream(payload);
      expect(request.readList<String>(<String>[''], 0, false), <String>[
        _liveGroup,
        _chatGroup,
      ]);
    });

    test('心跳包写出当前 WebSocketCommand 的完整默认字段', () {
      final danmaku = HuyaDanmaku();
      expect(base64.encode(danmaku.heartbeatData), 'ABQdAAwsNgBMXGYA');
    });

    test('getPropsList 使用匿名 Web 模板并携带真实主播参数', () {
      final danmaku = HuyaDanmaku();
      final data = danmaku.getGiftCatalogRequestData(_args, requestId: 123);

      final command = TarsInputStream(Uint8List.fromList(data));
      expect(command.read(0, 0, false), HuyaHySignalCommandType.wupRequest);

      final packet = TarsUniPacket();
      packet.decode(command.readBytes(1, false));
      expect(packet.requestId, 123);
      expect(packet.servantName, 'PropsUIServer');
      expect(packet.funcName, 'getPropsList');

      final request = packet.get('tReq', HYGetPropsListReq());
      expect(request.userId.uid, 0);
      expect(request.userId.huyaUa, isEmpty);
      expect(request.userId.tokenType, 0);
      expect(request.userId.deviceInfo, isEmpty);
      expect(request.userId.qimei, isEmpty);
      expect(request.templateType, 32);
      expect(request.presenterUid, _presenterUid);
      expect(request.sid, _args.topSid);
      expect(request.subSid, _args.subSid);
      expect(request.gameId, 0);
    });

    test('注册成功 ACK 会停止看门狗且不会误重连', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      final protocolReady = Completer<void>();
      var connectionCount = 0;
      var registerMessageCount = 0;

      final serverSubscription = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        connectionCount++;
        socket.listen((data) {
          if (data is! List<int>) return;
          final command = TarsInputStream(Uint8List.fromList(data));
          final type = command.read(0, 0, false);
          if (type != HuyaHySignalCommandType.registerGroupRequest) return;
          registerMessageCount++;
          final response = HYWSRegisterGroupRsp()..resultCode = 0;
          socket.add(
            _wrapCommand(
              HuyaHySignalCommandType.registerGroupResponse,
              _encodeStruct(response),
            ),
          );
        });
      });

      final danmaku = HuyaDanmaku(
        registerAckTimeout: const Duration(milliseconds: 25),
        maxRegisterAttempts: 2,
        socketReconnectInterval: const Duration(milliseconds: 15),
      )
        ..serverUrl = 'ws://${server.address.address}:${server.port}'
        ..onReady = () {
          if (!protocolReady.isCompleted) protocolReady.complete();
        };

      addTearDown(() async {
        await danmaku.stop();
        for (final socket in sockets) {
          await socket.close();
        }
        await serverSubscription.cancel();
        await server.close(force: true);
      });

      await danmaku.start(_args);
      await protocolReady.future.timeout(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(connectionCount, 1);
      expect(registerMessageCount, 1);
    });

    test('注册 ACK 连续超时后有限重发并切换到新连接', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      final registrationsByConnection = <int, int>{};
      final secondConnectionRegistered = Completer<void>();
      var connectionCount = 0;

      final serverSubscription = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        final connectionId = ++connectionCount;
        socket.listen((data) {
          if (data is! List<int>) return;
          final command = TarsInputStream(Uint8List.fromList(data));
          final type = command.read(0, 0, false);
          if (type != HuyaHySignalCommandType.registerGroupRequest) return;
          registrationsByConnection.update(
            connectionId,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
          if (connectionId >= 2 && !secondConnectionRegistered.isCompleted) {
            secondConnectionRegistered.complete();
          }
        });
      });

      final danmaku = HuyaDanmaku(
        registerAckTimeout: const Duration(milliseconds: 25),
        maxRegisterAttempts: 2,
        socketReconnectInterval: const Duration(milliseconds: 15),
      )..serverUrl = 'ws://${server.address.address}:${server.port}';

      addTearDown(() async {
        await danmaku.stop();
        for (final socket in sockets) {
          await socket.close();
        }
        await serverSubscription.cancel();
        await server.close(force: true);
      });

      await danmaku.start(_args);
      await secondConnectionRegistered.future.timeout(
        const Duration(seconds: 3),
      );

      expect(connectionCount, greaterThanOrEqualTo(2));
      expect(registrationsByConnection[1], 2);
      expect(registrationsByConnection[2], greaterThanOrEqualTo(1));
    });
  });

  group('虎牙事实型消息解析', () {
    test('解析真实抓包的 URI 6211 贵宾人数快照', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final fixture = base64.decode('AwAAAACHcMxnERwhLA==');

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.vipBarCount,
          payload: fixture,
          messageId: 101,
        ),
      );

      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.vipCount);
      final data = messages.single.data as Map;
      expect(data['count'], 7201);
      expect(data['pid'], _presenterUid);
    });

    test('V2 贵宾进场只产生进场事件，不伪造人数', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final banner = HYVipEnterBanner()
        ..uid = 90001
        ..nickName = '贵宾用户'
        ..pid = _presenterUid
        ..logoUrl = 'https://example.invalid/avatar.png';

      danmaku.decodeMessage(
        _wrapPushV2(
          uri: HuyaPushUri.vipEnterBanner,
          payload: _encodeStruct(banner),
          messageId: 102,
        ),
      );

      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.vipEnter);
      expect(messages.single.message, contains('贵宾用户'));
      expect(
        messages.where((e) => e.type == LiveMessageType.vipCount),
        isEmpty,
      );
    });

    test('解析真实抓包的 URI 6501 礼物事实字段', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: base64.decode(_capturedGiftFixtureBase64),
          messageId: 200,
        ),
      );

      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.gift);
      expect(messages.single.message, '🎁 就爱做做古 送出 虎粮 x1');
      final data = messages.single.data as Map;
      expect(data['giftId'], 4);
      expect(data['giftName'], '虎粮');
      expect(data['count'], 1);
      expect(data['itemCountByGroup'], 1);
      expect(data['itemGroup'], 1);
      expect(data['senderUid'], 1199640536383);
      expect(data['presenterUid'], _presenterUid);
      expect(data['roomId'], 1995);
      expect(data['payTotal'], 0);
    });

    test('广播包礼物名优先，数量严格使用 itemCount', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final gift = _gift(itemCount: 2, propsName: '广播虎粮');

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(gift),
          messageId: 201,
        ),
      );

      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.gift);
      expect(messages.single.message, '🎁 测试用户 送出 广播虎粮 x2');
      final data = messages.single.data as Map;
      expect(data['giftName'], '广播虎粮');
      expect(data['count'], 2);
      expect(data['itemCountByGroup'], 12);
      expect(data['payTotal'], 0);
      expect(data['catalogNominalTotalYb'], isNull);
    });

    test('透传 DIY 大礼物资源字段供 UI 安全选择图片', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final gift = _gift(payId: 'pay-effect-resource');
      gift.diyEffect
        ..resourceUrl = 'https://cdn.example.com/gift/common.webp'
        ..resourceAttr = '{"format":"webp","width":480}'
        ..webResourceUrl = 'https://cdn.example.com/gift/web.svga'
        ..pcResourceUrl = 'https://cdn.example.com/gift/desktop.zip';

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(gift),
          messageId: 206,
        ),
      );

      expect(messages, hasLength(1));
      final data = messages.single.data as Map;
      expect(data['resourceUrl'], gift.diyEffect.resourceUrl);
      expect(data['resourceAttr'], gift.diyEffect.resourceAttr);
      expect(data['webResourceUrl'], gift.diyEffect.webResourceUrl);
      expect(data['pcResourceUrl'], gift.diyEffect.pcResourceUrl);
    });

    test('礼物目录候选会规范化去重且图标不混入效果资源', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      danmaku.decodeMessage(
        _wrapCatalogResponse(<HYPropsItem>[
          HYPropsItem()
            ..propsId = 4
            ..propsName = '目录虎粮'
            ..propsYb = 10
            ..androidLogo = '//cdn.example.com/gift/android.png&legacy-sign'
            ..iphoneLogo =
                'https://cdn.example.com/gift/android.png?platform=iphone'
            ..identities = <HYPropsIdentity>[
              HYPropsIdentity()
                ..propsPic108 =
                    '//cdn.example.com/gift/catalog-108.webp?token=first'
                ..propsPic24 =
                    'https://cdn.example.com/gift/catalog-108.webp?token=second'
                ..propsPicGif =
                    'https://cdn.example.com/gift/catalog-icon.gif&legacy-sign'
                ..propsChatBannerResource =
                    '//cdn.example.com/gift/chat-effect.gif?token=first'
                ..propsBannerResource =
                    'https://cdn.example.com/gift/chat-effect.gif?token=second'
                ..propH5Resource =
                    'https://cdn.example.com/gift/real-effect.webp',
            ],
        ]),
      );

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(_gift(payId: 'pay-catalog-visual')),
          messageId: 207,
        ),
      );

      expect(messages, hasLength(1));
      final data = messages.single.data as Map;
      expect(data['giftImageUrls'], <String>[
        'https://cdn.example.com/gift/catalog-108.webp?token=first',
        'https://cdn.example.com/gift/catalog-icon.gif',
        'https://cdn.example.com/gift/android.png',
      ]);
      expect(data['giftEffectUrls'], <String>[
        'https://cdn.example.com/gift/chat-effect.gif?token=first',
        'https://cdn.example.com/gift/real-effect.webp',
      ]);
    });

    test('目录只为缺少名称的广播提供真实回退', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      danmaku.decodeMessage(
        _wrapCatalogResponse(<HYPropsItem>[
          HYPropsItem()
            ..propsId = 4
            ..propsName = '目录虎粮'
            ..propsYb = 10,
        ]),
      );

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(_gift(propsName: '', payId: 'pay-2')),
          messageId: 202,
        ),
      );

      expect(messages, hasLength(1));
      final data = messages.single.data as Map;
      expect(data['giftName'], '目录虎粮');
      expect(data['catalogUnitPriceYb'], 10);
      expect(data['catalogNominalTotalYb'], 10);
    });

    test('广播名称不会被目录中的名称覆盖', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      danmaku.decodeMessage(
        _wrapCatalogResponse(<HYPropsItem>[
          HYPropsItem()
            ..propsId = 4
            ..propsName = '目录旧名称'
            ..propsYb = 10,
        ]),
      );

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(_gift(propsName: '广播新名称', payId: 'pay-3')),
          messageId: 203,
        ),
      );

      expect((messages.single.data as Map)['giftName'], '广播新名称');
    });

    test('目录已就绪但无法识别时明确标记未知礼物', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      danmaku.decodeMessage(
        _wrapCatalogResponse(<HYPropsItem>[
          HYPropsItem()
            ..propsId = 4
            ..propsName = '虎粮'
            ..propsYb = 10,
        ]),
      );

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(
            _gift(itemType: 99999, propsName: '', payId: 'pay-unknown'),
          ),
          messageId: 204,
        ),
      );

      expect((messages.single.data as Map)['giftName'], '未知礼物（ID 99999）');
    });

    test('不使用 itemCountByGroup 猜测本次礼物数量', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final gift = _gift(itemCount: 0, payId: 'pay-zero')
        ..itemCountByGroup = 88;

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(gift),
          messageId: 205,
        ),
      );

      expect(messages, isEmpty);
    });

    test('相同支付号的不同 itemGroup 不会被误判为重复礼物', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final first = _gift(payId: 'grouped-payment')..itemGroup = 1;
      final second = _gift(payId: 'grouped-payment')..itemGroup = 2;

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(first),
          messageId: 0,
        ),
      );
      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(second),
          messageId: 0,
        ),
      );

      expect(messages, hasLength(2));
      expect(
        messages.map((message) => (message.data as Map)['itemGroup']),
        <int>[1, 2],
      );
    });

    test('messageId 缺失时按 payId 与 itemGroup 去重', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final duplicate = _encodeStruct(
        _gift(payId: 'fallback-payment')..itemGroup = 7,
      );

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: duplicate,
          messageId: 0,
        ),
      );
      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: duplicate,
          messageId: 0,
        ),
      );

      expect(messages, hasLength(1));
    });

    test('messageId 与 payId 均缺失时不臆造交易去重键', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final gift = _encodeStruct(_gift(payId: ''));

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: gift,
          messageId: 0,
        ),
      );
      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: gift,
          messageId: 0,
        ),
      );

      expect(messages, hasLength(2));
    });

    test('丢弃错误分组、错误主播和重复消息事件', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(_gift(payId: 'wrong-group')),
          groupId: 'chat:1',
          messageId: 301,
        ),
      );
      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(
            _gift(presenterUid: 1, payId: 'wrong-presenter'),
          ),
          messageId: 302,
        ),
      );
      final duplicate = _encodeStruct(_gift(payId: 'same-transaction'));
      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: duplicate,
          messageId: 303,
        ),
      );
      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: duplicate,
          messageId: 303,
        ),
      );

      expect(messages, hasLength(1));
      expect((messages.single.data as Map)['payId'], 'same-transaction');
    });
  });
}
