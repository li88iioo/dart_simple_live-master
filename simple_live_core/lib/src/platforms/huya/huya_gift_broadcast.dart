// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

import 'huya_hysignal.dart';
import 'huya_tars_utils.dart';

// 兼容网页的独立广播结构；不能把广播 URI 改成 6501 后复用其解码器。
// 协议字段来源与跨实现编码回放见 test/platforms/huya/fixtures/README.md。

/// URI 6502：文字广播。tag 1 为数量，tag 5 才是收礼主播 UID。
class HYSendItemNoticeWordBroadcastPacket extends TarsStruct {
  int itemType = 0;
  int itemCount = 0;
  int senderSid = 0;
  int senderUid = 0;
  String senderNick = "";
  int presenterUid = 0;
  String presenterNick = "";
  int noticeChannelCount = 0;
  int itemCountByGroup = 0;
  int itemGroup = 0;
  int displayInfo = 0;
  int superPurpleLevel = 0;
  int templateType = 0;
  String expand = "";
  bool business = false;
  int showTime = 0;
  int presenterYy = 0;
  int sid = 0;
  int subSid = 0;
  int roomId = 0;
  int nobleLevel = 0;
  int upgradeLevel = 0;
  List<HYItemEffectBizData> bizData = <HYItemEffectBizData>[];

  @override
  void readFrom(TarsInputStream _is) {
    itemType = readHuyaSignedInt(_is, 0, true);
    itemCount = readHuyaSignedInt(_is, 1, true);
    senderSid = readHuyaSignedInt(_is, 2, false);
    senderUid = readHuyaSignedInt(_is, 3, true);
    senderNick = _is.read(senderNick, 4, false);
    presenterUid = readHuyaSignedInt(_is, 5, true);
    presenterNick = _is.read(presenterNick, 6, false);
    noticeChannelCount = readHuyaSignedInt(_is, 7, false);
    itemCountByGroup = readHuyaSignedInt(_is, 8, false);
    itemGroup = readHuyaSignedInt(_is, 9, false);
    displayInfo = readHuyaSignedInt(_is, 10, false);
    superPurpleLevel = readHuyaSignedInt(_is, 11, false);
    templateType = readHuyaSignedInt(_is, 12, false);
    expand = _is.read(expand, 13, false);
    business = _is.read(business, 14, false);
    showTime = readHuyaSignedInt(_is, 15, false);
    presenterYy = readHuyaSignedInt(_is, 16, false);
    sid = readHuyaSignedInt(_is, 17, false);
    subSid = readHuyaSignedInt(_is, 18, false);
    roomId = readHuyaSignedInt(_is, 19, false);
    nobleLevel = readHuyaSignedInt(_is, 20, false);
    upgradeLevel = readHuyaSignedInt(_is, 23, false);
    bizData =
        _is.readList<HYItemEffectBizData>([HYItemEffectBizData()], 25, false);
  }

  /// 只在独立解码完成后标准化事实字段；不构造支付号或伪造礼物名。
  HYSendItemSubBroadcastPacket toGift() {
    return HYSendItemSubBroadcastPacket()
      ..itemType = itemType
      ..itemCount = itemCount
      ..senderUid = senderUid
      ..senderNick = senderNick
      ..presenterUid = presenterUid
      ..presenterNick = presenterNick
      ..itemCountByGroup = itemCountByGroup
      ..itemGroup = itemGroup
      ..displayInfo = displayInfo
      ..superPurpleLevel = superPurpleLevel
      ..templateType = templateType
      ..expand = expand
      ..business = business
      ..roomId = roomId
      ..nobleLevel = nobleLevel
      ..upgradeLevel = upgradeLevel
      ..bizData = bizData;
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(itemType, 0);
    _os.write(itemCount, 1);
    _os.write(senderSid, 2);
    _os.write(senderUid, 3);
    _os.write(senderNick, 4);
    _os.write(presenterUid, 5);
    _os.write(presenterNick, 6);
    _os.write(noticeChannelCount, 7);
    _os.write(itemCountByGroup, 8);
    _os.write(itemGroup, 9);
    _os.write(displayInfo, 10);
    _os.write(superPurpleLevel, 11);
    _os.write(templateType, 12);
    _os.write(expand, 13);
    _os.write(business, 14);
    _os.write(showTime, 15);
    _os.write(presenterYy, 16);
    _os.write(sid, 17);
    _os.write(subSid, 18);
    _os.write(roomId, 19);
    _os.write(nobleLevel, 20);
    _os.write(upgradeLevel, 23);
    _os.write(bizData, 25);
  }

  @override
  Object deepCopy() {
    return HYSendItemNoticeWordBroadcastPacket()
      ..itemType = itemType
      ..itemCount = itemCount
      ..senderSid = senderSid
      ..senderUid = senderUid
      ..senderNick = senderNick
      ..presenterUid = presenterUid
      ..presenterNick = presenterNick
      ..noticeChannelCount = noticeChannelCount
      ..itemCountByGroup = itemCountByGroup
      ..itemGroup = itemGroup
      ..displayInfo = displayInfo
      ..superPurpleLevel = superPurpleLevel
      ..templateType = templateType
      ..expand = expand
      ..business = business
      ..showTime = showTime
      ..presenterYy = presenterYy
      ..sid = sid
      ..subSid = subSid
      ..roomId = roomId
      ..nobleLevel = nobleLevel
      ..upgradeLevel = upgradeLevel
      ..bizData =
          bizData.map((e) => e.deepCopy() as HYItemEffectBizData).toList();
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

/// URI 6507：游戏区广播。tag 2 未定义；tag 3 为送礼用户，非收礼主播。
class HYSendItemNoticeGameBroadcastPacket extends TarsStruct {
  int itemType = 0;
  int itemCount = 0;
  int senderUid = 0;
  String senderNick = "";
  int presenterUid = 0;
  String presenterNick = "";
  int sid = 0;
  int subSid = 0;
  int roomId = 0;
  int templateType = 0;

  @override
  void readFrom(TarsInputStream _is) {
    itemType = readHuyaSignedInt(_is, 0, true);
    itemCount = readHuyaSignedInt(_is, 1, true);
    senderUid = readHuyaSignedInt(_is, 3, true);
    senderNick = _is.read(senderNick, 4, false);
    presenterUid = readHuyaSignedInt(_is, 5, true);
    presenterNick = _is.read(presenterNick, 6, false);
    sid = readHuyaSignedInt(_is, 7, false);
    subSid = readHuyaSignedInt(_is, 8, false);
    roomId = readHuyaSignedInt(_is, 9, false);
    templateType = readHuyaSignedInt(_is, 10, false);
  }

  /// 只在独立解码完成后标准化事实字段；不构造支付号或伪造礼物名。
  HYSendItemSubBroadcastPacket toGift() {
    return HYSendItemSubBroadcastPacket()
      ..itemType = itemType
      ..itemCount = itemCount
      ..senderUid = senderUid
      ..senderNick = senderNick
      ..presenterUid = presenterUid
      ..presenterNick = presenterNick
      ..roomId = roomId
      ..templateType = templateType;
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(itemType, 0);
    _os.write(itemCount, 1);
    _os.write(senderUid, 3);
    _os.write(senderNick, 4);
    _os.write(presenterUid, 5);
    _os.write(presenterNick, 6);
    _os.write(sid, 7);
    _os.write(subSid, 8);
    _os.write(roomId, 9);
    _os.write(templateType, 10);
  }

  @override
  Object deepCopy() {
    return HYSendItemNoticeGameBroadcastPacket()
      ..itemType = itemType
      ..itemCount = itemCount
      ..senderUid = senderUid
      ..senderNick = senderNick
      ..presenterUid = presenterUid
      ..presenterNick = presenterNick
      ..sid = sid
      ..subSid = subSid
      ..roomId = roomId
      ..templateType = templateType;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYSendItemActivityNoticeBroadcastPacket extends TarsStruct {
  int effectId = 0;
  int sid = 0;
  int subSid = 0;
  int senderUid = 0;
  int presenterUid = 0;
  String senderNick = '';
  String presenterNick = '';
  String effectUrl = '';
  int frames = 0;

  @override
  void readFrom(TarsInputStream _is) {
    effectId = readHuyaSignedInt(_is, 0, false);
    sid = readHuyaSignedInt(_is, 1, false);
    subSid = readHuyaSignedInt(_is, 2, false);
    senderUid = readHuyaSignedInt(_is, 3, true);
    presenterUid = readHuyaSignedInt(_is, 4, true);
    senderNick = _is.read(senderNick, 5, false);
    presenterNick = _is.read(presenterNick, 6, false);
    effectUrl = _is.read(effectUrl, 7, false);
    frames = readHuyaSignedInt(_is, 8, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(effectId, 0);
    _os.write(sid, 1);
    _os.write(subSid, 2);
    _os.write(senderUid, 3);
    _os.write(presenterUid, 4);
    _os.write(senderNick, 5);
    _os.write(presenterNick, 6);
    _os.write(effectUrl, 7);
    _os.write(frames, 8);
  }

  @override
  Object deepCopy() => HYSendItemActivityNoticeBroadcastPacket()
    ..effectId = effectId
    ..sid = sid
    ..subSid = subSid
    ..senderUid = senderUid
    ..presenterUid = presenterUid
    ..senderNick = senderNick
    ..presenterNick = presenterNick
    ..effectUrl = effectUrl
    ..frames = frames;

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYGiftItemCount extends TarsStruct {
  int itemType = 0;
  int itemCount = 0;

  @override
  void readFrom(TarsInputStream _is) {
    itemType = readHuyaSignedInt(_is, 0, true);
    itemCount = readHuyaSignedInt(_is, 1, true);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(itemType, 0);
    _os.write(itemCount, 1);
  }

  @override
  Object deepCopy() => HYGiftItemCount()
    ..itemType = itemType
    ..itemCount = itemCount;

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

/// URI 6514：绘图礼物，一次交易可以包含多个 ItemCount；tag 2 不存在。
class HYSendItemOtherBroadcastPacket extends TarsStruct {
  int senderUid = 0;
  int presenterUid = 0;
  int payTime = 0;
  String payId = '';
  String senderNick = '';
  String presenterNick = '';
  String senderAvatar = '';
  List<HYGiftItemCount> items = <HYGiftItemCount>[];

  @override
  void readFrom(TarsInputStream _is) {
    senderUid = readHuyaSignedInt(_is, 0, true);
    presenterUid = readHuyaSignedInt(_is, 1, true);
    payTime = readHuyaSignedInt(_is, 3, false);
    payId = _is.read(payId, 4, false);
    senderNick = _is.read(senderNick, 5, false);
    presenterNick = _is.read(presenterNick, 6, false);
    senderAvatar = _is.read(senderAvatar, 7, false);
    items = _is.readList<HYGiftItemCount>([HYGiftItemCount()], 8, true);
    // vItemRoute / tItemSize 是绘图位置，不是额外的送礼数量。
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(senderUid, 0);
    _os.write(presenterUid, 1);
    _os.write(payTime, 3);
    _os.write(payId, 4);
    _os.write(senderNick, 5);
    _os.write(presenterNick, 6);
    _os.write(senderAvatar, 7);
    _os.write(items, 8);
  }

  @override
  Object deepCopy() => HYSendItemOtherBroadcastPacket()
    ..senderUid = senderUid
    ..presenterUid = presenterUid
    ..payTime = payTime
    ..payId = payId
    ..senderNick = senderNick
    ..presenterNick = presenterNick
    ..senderAvatar = senderAvatar
    ..items = items.map((e) => e.deepCopy() as HYGiftItemCount).toList();

  @override
  void displayAsString(StringBuffer sb, int level) {}
}
