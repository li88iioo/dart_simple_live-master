// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

class HYPushMessage extends TarsStruct {
  int pushType = 0;
  int uri = 0;
  List<int> msg = <int>[];
  int protocolType = 0;

  @override
  void readFrom(TarsInputStream _is) {
    pushType = _is.read(pushType, 0, false);
    uri = _is.read(uri, 1, false);
    msg = _is.readBytes(2, false);
    protocolType = _is.read(protocolType, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYPushMessage()
      ..pushType = pushType
      ..uri = uri
      ..msg = List<int>.from(msg)
      ..protocolType = protocolType;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYSender extends TarsStruct {
  int uid = 0;
  int lMid = 0;
  String nickName = "";
  int gender = 0;

  @override
  void readFrom(TarsInputStream _is) {
    uid = _is.read(uid, 0, false);
    lMid = _is.read(lMid, 0, false);
    nickName = _is.read(nickName, 2, false);
    gender = _is.read(gender, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYSender()
      ..uid = uid
      ..lMid = lMid
      ..nickName = nickName
      ..gender = gender;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYMessage extends TarsStruct {
  HYSender userInfo = HYSender();
  String content = "";
  HYBulletFormat bulletFormat = HYBulletFormat();

  @override
  void readFrom(TarsInputStream _is) {
    userInfo = _is.readTarsStruct(userInfo, 0, false) as HYSender;
    content = _is.read(content, 3, false);
    bulletFormat = _is.readTarsStruct(bulletFormat, 6, false) as HYBulletFormat;
  }

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYMessage()
      ..userInfo = userInfo.deepCopy() as HYSender
      ..content = content
      ..bulletFormat = bulletFormat.deepCopy() as HYBulletFormat;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYBulletFormat extends TarsStruct {
  int fontColor = 0;
  int fontSize = 4;
  int textSpeed = 0;
  int transitionType = 1;

  @override
  void readFrom(TarsInputStream _is) {
    fontColor = _is.read(fontColor, 0, false);
    fontSize = _is.read(fontSize, 1, false);
    textSpeed = _is.read(textSpeed, 2, false);
    transitionType = _is.read(transitionType, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYBulletFormat()
      ..fontColor = fontColor
      ..fontSize = fontSize
      ..textSpeed = textSpeed
      ..transitionType = transitionType;
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
    sSenderNick = _is.read(sSenderNick, 2, false);
    lPresenterUid = _is.read(lPresenterUid, 3, false);
    lPresenterUid2 = _is.read(lPresenterUid2, 4, false);
    sPresenterNick = _is.read(sPresenterNick, 5, false);
    iGiftId = _is.read(iGiftId, 6, false);
    sGiftName = _is.read(sGiftName, 7, false);
    iGiftCount = _is.read(iGiftCount, 8, false);
    iCombo = _is.read(iCombo, 9, false);
    iSlot = _is.read(iSlot, 10, false);
    iItemType = _is.read(iItemType, 11, false);
    iPrice = _is.read(iPrice, 12, false);
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
