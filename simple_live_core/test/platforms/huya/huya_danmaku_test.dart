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
  String sendContent = '',
  String customText = '',
  int payTotal = 0,
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
    ..sendContent = sendContent
    ..customText = customText
    ..roomId = 1995
    ..homeOwnerUid = _presenterUid
    ..payType = 0
    ..payTotal = payTotal;
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
    test('URI 1400 从真实 10400 装饰前缀解析粉丝牌', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final notice = HYMessage()
        ..userInfo = (HYSender()
          ..uid = 10001
          ..nickName = '粉丝用户')
        ..content = '测试弹幕'
        ..decorationPrefix = <HYDecorationInfo>[
          HYDecorationInfo()
            ..appId = 10400
            ..viewType = 0
            ..data = base64.decode(
              'EhGPyvA2Bualmuays0ANzPwR+hIGABkMC/oTAmirXeMcLDxMXGwL8BYB+hkGABwgAgv8Gg==',
            ),
        ];

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.chat,
          payload: _encodeStruct(notice),
          messageId: 100,
        ),
      );

      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.chat);
      final data = messages.single.data as Map;
      expect(data['uid'], 10001);
      expect(data['fanBadge'], {
        'id': 294636272,
        'name': '楚河',
        'level': 13,
        'appId': 10400,
        'viewType': 0,
      });
    });

    test('URI 1400 从 SenderInfo 解析普通聊天爵位', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final notice = HYMessage()
        ..userInfo = (HYSender()
          ..uid = 10003
          ..nickName = '公爵用户'
          ..nobleLevel = 4
          ..nobleLevelInfo = (HYNobleLevelInfo()
            ..nobleLevel = 4
            ..attrType = 2))
        ..content = '带爵位的普通弹幕';

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.chat,
          payload: _encodeStruct(notice),
          messageId: 102,
        ),
      );

      final data = messages.single.data as Map;
      expect(data['nobleName'], '公爵');
      expect(data['nobleLevel'], 4);
      expect(data['nobleSource'], 'sender');
      expect(data['nobleAttrType'], 2);
    });

    test('SenderInfo 直接等级缺失时兼容 NobleLevelInfo', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final notice = HYMessage()
        ..userInfo = (HYSender()
          ..uid = 10004
          ..nickName = '君王用户'
          ..nobleLevelInfo = (HYNobleLevelInfo()
            ..nobleLevel = 5
            ..attrType = 1))
        ..content = '嵌套爵位字段';

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.chat,
          payload: _encodeStruct(notice),
          messageId: 103,
        ),
      );

      final data = messages.single.data as Map;
      expect(data['nobleName'], '君王');
      expect(data['nobleLevel'], 5);
      expect(data['nobleSource'], 'senderInfo');
    });

    test('现代爵位字段缺失时回退解析 10200 旧装饰', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final notice = HYMessage()
        ..userInfo = (HYSender()
          ..uid = 10005
          ..nickName = '旧协议用户')
        ..content = '旧版爵位装饰'
        ..decorationPrefix = <HYDecorationInfo>[
          HYDecorationInfo()
            ..appId = 10200
            ..viewType = 0
            ..data = _encodeStruct(
              HYLegacyNobleBase()
                ..level = 3
                ..name = '领主',
            ),
        ];

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.chat,
          payload: _encodeStruct(notice),
          messageId: 104,
        ),
      );

      final data = messages.single.data as Map;
      expect(data['nobleName'], '领主');
      expect(data['nobleLevel'], 3);
      expect(data['nobleSource'], 'decoration');
    });

    test('无有效 10400 装饰时普通弹幕不伪造粉丝牌', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final notice = HYMessage()
        ..userInfo = (HYSender()
          ..uid = 10002
          ..nickName = '普通用户')
        ..content = '普通弹幕';

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.chat,
          payload: _encodeStruct(notice),
          messageId: 101,
        ),
      );

      final data = messages.single.data as Map;
      expect(data.containsKey('fanBadge'), isFalse);
      expect(data.containsKey('nobleLevel'), isFalse);
      expect(data.containsKey('nobleName'), isFalse);
    });

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
        ..nobleInfo = (HYNobleInfo()
          ..name = '剑士'
          ..level = 1)
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
      final data = messages.single.data as Map;
      expect(data['messageId'], 102);
      expect(data['groupId'], _liveGroup);
      expect(data['nobleName'], '剑士');
      expect(data['nobleLevel'], 1);
      expect(messages.single.message, isNot(startsWith('⭐')));
      expect(
        messages.where((e) => e.type == LiveMessageType.vipCount),
        isEmpty,
      );
    });

    test('V2 普通用户进场不伪造爵位字段', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final banner = HYVipEnterBanner()
        ..uid = 90002
        ..nickName = '普通用户'
        ..pid = _presenterUid;

      danmaku.decodeMessage(
        _wrapPushV2(
          uri: HuyaPushUri.vipEnterBanner,
          payload: _encodeStruct(banner),
          messageId: 103,
        ),
      );

      final data = messages.single.data as Map;
      expect(data.containsKey('nobleName'), isFalse);
      expect(data.containsKey('nobleLevel'), isFalse);
      expect(messages.single.message, '普通用户 进入直播间');
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

    test('透传互动礼物的服务端真实文案字段', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final gift = _gift(
        propsName: '告白灯牌',
        payId: 'pay-interactive',
        sendContent: '备用服务端文案',
        customText: '今天也要一直喜欢你',
      );

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(gift),
          messageId: 208,
        ),
      );

      expect(messages, hasLength(1));
      final data = messages.single.data as Map;
      expect(data['giftName'], '告白灯牌');
      expect(data['customText'], '今天也要一直喜欢你');
      expect(data['sendContent'], '备用服务端文案');
      expect(data['content'], '备用服务端文案');
    });

    test('透传服务端实付总额供高价值礼物识别', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(
            _gift(payId: 'pay-high-value', payTotal: 100000),
          ),
          messageId: 209,
        ),
      );

      expect(messages, hasLength(1));
      expect((messages.single.data as Map)['payTotal'], 100000);
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
        'https://cdn.example.com/gift/catalog-108.webp?token=second',
        'https://cdn.example.com/gift/catalog-icon.gif',
        'https://cdn.example.com/gift/android.png',
        'https://cdn.example.com/gift/android.png?platform=iphone',
      ]);
      expect(data['giftEffectUrls'], <String>[
        'https://cdn.example.com/gift/chat-effect.gif?token=first',
        'https://cdn.example.com/gift/chat-effect.gif?token=second',
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

    test('itemCount 缺失时使用服务端 itemCountByGroup 兜底', () {
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

      expect(messages, hasLength(1));
      expect((messages.single.data as Map)['count'], 88);
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

    test('6501/6502/6507/6514 的同一支付交易只展示一次', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final payload = _encodeStruct(
        _gift(payId: 'cross-channel-payment')..itemGroup = 3,
      );
      final uris = <int>[
        HuyaPushUri.giftSubChannel,
        HuyaPushUri.giftTopChannel,
        HuyaPushUri.giftGameBroadcast,
        HuyaPushUri.giftOtherBroadcast,
      ];

      for (var index = 0; index < uris.length; index++) {
        danmaku.decodeMessage(
          _wrapPush(
            uri: uris[index],
            payload: payload,
            messageId: 900 + index,
          ),
        );
      }

      expect(messages, hasLength(1));
      expect((messages.single.data as Map)['uri'], HuyaPushUri.giftSubChannel);
    });

    test('6541 高价值礼物特效可解析为可展示礼物事件', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final effect = HYLiveRoomLargeConsumptionEffectNotice()
        ..presenterUid = _presenterUid
        ..effectId = 70001
        ..customerUid = 8899
        ..customerNick = '高价值用户'
        ..customerAvatar = '//cdn.example.com/avatar.webp'
        ..recipientUid = _presenterUid
        ..recipientNick = '测试主播'
        ..itemName = '星河飞船'
        ..effectParams = <String, String>{
          'PAYTOTAL': '188000',
          'iconUrl': '//cdn.example.com/gift/starship.webp',
          'animationUrl': 'https://cdn.example.com/gift/starship.svga',
          'copy': '{"content":"一路星河送给你"}',
        };

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.bigGiftEffect,
          payload: _encodeStruct(effect),
          groupId: '',
          messageId: 951,
        ),
      );

      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.gift);
      final data = messages.single.data as Map;
      expect(data['kind'], 'giftEffectNotice');
      expect(data['giftName'], '星河飞船');
      expect(data['sender'], '高价值用户');
      expect(data['payTotal'], 188000);
      expect(data['isBigEffect'], isTrue);
      expect(
        data['giftEffectUrls'],
        contains('https://cdn.example.com/gift/starship.svga'),
      );
    });

    test('6541 使用 messageId 精确去重且不误删连续同款礼物', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final effect = HYLiveRoomLargeConsumptionEffectNotice()
        ..presenterUid = _presenterUid
        ..effectId = 70002
        ..customerUid = 9901
        ..customerNick = '连续送礼用户'
        ..itemName = '星河飞船'
        ..effectParams = <String, String>{'PAYTOTAL': '188000'};
      final payload = _encodeStruct(effect);

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.bigGiftEffect,
          payload: payload,
          groupId: '',
          messageId: 960,
        ),
      );
      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.bigGiftEffect,
          payload: payload,
          groupId: '',
          messageId: 960,
        ),
      );
      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.bigGiftEffect,
          payload: payload,
          groupId: '',
          messageId: 961,
        ),
      );

      expect(messages, hasLength(2));
      expect(
        messages.map((message) => (message.data as Map)['messageId']),
        <int>[960, 961],
      );
    });

    test('6501 与 6541 同一高价值礼物只进入 UI 一次', () {
      HYLiveRoomLargeConsumptionEffectNotice effect() {
        return HYLiveRoomLargeConsumptionEffectNotice()
          ..presenterUid = _presenterUid
          ..effectId = 70003
          ..customerUid = 9910
          ..customerNick = '高价值用户'
          ..itemName = '星河飞船'
          ..effectParams = <String, String>{
            'PAYTOTAL': '188000',
            'PAYID': 'cross-kind-payment',
          };
      }

      HYSendItemSubBroadcastPacket transaction() {
        return _gift(
          payId: 'cross-kind-payment',
          senderUid: 9910,
          senderNick: '高价值用户',
          propsName: '星河飞船',
          payTotal: 188000,
        );
      }

      final transactionFirst = <LiveMessage>[];
      final firstDanmaku = _createDanmaku(transactionFirst);
      firstDanmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(transaction()),
          messageId: 970,
        ),
      );
      firstDanmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.bigGiftEffect,
          payload: _encodeStruct(effect()),
          groupId: '',
          messageId: 971,
        ),
      );

      final effectFirst = <LiveMessage>[];
      final secondDanmaku = _createDanmaku(effectFirst);
      secondDanmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.bigGiftEffect,
          payload: _encodeStruct(effect()),
          groupId: '',
          messageId: 972,
        ),
      );
      secondDanmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(transaction()),
          messageId: 973,
        ),
      );

      expect(transactionFirst, hasLength(1));
      expect((transactionFirst.single.data as Map)['kind'], 'giftTransaction');
      expect(effectFirst, hasLength(1));
      expect((effectFirst.single.data as Map)['kind'], 'giftEffectNotice');
    });

    test('缺少共同交易标识时不按用户、礼物名和金额模糊去重', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final effect = HYLiveRoomLargeConsumptionEffectNotice()
        ..presenterUid = _presenterUid
        ..effectId = 70004
        ..customerUid = 9911
        ..customerNick = '连续送礼用户'
        ..itemName = '星河飞船'
        ..effectParams = <String, String>{'PAYTOTAL': '188000'};

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(
            _gift(
              payId: 'transaction-without-shared-id',
              senderUid: 9911,
              senderNick: '连续送礼用户',
              propsName: '星河飞船',
              payTotal: 188000,
            ),
          ),
          messageId: 980,
        ),
      );
      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.bigGiftEffect,
          payload: _encodeStruct(effect),
          groupId: '',
          messageId: 981,
        ),
      );

      expect(messages, hasLength(2));
    });

    test('礼物扩展字段、效果信息和互动业务数据完整透传', () {
      final messages = <LiveMessage>[];
      final danmaku = _createDanmaku(messages);
      final gift = _gift(
        payId: 'complete-fields',
        propsName: '告白灯牌',
      )
        ..expand = '{"content":"今晚的星光都送给你"}'
        ..comboSeqId = 81
        ..comboStatus = 2
        ..displayInfo = 6
        ..eventType = 7
        ..accept = 1
        ..superPurpleLevel = 3
        ..nobleLevel = 4
        ..vFanLevel = 25
        ..upgradeLevel = 2
        ..multiSend = 1
        ..effectInfo = (HYItemEffectInfo()
          ..priceLevel = 5
          ..streamDuration = 3600
          ..showType = 3
          ..streamId = 99)
        ..bizData = <HYItemEffectBizData>[
          HYItemEffectBizData()
            ..type = 12
            ..data = Uint8List.fromList(
              utf8.encode('{"message":"永远支持你"}'),
            ),
        ];

      danmaku.decodeMessage(
        _wrapPush(
          uri: HuyaPushUri.giftSubChannel,
          payload: _encodeStruct(gift),
          messageId: 952,
        ),
      );

      final data = messages.single.data as Map;
      expect(data['expand'], gift.expand);
      expect(data['comboSeqId'], 81);
      expect(data['comboStatus'], 2);
      expect(data['displayInfo'], 6);
      expect(data['eventType'], 7);
      expect(data['nobleLevel'], 4);
      expect(data['vFanLevel'], 25);
      expect(data['multiSend'], 1);
      expect((data['effectInfo'] as Map)['showAsStream'], isTrue);
      expect((data['effectInfo'] as Map)['showAsBigEffect'], isTrue);
      expect((data['bizData'] as List).single['text'], contains('永远支持你'));
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
