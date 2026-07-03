// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:typed_data';

import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

class HuyaHySignalCommandType {
  const HuyaHySignalCommandType._();

  static const int pushMessage = 7;
  static const int pushMessageV2 = 22;
}

class HuyaPushUri {
  const HuyaPushUri._();

  static const int vipBarList = 6210;
  static const int vipBarCount = 6211;
  static const int vipBarSimpleList = 6213;
  static const int giftSubChannel = 6501;
  static const int giftTopChannel = 6502;
  static const int giftGameBroadcast = 6507;
  static const int giftOtherBroadcast = 6514;
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
  void writeTo(TarsOutputStream _os) {}

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
  void writeTo(TarsOutputStream _os) {}

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
    itemType = _is.read(itemType, 0, false);
    payId = _is.read(payId, 1, false);
    itemCount = _is.read(itemCount, 2, false);
    presenterUid = _is.read(presenterUid, 3, false);
    senderUid = _is.read(senderUid, 4, false);
    presenterNick = _is.read(presenterNick, 5, false);
    senderNick = _is.read(senderNick, 6, false);
    sendContent = _is.read(sendContent, 7, false);
    itemCountByGroup = _is.read(itemCountByGroup, 8, false);
    itemGroup = _is.read(itemGroup, 9, false);
    superPurpleLevel = _is.read(superPurpleLevel, 10, false);
    comboScore = _is.read(comboScore, 11, false);
    displayInfo = _is.read(displayInfo, 12, false);
    effectType = _is.read(effectType, 13, false);
    senderIcon = _is.read(senderIcon, 14, false);
    presenterIcon = _is.read(presenterIcon, 15, false);
    templateType = _is.read(templateType, 16, false);
    expand = _is.read(expand, 17, false);
    business = _is.read(business, 18, false);
    colorEffectType = _is.read(colorEffectType, 19, false);
    propsName = _is.read(propsName, 20, false);
    accept = _is.read(accept, 21, false);
    eventType = _is.read(eventType, 22, false);
    roomId = _is.read(roomId, 24, false);
    homeOwnerUid = _is.read(homeOwnerUid, 25, false);
    payType = _is.read(payType, 27, false);
    nobleLevel = _is.read(nobleLevel, 28, false);
    effectInfo = _is.readTarsStruct(
      effectInfo,
      30,
      false,
    ) as HYItemEffectInfo;
    comboStatus = _is.read(comboStatus, 32, false);
    pidColorType = _is.read(pidColorType, 33, false);
    multiSend = _is.read(multiSend, 34, false);
    vFanLevel = _is.read(vFanLevel, 35, false);
    upgradeLevel = _is.read(upgradeLevel, 36, false);
    customText = _is.read(customText, 37, false);
    diyEffect = _is.readTarsStruct(
      diyEffect,
      38,
      false,
    ) as HYDIYBigGiftEffect;
    comboSeqId = _is.read(comboSeqId, 39, false);
    payTotal = _is.read(payTotal, 41, false);
    bizData = _is.readList<HYItemEffectBizData>(
      [HYItemEffectBizData()],
      42,
      false,
    );
  }

  @override
  void writeTo(TarsOutputStream _os) {}

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
      ..bizData = bizData
          .map((e) => e.deepCopy() as HYItemEffectBizData)
          .toList();
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
    priceLevel = _is.read(priceLevel, 0, false);
    streamDuration = _is.read(streamDuration, 1, false);
    showType = _is.read(showType, 2, false);
    streamId = _is.read(streamId, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}

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
  void writeTo(TarsOutputStream _os) {}

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
    type = _is.read(type, 0, false);
    data = _is.readBytes(1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}

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
    presenterUid = _is.read(presenterUid, 0, false);
    effectId = _is.read(effectId, 1, false);
    customerUid = _is.read(customerUid, 2, false);
    customerNick = _is.read(customerNick, 3, false);
    customerAvatar = _is.read(customerAvatar, 4, false);
    recipientUid = _is.read(recipientUid, 5, false);
    recipientNick = _is.read(recipientNick, 6, false);
    recipientAvatar = _is.read(recipientAvatar, 7, false);
    itemName = _is.read(itemName, 8, false);
    effectParams = readStringMap(_is, 9);
  }

  @override
  void writeTo(TarsOutputStream _os) {}

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
  void writeTo(TarsOutputStream _os) {}

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
      ..items = items
          .map((e) => e.deepCopy() as HYVipBarSimpleItem)
          .toList();
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
  void writeTo(TarsOutputStream _os) {}

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
