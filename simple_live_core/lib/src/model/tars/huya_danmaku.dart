// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:typed_data';

import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

class HYPushMessage extends TarsStruct {
  int pushType = 0;
  int uri = 0;
  List<int> msg = <int>[];
  int protocolType = 0;
  String groupId = "";
  int messageId = 0;
  int messageTag = 0;

  @override
  void readFrom(TarsInputStream _is) {
    pushType = _is.read(pushType, 0, false);
    uri = _is.read(uri, 1, false);
    msg = _is.readBytes(2, false);
    protocolType = _is.read(protocolType, 3, false);
    groupId = _is.read(groupId, 4, false);
    messageId = _is.read(messageId, 5, false);
    messageTag = _is.read(messageTag, 6, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(pushType, 0);
    _os.write(uri, 1);
    _os.write(Uint8List.fromList(msg), 2);
    _os.write(protocolType, 3);
    _os.write(groupId, 4);
    _os.write(messageId, 5);
    _os.write(messageTag, 6);
  }

  @override
  Object deepCopy() {
    return HYPushMessage()
      ..pushType = pushType
      ..uri = uri
      ..msg = List<int>.from(msg)
      ..protocolType = protocolType
      ..groupId = groupId
      ..messageId = messageId
      ..messageTag = messageTag;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYNobleLevelInfo extends TarsStruct {
  int nobleLevel = 0;
  int attrType = 0;

  @override
  void readFrom(TarsInputStream _is) {
    nobleLevel = _is.read(nobleLevel, 0, false);
    attrType = _is.read(attrType, 1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(nobleLevel, 0);
    _os.write(attrType, 1);
  }

  @override
  Object deepCopy() {
    return HYNobleLevelInfo()
      ..nobleLevel = nobleLevel
      ..attrType = attrType;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYSender extends TarsStruct {
  int uid = 0;
  int lMid = 0;
  String nickName = "";
  int gender = 0;
  String avatarUrl = "";
  int nobleLevel = 0;
  HYNobleLevelInfo nobleLevelInfo = HYNobleLevelInfo();
  String guid = "";
  String huyaUa = "";
  int userType = 0;

  @override
  void readFrom(TarsInputStream _is) {
    uid = _is.read(uid, 0, false);
    lMid = _is.read(lMid, 1, false);
    nickName = _is.read(nickName, 2, false);
    gender = _is.read(gender, 3, false);
    avatarUrl = _is.read(avatarUrl, 4, false);
    nobleLevel = _is.read(nobleLevel, 5, false);
    nobleLevelInfo =
        _is.readTarsStruct(nobleLevelInfo, 6, false) as HYNobleLevelInfo;
    guid = _is.read(guid, 7, false);
    huyaUa = _is.read(huyaUa, 8, false);
    userType = _is.read(userType, 9, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(uid, 0);
    _os.write(lMid, 1);
    _os.write(nickName, 2);
    _os.write(gender, 3);
    _os.write(avatarUrl, 4);
    _os.write(nobleLevel, 5);
    _os.write(nobleLevelInfo, 6);
    _os.write(guid, 7);
    _os.write(huyaUa, 8);
    _os.write(userType, 9);
  }

  @override
  Object deepCopy() {
    return HYSender()
      ..uid = uid
      ..lMid = lMid
      ..nickName = nickName
      ..gender = gender
      ..avatarUrl = avatarUrl
      ..nobleLevel = nobleLevel
      ..nobleLevelInfo = nobleLevelInfo.deepCopy() as HYNobleLevelInfo
      ..guid = guid
      ..huyaUa = huyaUa
      ..userType = userType;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYContentFormat extends TarsStruct {
  int fontColor = 0;
  int fontSize = 4;
  int popupStyle = 0;

  @override
  void readFrom(TarsInputStream _is) {
    fontColor = _is.read(fontColor, 0, false);
    fontSize = _is.read(fontSize, 1, false);
    popupStyle = _is.read(popupStyle, 2, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(fontColor, 0);
    _os.write(fontSize, 1);
    _os.write(popupStyle, 2);
  }

  @override
  Object deepCopy() {
    return HYContentFormat()
      ..fontColor = fontColor
      ..fontSize = fontSize
      ..popupStyle = popupStyle;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYDecorationInfo extends TarsStruct {
  int appId = 0;
  int viewType = 0;
  Uint8List data = Uint8List(0);

  @override
  void readFrom(TarsInputStream _is) {
    appId = _is.read(appId, 0, false);
    viewType = _is.read(viewType, 1, false);
    data = _is.readBytes(2, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(appId, 0);
    _os.write(viewType, 1);
    _os.write(data, 2);
  }

  @override
  Object deepCopy() {
    return HYDecorationInfo()
      ..appId = appId
      ..viewType = viewType
      ..data = Uint8List.fromList(data);
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

/// MessageNotice 的 appId 10400 前缀数据。
///
/// 真机协议样本中 tag 1/3/4 分别为粉丝牌 ID、名称与等级；
/// 其余视觉字段保持由 TARS 跳过，避免把协议装饰细节耦合进业务模型。
class HYFansBadgeInfo extends TarsStruct {
  int badgeId = 0;
  String badgeName = "";
  int badgeLevel = 0;

  @override
  void readFrom(TarsInputStream _is) {
    badgeId = _is.read(badgeId, 1, false);
    badgeName = _is.read(badgeName, 3, false);
    badgeLevel = _is.read(badgeLevel, 4, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(badgeId, 1);
    _os.write(badgeName, 3);
    _os.write(badgeLevel, 4);
  }

  @override
  Object deepCopy() {
    return HYFansBadgeInfo()
      ..badgeId = badgeId
      ..badgeName = badgeName
      ..badgeLevel = badgeLevel;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

/// 旧版 MessageNotice appId 10200 装饰中的爵位基础信息。
///
/// 这里只读取 UI 所需的 tag 2/3；其它历史字段由 TARS 安全跳过。
class HYLegacyNobleBase extends TarsStruct {
  int level = 0;
  String name = "";

  @override
  void readFrom(TarsInputStream _is) {
    level = _is.read(level, 2, false);
    name = _is.read(name, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(level, 2);
    _os.write(name, 3);
  }

  @override
  Object deepCopy() {
    return HYLegacyNobleBase()
      ..level = level
      ..name = name;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYUidNickName extends TarsStruct {
  int uid = 0;
  String nickName = "";

  @override
  void readFrom(TarsInputStream _is) {
    uid = _is.read(uid, 0, false);
    nickName = _is.read(nickName, 1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(uid, 0);
    _os.write(nickName, 1);
  }

  @override
  Object deepCopy() {
    return HYUidNickName()
      ..uid = uid
      ..nickName = nickName;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYMessage extends TarsStruct {
  HYSender userInfo = HYSender();
  int tid = 0;
  int sid = 0;
  String content = "";
  int showMode = 0;
  HYContentFormat contentFormat = HYContentFormat();
  HYBulletFormat bulletFormat = HYBulletFormat();
  int termType = 0;
  List<HYDecorationInfo> decorationPrefix = <HYDecorationInfo>[];
  List<HYDecorationInfo> decorationSuffix = <HYDecorationInfo>[];
  List<HYUidNickName> atSomeone = <HYUidNickName>[];
  int pid = 0;
  List<HYDecorationInfo> bulletPrefix = <HYDecorationInfo>[];
  String iconUrl = "";
  int type = 0;
  List<HYDecorationInfo> bulletSuffix = <HYDecorationInfo>[];

  @override
  void readFrom(TarsInputStream _is) {
    userInfo = _is.readTarsStruct(userInfo, 0, false) as HYSender;
    tid = _is.read(tid, 1, false);
    sid = _is.read(sid, 2, false);
    content = _is.read(content, 3, false);
    showMode = _is.read(showMode, 4, false);
    contentFormat =
        _is.readTarsStruct(contentFormat, 5, false) as HYContentFormat;
    bulletFormat = _is.readTarsStruct(bulletFormat, 6, false) as HYBulletFormat;
    termType = _is.read(termType, 7, false);
    decorationPrefix = _is.readList<HYDecorationInfo>(
      <HYDecorationInfo>[HYDecorationInfo()],
      8,
      false,
    );
    decorationSuffix = _is.readList<HYDecorationInfo>(
      <HYDecorationInfo>[HYDecorationInfo()],
      9,
      false,
    );
    atSomeone = _is.readList<HYUidNickName>(
      <HYUidNickName>[HYUidNickName()],
      10,
      false,
    );
    pid = _is.read(pid, 11, false);
    bulletPrefix = _is.readList<HYDecorationInfo>(
      <HYDecorationInfo>[HYDecorationInfo()],
      12,
      false,
    );
    iconUrl = _is.read(iconUrl, 13, false);
    type = _is.read(type, 14, false);
    bulletSuffix = _is.readList<HYDecorationInfo>(
      <HYDecorationInfo>[HYDecorationInfo()],
      15,
      false,
    );
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(userInfo, 0);
    _os.write(tid, 1);
    _os.write(sid, 2);
    _os.write(content, 3);
    _os.write(showMode, 4);
    _os.write(contentFormat, 5);
    _os.write(bulletFormat, 6);
    _os.write(termType, 7);
    _os.write(decorationPrefix, 8);
    _os.write(decorationSuffix, 9);
    _os.write(atSomeone, 10);
    _os.write(pid, 11);
    _os.write(bulletPrefix, 12);
    _os.write(iconUrl, 13);
    _os.write(type, 14);
    _os.write(bulletSuffix, 15);
  }

  @override
  Object deepCopy() {
    return HYMessage()
      ..userInfo = userInfo.deepCopy() as HYSender
      ..tid = tid
      ..sid = sid
      ..content = content
      ..showMode = showMode
      ..contentFormat = contentFormat.deepCopy() as HYContentFormat
      ..bulletFormat = bulletFormat.deepCopy() as HYBulletFormat
      ..termType = termType
      ..decorationPrefix = decorationPrefix
          .map((item) => item.deepCopy() as HYDecorationInfo)
          .toList()
      ..decorationSuffix = decorationSuffix
          .map((item) => item.deepCopy() as HYDecorationInfo)
          .toList()
      ..atSomeone =
          atSomeone.map((item) => item.deepCopy() as HYUidNickName).toList()
      ..pid = pid
      ..bulletPrefix = bulletPrefix
          .map((item) => item.deepCopy() as HYDecorationInfo)
          .toList()
      ..iconUrl = iconUrl
      ..type = type
      ..bulletSuffix = bulletSuffix
          .map((item) => item.deepCopy() as HYDecorationInfo)
          .toList();
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYBulletFormat extends TarsStruct {
  int fontColor = 0;
  int fontSize = 4;
  int textSpeed = 0;
  int transitionType = 1;
  int popupStyle = 0;

  @override
  void readFrom(TarsInputStream _is) {
    fontColor = _is.read(fontColor, 0, false);
    fontSize = _is.read(fontSize, 1, false);
    textSpeed = _is.read(textSpeed, 2, false);
    transitionType = _is.read(transitionType, 3, false);
    popupStyle = _is.read(popupStyle, 4, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(fontColor, 0);
    _os.write(fontSize, 1);
    _os.write(textSpeed, 2);
    _os.write(transitionType, 3);
    _os.write(popupStyle, 4);
  }

  @override
  Object deepCopy() {
    return HYBulletFormat()
      ..fontColor = fontColor
      ..fontSize = fontSize
      ..textSpeed = textSpeed
      ..transitionType = transitionType
      ..popupStyle = popupStyle;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYGiftNotice extends TarsStruct {
  int lSenderUid = 0;
  int lSenderUid2 = 0;
  String sSenderNick = "";
  int lPresenterUid = 0;
  int lPresenterUid2 = 0;
  String sPresenterNick = "";
  int iGiftId = 0;
  String sGiftName = "";
  int iGiftCount = 0;
  int iCombo = 0;
  int iSlot = 0;
  int iItemType = 0;
  int iPrice = 0;

  @override
  void readFrom(TarsInputStream _is) {
    lSenderUid = _is.read(lSenderUid, 0, false);
    lSenderUid2 = _is.read(lSenderUid2, 1, false);
    sSenderNick = _is.read(sSenderNick, 3, false);
    lPresenterUid = _is.read(lPresenterUid, 4, false);
    lPresenterUid2 = _is.read(lPresenterUid2, 5, false);
    sPresenterNick = _is.read(sPresenterNick, 6, false);
    iGiftId = _is.read(iGiftId, 7, false);
    sGiftName = _is.read(sGiftName, 8, false);
    iGiftCount = _is.read(iGiftCount, 9, false);
    iCombo = _is.read(iCombo, 10, false);
    iSlot = _is.read(iSlot, 11, false);
    iItemType = _is.read(iItemType, 12, false);
    iPrice = _is.read(iPrice, 13, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYGiftNotice()
      ..lSenderUid = lSenderUid
      ..lSenderUid2 = lSenderUid2
      ..sSenderNick = sSenderNick
      ..lPresenterUid = lPresenterUid
      ..lPresenterUid2 = lPresenterUid2
      ..sPresenterNick = sPresenterNick
      ..iGiftId = iGiftId
      ..sGiftName = sGiftName
      ..iGiftCount = iGiftCount
      ..iCombo = iCombo
      ..iSlot = iSlot
      ..iItemType = iItemType
      ..iPrice = iPrice;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYVipEnterNotice extends TarsStruct {
  int lUid = 0;
  int lUid2 = 0;
  String sNickName = "";
  int iBadgeType = 0;

  @override
  void readFrom(TarsInputStream _is) {
    lUid = _is.read(lUid, 0, false);
    lUid2 = _is.read(lUid2, 1, false);
    sNickName = _is.read(sNickName, 2, false);
    iBadgeType = _is.read(iBadgeType, 5, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYVipEnterNotice()
      ..lUid = lUid
      ..lUid2 = lUid2
      ..sNickName = sNickName
      ..iBadgeType = iBadgeType;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}
