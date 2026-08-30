// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

/// 虎牙 WUP 请求中的匿名用户信息。
class HYUserId extends TarsStruct {
  int uid = 0;
  String guid = "";
  String token = "";
  String huyaUa = "";
  String cookie = "";
  int tokenType = 0;
  String deviceInfo = "";
  String qimei = "";

  @override
  void readFrom(TarsInputStream _is) {
    uid = _is.read(uid, 0, false);
    guid = _is.read(guid, 1, false);
    token = _is.read(token, 2, false);
    huyaUa = _is.read(huyaUa, 3, false);
    cookie = _is.read(cookie, 4, false);
    tokenType = _is.read(tokenType, 5, false);
    deviceInfo = _is.read(deviceInfo, 6, false);
    qimei = _is.read(qimei, 7, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(uid, 0);
    _os.write(guid, 1);
    _os.write(token, 2);
    _os.write(huyaUa, 3);
    _os.write(cookie, 4);
    _os.write(tokenType, 5);
    _os.write(deviceInfo, 6);
    _os.write(qimei, 7);
  }

  @override
  Object deepCopy() {
    return HYUserId()
      ..uid = uid
      ..guid = guid
      ..token = token
      ..huyaUa = huyaUa
      ..cookie = cookie
      ..tokenType = tokenType
      ..deviceInfo = deviceInfo
      ..qimei = qimei;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

/// PropsUIServer.getPropsList 请求。
class HYGetPropsListReq extends TarsStruct {
  HYUserId userId = HYUserId();
  String md5 = "";
  int templateType = 32;
  String version = "";
  int appId = 0;
  int presenterUid = 0;
  int sid = 0;
  int subSid = 0;
  int gameId = 0;

  @override
  void readFrom(TarsInputStream _is) {
    userId = _is.readTarsStruct(userId, 1, false) as HYUserId;
    md5 = _is.read(md5, 2, false);
    templateType = _is.read(templateType, 3, false);
    version = _is.read(version, 4, false);
    appId = _is.read(appId, 5, false);
    presenterUid = _is.read(presenterUid, 6, false);
    sid = _is.read(sid, 7, false);
    subSid = _is.read(subSid, 8, false);
    gameId = _is.read(gameId, 9, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(userId, 1);
    _os.write(md5, 2);
    _os.write(templateType, 3);
    _os.write(version, 4);
    _os.write(appId, 5);
    _os.write(presenterUid, 6);
    _os.write(sid, 7);
    _os.write(subSid, 8);
    _os.write(gameId, 9);
  }

  @override
  Object deepCopy() {
    return HYGetPropsListReq()
      ..userId = userId.deepCopy() as HYUserId
      ..md5 = md5
      ..templateType = templateType
      ..version = version
      ..appId = appId
      ..presenterUid = presenterUid
      ..sid = sid
      ..subSid = subSid
      ..gameId = gameId;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

/// 礼物目录中当前功能需要的可信字段。
class HYPropsItem extends TarsStruct {
  int propsId = 0;
  String propsName = "";
  int propsYb = 0;
  int templateType = 0;
  int shelfStatus = 0;

  @override
  void readFrom(TarsInputStream _is) {
    propsId = _is.read(propsId, 1, false);
    propsName = _is.read(propsName, 2, false);
    propsYb = _is.read(propsYb, 3, false);
    templateType = _is.read(templateType, 26, false);
    shelfStatus = _is.read(shelfStatus, 27, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(propsId, 1);
    _os.write(propsName, 2);
    _os.write(propsYb, 3);
    _os.write(templateType, 26);
    _os.write(shelfStatus, 27);
  }

  @override
  Object deepCopy() {
    return HYPropsItem()
      ..propsId = propsId
      ..propsName = propsName
      ..propsYb = propsYb
      ..templateType = templateType
      ..shelfStatus = shelfStatus;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

/// PropsUIServer.getPropsList 响应。
class HYGetPropsListRsp extends TarsStruct {
  List<HYPropsItem> items = <HYPropsItem>[];
  String md5 = "";
  int newEffectSwitch = 0;
  int mirrorRoomShowNum = 0;
  int gameRoomShowNum = 0;

  @override
  void readFrom(TarsInputStream _is) {
    items = _is.readList<HYPropsItem>([HYPropsItem()], 1, false);
    md5 = _is.read(md5, 2, false);
    newEffectSwitch = _is.read(newEffectSwitch, 3, false);
    mirrorRoomShowNum = _is.read(mirrorRoomShowNum, 4, false);
    gameRoomShowNum = _is.read(gameRoomShowNum, 5, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(items, 1);
    _os.write(md5, 2);
    _os.write(newEffectSwitch, 3);
    _os.write(mirrorRoomShowNum, 4);
    _os.write(gameRoomShowNum, 5);
  }

  @override
  Object deepCopy() {
    return HYGetPropsListRsp()
      ..items = items.map((e) => e.deepCopy() as HYPropsItem).toList()
      ..md5 = md5
      ..newEffectSwitch = newEffectSwitch
      ..mirrorRoomShowNum = mirrorRoomShowNum
      ..gameRoomShowNum = gameRoomShowNum;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}
