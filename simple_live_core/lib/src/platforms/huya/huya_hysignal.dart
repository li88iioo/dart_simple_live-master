// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:typed_data';

import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

import 'huya_tars_utils.dart';

class HuyaHySignalCommandType {
  const HuyaHySignalCommandType._();

  static const int wupRequest = 3;
  static const int wupResponse = 4;
  static const int pushMessage = 7;
  static const int registerGroupRequest = 16;
  static const int registerGroupResponse = 17;
  static const int heartbeatRequest = 20;
  static const int pushMessageV2 = 22;
}

class HuyaPushUri {
  const HuyaPushUri._();

  static const int chat = 1400;
  static const int vipEnterBanner = 6110;
  static const int vipBarList = 6210;
  static const int vipBarCount = 6211;
  static const int vipBarSimpleList = 6213;
  static const int giftSubChannel = 6501;
  // 兼容既有名称：6502 实际是文字广播，不是 6501 的另一个频道。
  static const int giftTopChannel = 6502;
  static const int giftGameBroadcast = 6507;
  static const int giftActivityBroadcast = 6508;
  static const int giftOtherBroadcast = 6514;
  static const int guardianNotice = 1020001;
  static const int bigGiftEffect = 6541;
  static const int attendeeCount = 8006;
}

class HYWSPushMessageV2 extends TarsStruct {
  String groupId = "";
  List<HYWSMsgItem> items = <HYWSMsgItem>[];

  @override
  void readFrom(TarsInputStream _is) {
    groupId = _is.read(groupId, 0, false);
    items = _is.readList<HYWSMsgItem>([HYWSMsgItem()], 1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(groupId, 0);
    _os.write(items, 1);
  }

  @override
  Object deepCopy() {
    return HYWSPushMessageV2()
      ..groupId = groupId
      ..items = items.map((e) => e.deepCopy() as HYWSMsgItem).toList();
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYWSMsgItem extends TarsStruct {
  int uri = 0;
  Uint8List message = Uint8List(0);
  int messageId = 0;

  @override
  void readFrom(TarsInputStream _is) {
    uri = _is.read(uri, 0, false);
    message = _is.readBytes(1, false);
    messageId = _is.read(messageId, 2, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(uri, 0);
    _os.write(message, 1);
    _os.write(messageId, 2);
  }

  @override
  Object deepCopy() {
    return HYWSMsgItem()
      ..uri = uri
      ..message = Uint8List.fromList(message)
      ..messageId = messageId;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYWSRegisterGroupRsp extends TarsStruct {
  int resultCode = 0;
  List<String> supportedGroupIds = <String>[];

  @override
  void readFrom(TarsInputStream _is) {
    resultCode = _is.read(resultCode, 0, false);
    supportedGroupIds = _is.readList<String>([""], 1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(resultCode, 0);
    _os.write(supportedGroupIds, 1);
  }

  @override
  Object deepCopy() {
    return HYWSRegisterGroupRsp()
      ..resultCode = resultCode
      ..supportedGroupIds = List<String>.from(supportedGroupIds);
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

/// URI 6501: SendItemSubBroadcastPacket。
///
/// 当前桌面网页协议包含 tag 0-42；其中 [propsName] 是广播包自带的真实礼物名。
/// 礼物目录只在旧版/移动端形状未携带名称时作为回退，不能覆盖广播事实。
class HYSendItemSubBroadcastPacket extends TarsStruct {
  int itemType = 0;
  String payId = "";
  int itemCount = 0;
  int presenterUid = 0;
  int senderUid = 0;
  String presenterNick = "";
  String senderNick = "";
  String sendContent = "";
  int itemCountByGroup = 0;
  int itemGroup = 0;
  int superPurpleLevel = 0;
  int comboScore = 0;
  int displayInfo = 0;
  int effectType = 0;
  String senderIcon = "";
  String presenterIcon = "";
  int templateType = 0;
  String expand = "";
  bool business = false;
  int colorEffectType = 0;
  String propsName = "";
  int accept = 0;
  int eventType = 0;
  int roomId = 0;
  int homeOwnerUid = 0;
  int payType = -1;
  int nobleLevel = 0;
  HYItemEffectInfo effectInfo = HYItemEffectInfo();
  int comboStatus = 0;
  int pidColorType = 0;
  int multiSend = 0;
  int vFanLevel = 0;
  int upgradeLevel = 0;
  String customText = "";
  HYDIYBigGiftEffect diyEffect = HYDIYBigGiftEffect();
  int comboSeqId = 0;
  int payTotal = 0;
  List<HYItemEffectBizData> bizData = <HYItemEffectBizData>[];

  @override
  void readFrom(TarsInputStream _is) {
    itemType = readHuyaSignedInt(_is, 0, false);
    payId = _is.read(payId, 1, false);
    itemCount = readHuyaSignedInt(_is, 2, false);
    presenterUid = readHuyaSignedInt(_is, 3, false);
    senderUid = readHuyaSignedInt(_is, 4, false);
    presenterNick = _is.read(presenterNick, 5, false);
    senderNick = _is.read(senderNick, 6, false);
    sendContent = _is.read(sendContent, 7, false);
    itemCountByGroup = readHuyaSignedInt(_is, 8, false);
    itemGroup = readHuyaSignedInt(_is, 9, false);
    superPurpleLevel = readHuyaSignedInt(_is, 10, false);
    comboScore = readHuyaSignedInt(_is, 11, false);
    displayInfo = readHuyaSignedInt(_is, 12, false);
    effectType = readHuyaSignedInt(_is, 13, false);
    senderIcon = _is.read(senderIcon, 14, false);
    presenterIcon = _is.read(presenterIcon, 15, false);
    templateType = readHuyaSignedInt(_is, 16, false);
    expand = _is.read(expand, 17, false);
    business = _is.read(business, 18, false);
    colorEffectType = readHuyaSignedInt(_is, 19, false);
    propsName = _is.read(propsName, 20, false);
    accept = readHuyaSignedInt(_is, 21, false);
    eventType = readHuyaSignedInt(_is, 22, false);
    roomId = readHuyaSignedInt(_is, 24, false);
    homeOwnerUid = readHuyaSignedInt(_is, 25, false);
    // 缺失时保留协议的未知支付类型 -1；显式 0 是另一种事实。
    payType = readHuyaSignedInt(_is, 27, false, defaultValue: -1);
    nobleLevel = readHuyaSignedInt(_is, 28, false);
    effectInfo = _is.readTarsStruct(
      effectInfo,
      30,
      false,
    ) as HYItemEffectInfo;
    comboStatus = readHuyaSignedInt(_is, 32, false);
    pidColorType = readHuyaSignedInt(_is, 33, false);
    multiSend = readHuyaSignedInt(_is, 34, false);
    vFanLevel = readHuyaSignedInt(_is, 35, false);
    upgradeLevel = readHuyaSignedInt(_is, 36, false);
    customText = _is.read(customText, 37, false);
    diyEffect = _is.readTarsStruct(
      diyEffect,
      38,
      false,
    ) as HYDIYBigGiftEffect;
    comboSeqId = readHuyaSignedInt(_is, 39, false);
    payTotal = readHuyaSignedInt(_is, 41, false);
    bizData = _is.readList<HYItemEffectBizData>(
      [HYItemEffectBizData()],
      42,
      false,
    );
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(itemType, 0);
    _os.write(payId, 1);
    _os.write(itemCount, 2);
    _os.write(presenterUid, 3);
    _os.write(senderUid, 4);
    _os.write(presenterNick, 5);
    _os.write(senderNick, 6);
    _os.write(sendContent, 7);
    _os.write(itemCountByGroup, 8);
    _os.write(itemGroup, 9);
    _os.write(superPurpleLevel, 10);
    _os.write(comboScore, 11);
    _os.write(displayInfo, 12);
    _os.write(effectType, 13);
    _os.write(senderIcon, 14);
    _os.write(presenterIcon, 15);
    _os.write(templateType, 16);
    _os.write(expand, 17);
    _os.write(business, 18);
    _os.write(colorEffectType, 19);
    _os.write(propsName, 20);
    _os.write(accept, 21);
    _os.write(eventType, 22);
    _os.write(roomId, 24);
    _os.write(homeOwnerUid, 25);
    _os.write(payType, 27);
    _os.write(nobleLevel, 28);
    _os.write(effectInfo, 30);
    _os.write(comboStatus, 32);
    _os.write(pidColorType, 33);
    _os.write(multiSend, 34);
    _os.write(vFanLevel, 35);
    _os.write(upgradeLevel, 36);
    _os.write(customText, 37);
    _os.write(diyEffect, 38);
    _os.write(comboSeqId, 39);
    _os.write(payTotal, 41);
    _os.write(bizData, 42);
  }

  @override
  Object deepCopy() {
    return HYSendItemSubBroadcastPacket()
      ..itemType = itemType
      ..payId = payId
      ..itemCount = itemCount
      ..presenterUid = presenterUid
      ..senderUid = senderUid
      ..presenterNick = presenterNick
      ..senderNick = senderNick
      ..sendContent = sendContent
      ..itemCountByGroup = itemCountByGroup
      ..itemGroup = itemGroup
      ..superPurpleLevel = superPurpleLevel
      ..comboScore = comboScore
      ..displayInfo = displayInfo
      ..effectType = effectType
      ..senderIcon = senderIcon
      ..presenterIcon = presenterIcon
      ..templateType = templateType
      ..expand = expand
      ..business = business
      ..colorEffectType = colorEffectType
      ..propsName = propsName
      ..accept = accept
      ..eventType = eventType
      ..roomId = roomId
      ..homeOwnerUid = homeOwnerUid
      ..payType = payType
      ..nobleLevel = nobleLevel
      ..effectInfo = effectInfo.deepCopy() as HYItemEffectInfo
      ..comboStatus = comboStatus
      ..pidColorType = pidColorType
      ..multiSend = multiSend
      ..vFanLevel = vFanLevel
      ..upgradeLevel = upgradeLevel
      ..customText = customText
      ..diyEffect = diyEffect.deepCopy() as HYDIYBigGiftEffect
      ..comboSeqId = comboSeqId
      ..payTotal = payTotal
      ..bizData =
          bizData.map((e) => e.deepCopy() as HYItemEffectBizData).toList();
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYItemEffectInfo extends TarsStruct {
  int priceLevel = 0;
  int streamDuration = 0;
  int showType = 0;
  int streamId = 0;

  bool get showAsStream => (showType & 1) != 0;
  bool get showAsBigEffect => (showType & 2) != 0;

  @override
  void readFrom(TarsInputStream _is) {
    priceLevel = readHuyaSignedInt(_is, 0, false);
    streamDuration = readHuyaSignedInt(_is, 1, false);
    showType = readHuyaSignedInt(_is, 2, false);
    streamId = readHuyaSignedInt(_is, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(priceLevel, 0);
    _os.write(streamDuration, 1);
    _os.write(showType, 2);
    _os.write(streamId, 3);
  }

  @override
  Object deepCopy() {
    return HYItemEffectInfo()
      ..priceLevel = priceLevel
      ..streamDuration = streamDuration
      ..showType = showType
      ..streamId = streamId;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYDIYBigGiftEffect extends TarsStruct {
  String resourceUrl = "";
  String resourceAttr = "";
  String webResourceUrl = "";
  String pcResourceUrl = "";

  @override
  void readFrom(TarsInputStream _is) {
    resourceUrl = _is.read(resourceUrl, 0, false);
    resourceAttr = _is.read(resourceAttr, 1, false);
    webResourceUrl = _is.read(webResourceUrl, 2, false);
    pcResourceUrl = _is.read(pcResourceUrl, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(resourceUrl, 0);
    _os.write(resourceAttr, 1);
    _os.write(webResourceUrl, 2);
    _os.write(pcResourceUrl, 3);
  }

  @override
  Object deepCopy() {
    return HYDIYBigGiftEffect()
      ..resourceUrl = resourceUrl
      ..resourceAttr = resourceAttr
      ..webResourceUrl = webResourceUrl
      ..pcResourceUrl = pcResourceUrl;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYItemEffectBizData extends TarsStruct {
  int type = 0;
  Uint8List data = Uint8List(0);

  @override
  void readFrom(TarsInputStream _is) {
    type = readHuyaSignedInt(_is, 0, false);
    data = _is.readBytes(1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(type, 0);
    _os.write(data, 1);
  }

  @override
  Object deepCopy() {
    return HYItemEffectBizData()
      ..type = type
      ..data = Uint8List.fromList(data);
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYLiveRoomLargeConsumptionEffectNotice extends TarsStruct {
  int presenterUid = 0;
  int effectId = 0;
  int customerUid = 0;
  String customerNick = "";
  String customerAvatar = "";
  int recipientUid = 0;
  String recipientNick = "";
  String recipientAvatar = "";
  String itemName = "";
  Map<String, String> effectParams = <String, String>{};

  @override
  void readFrom(TarsInputStream _is) {
    // 仅检查关键字段确实存在；有效范围由 handler 校验，不以默认值虚构特效。
    presenterUid = readHuyaSignedInt(_is, 0, true);
    effectId = readHuyaSignedInt(_is, 1, true);
    customerUid = readHuyaSignedInt(_is, 2, true);
    customerNick = _is.read(customerNick, 3, false);
    customerAvatar = _is.read(customerAvatar, 4, false);
    recipientUid = readHuyaSignedInt(_is, 5, false);
    recipientNick = _is.read(recipientNick, 6, false);
    recipientAvatar = _is.read(recipientAvatar, 7, false);
    itemName = _is.read(itemName, 8, false);
    effectParams = readStringMap(_is, 9);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(presenterUid, 0);
    _os.write(effectId, 1);
    _os.write(customerUid, 2);
    _os.write(customerNick, 3);
    _os.write(customerAvatar, 4);
    _os.write(recipientUid, 5);
    _os.write(recipientNick, 6);
    _os.write(recipientAvatar, 7);
    _os.write(itemName, 8);
    _os.write(effectParams, 9);
  }

  @override
  Object deepCopy() {
    return HYLiveRoomLargeConsumptionEffectNotice()
      ..presenterUid = presenterUid
      ..effectId = effectId
      ..customerUid = customerUid
      ..customerNick = customerNick
      ..customerAvatar = customerAvatar
      ..recipientUid = recipientUid
      ..recipientNick = recipientNick
      ..recipientAvatar = recipientAvatar
      ..itemName = itemName
      ..effectParams = Map<String, String>.from(effectParams);
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

/// URI 6110 中携带的用户爵位信息。
///
/// 虎牙会直接下发本地化后的爵位名，例如“剑士”。无爵位用户的
/// [name] 为空且 [level] 为 0，调用方不应为其伪造通用爵位。
class HYNobleInfo extends TarsStruct {
  String name = "";
  int level = 0;

  @override
  void readFrom(TarsInputStream _is) {
    name = _is.read(name, 3, false);
    level = _is.read(level, 4, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(name, 3);
    _os.write(level, 4);
  }

  @override
  Object deepCopy() {
    return HYNobleInfo()
      ..name = name
      ..level = level;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

/// URI 6110: 当前网页使用的用户进场横幅。
class HYVipEnterBanner extends TarsStruct {
  int uid = 0;
  String nickName = "";
  int pid = 0;
  HYNobleInfo nobleInfo = HYNobleInfo();
  String logoUrl = "";

  @override
  void readFrom(TarsInputStream _is) {
    uid = _is.read(uid, 0, false);
    nickName = _is.read(nickName, 1, false);
    pid = _is.read(pid, 2, false);
    nobleInfo = _is.readTarsStruct(nobleInfo, 3, false) as HYNobleInfo;
    logoUrl = _is.read(logoUrl, 6, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(uid, 0);
    _os.write(nickName, 1);
    _os.write(pid, 2);
    _os.write(nobleInfo, 3);
    _os.write(logoUrl, 6);
  }

  @override
  Object deepCopy() {
    return HYVipEnterBanner()
      ..uid = uid
      ..nickName = nickName
      ..pid = pid
      ..nobleInfo = nobleInfo.deepCopy() as HYNobleInfo
      ..logoUrl = logoUrl;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYVipBarListRsp extends TarsStruct {
  int start = 0;
  int count = 0;
  int total = 0;
  List<HYVipBarItem> items = <HYVipBarItem>[];
  String badgeName = "";
  int changedHighestRank = 0;
  int pid = 0;
  String vLogo = "";
  int totalNum = 0;

  @override
  void readFrom(TarsInputStream _is) {
    start = _is.read(start, 1, false);
    count = _is.read(count, 2, false);
    total = _is.read(total, 3, false);
    items = _is.readList<HYVipBarItem>([HYVipBarItem()], 4, false);
    badgeName = _is.read(badgeName, 5, false);
    changedHighestRank = _is.read(changedHighestRank, 6, false);
    pid = _is.read(pid, 7, false);
    vLogo = _is.read(vLogo, 8, false);
    totalNum = _is.read(totalNum, 10, false);
  }

  int get displayTotal => totalNum > 0 ? totalNum : total;

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYVipBarListRsp()
      ..start = start
      ..count = count
      ..total = total
      ..items = items.map((e) => e.deepCopy() as HYVipBarItem).toList()
      ..badgeName = badgeName
      ..changedHighestRank = changedHighestRank
      ..pid = pid
      ..vLogo = vLogo
      ..totalNum = totalNum;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYVipBarItem extends TarsStruct {
  int uid = 0;
  int types = 0;
  String nickName = "";
  String logoUrl = "";
  int superPurpleLevel = 0;
  int userLevel = 0;

  @override
  void readFrom(TarsInputStream _is) {
    uid = _is.read(uid, 0, false);
    types = _is.read(types, 1, false);
    nickName = _is.read(nickName, 5, false);
    superPurpleLevel = _is.read(superPurpleLevel, 6, false);
    logoUrl = _is.read(logoUrl, 8, false);
    userLevel = _is.read(userLevel, 10, false);
  }

  Map<String, dynamic> toJson() => {
        "uid": uid,
        "nickName": nickName,
        "logoUrl": logoUrl,
        "types": types,
        "superPurpleLevel": superPurpleLevel,
        "userLevel": userLevel,
      };

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYVipBarItem()
      ..uid = uid
      ..types = types
      ..nickName = nickName
      ..logoUrl = logoUrl
      ..superPurpleLevel = superPurpleLevel
      ..userLevel = userLevel;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYVipBarListStatInfo extends TarsStruct {
  int pid = 0;
  int total = 0;

  @override
  void readFrom(TarsInputStream _is) {
    pid = _is.read(pid, 0, false);
    total = _is.read(total, 1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(pid, 0);
    _os.write(total, 1);
  }

  @override
  Object deepCopy() => HYVipBarListStatInfo()
    ..pid = pid
    ..total = total;

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYGetVipBarSimpleListRsp extends TarsStruct {
  int totalNum = 0;
  List<HYVipBarSimpleItem> items = <HYVipBarSimpleItem>[];

  @override
  void readFrom(TarsInputStream _is) {
    totalNum = _is.read(totalNum, 0, false);
    items = _is.readList<HYVipBarSimpleItem>(
      [HYVipBarSimpleItem()],
      1,
      false,
    );
  }

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYGetVipBarSimpleListRsp()
      ..totalNum = totalNum
      ..items = items.map((e) => e.deepCopy() as HYVipBarSimpleItem).toList();
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYVipBarSimpleItem extends TarsStruct {
  int uid = 0;
  String logoUrl = "";

  @override
  void readFrom(TarsInputStream _is) {
    uid = _is.read(uid, 0, false);
    logoUrl = _is.read(logoUrl, 1, false);
  }

  Map<String, dynamic> toJson() => {
        "uid": uid,
        "logoUrl": logoUrl,
      };

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() => HYVipBarSimpleItem()
    ..uid = uid
    ..logoUrl = logoUrl;

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYAttendeeCountNotice extends TarsStruct {
  int attendeeCount = 0;

  @override
  void readFrom(TarsInputStream _is) {
    attendeeCount = _is.read(attendeeCount, 0, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(attendeeCount, 0);
  }

  @override
  Object deepCopy() => HYAttendeeCountNotice()..attendeeCount = attendeeCount;

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

Map<String, String> readStringMap(TarsInputStream input, int tag) {
  try {
    return input.readMap<String, String>(
      <String, String>{"": ""},
      tag,
      false,
    );
  } catch (_) {
    return <String, String>{};
  }
}
