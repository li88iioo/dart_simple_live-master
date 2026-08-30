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

/// 虎牙礼物目录中的视觉资源描述。
///
/// 字段 tag 与网页端 PropsIdentity Tars 定义保持一致；这里只解析 App
/// 展示真实礼物图标与轻量特效所需的资源，未知字段由 Tars 解码器跳过。
class HYPropsIdentity extends TarsStruct {
  int propsIdType = 0;
  String propsPic18 = "";
  String propsPic24 = "";
  String propsPicGif = "";
  String propsBannerResource = "";
  String propsChatBannerResource = "";
  String propH5Resource = "";
  String propsWeb = "";
  String propStreamerResource = "";
  String propsPic108 = "";
  String pcBannerResource = "";

  @override
  void readFrom(TarsInputStream _is) {
    propsIdType = _is.read(propsIdType, 1, false);
    propsPic18 = _is.read(propsPic18, 2, false);
    propsPic24 = _is.read(propsPic24, 3, false);
    propsPicGif = _is.read(propsPicGif, 4, false);
    propsBannerResource = _is.read(propsBannerResource, 5, false);
    propsChatBannerResource = _is.read(propsChatBannerResource, 8, false);
    propH5Resource = _is.read(propH5Resource, 16, false);
    propsWeb = _is.read(propsWeb, 17, false);
    propStreamerResource = _is.read(propStreamerResource, 21, false);
    propsPic108 = _is.read(propsPic108, 23, false);
    pcBannerResource = _is.read(pcBannerResource, 24, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(propsIdType, 1);
    _os.write(propsPic18, 2);
    _os.write(propsPic24, 3);
    _os.write(propsPicGif, 4);
    _os.write(propsBannerResource, 5);
    _os.write(propsChatBannerResource, 8);
    _os.write(propH5Resource, 16);
    _os.write(propsWeb, 17);
    _os.write(propStreamerResource, 21);
    _os.write(propsPic108, 23);
    _os.write(pcBannerResource, 24);
  }

  @override
  Object deepCopy() {
    return HYPropsIdentity()
      ..propsIdType = propsIdType
      ..propsPic18 = propsPic18
      ..propsPic24 = propsPic24
      ..propsPicGif = propsPicGif
      ..propsBannerResource = propsBannerResource
      ..propsChatBannerResource = propsChatBannerResource
      ..propH5Resource = propH5Resource
      ..propsWeb = propsWeb
      ..propStreamerResource = propStreamerResource
      ..propsPic108 = propsPic108
      ..pcBannerResource = pcBannerResource;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

List<String> _uniqueResourceCandidates(Iterable<String> candidates) {
  final values = <String>[];
  final seen = <String>{};
  for (final candidate in candidates) {
    final normalized = _normalizeResourceCandidate(candidate);
    if (normalized == null) continue;
    if (seen.add(_resourceCandidateKey(normalized))) {
      values.add(normalized);
    }
  }
  return values;
}

String? _normalizeResourceCandidate(String value) {
  var normalized = value.trim();
  if (normalized.isEmpty) return null;
  if (normalized.startsWith('//')) {
    normalized = 'https:$normalized';
  }

  // 虎牙旧目录会把校验串直接追加为 `path.ext&hash`，它不是 URL 查询参数。
  // 保留真正的 `?query`，仅移除路径后的旧式校验串。
  final queryIndex = normalized.indexOf('?');
  final legacySuffixIndex = normalized.indexOf('&');
  if (legacySuffixIndex >= 0 &&
      (queryIndex < 0 || legacySuffixIndex < queryIndex)) {
    normalized = normalized.substring(0, legacySuffixIndex) +
        (queryIndex < 0 ? '' : normalized.substring(queryIndex));
  }
  return normalized;
}

String _resourceCandidateKey(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasAuthority) {
    final queryIndex = value.indexOf('?');
    final fragmentIndex = value.indexOf('#');
    final end = <int>[
      if (queryIndex >= 0) queryIndex,
      if (fragmentIndex >= 0) fragmentIndex,
    ].fold(value.length, (current, index) => index < current ? index : current);
    return value.substring(0, end);
  }

  final port = uri.hasPort &&
          !((uri.scheme == 'http' && uri.port == 80) ||
              (uri.scheme == 'https' && uri.port == 443))
      ? ':${uri.port}'
      : '';
  return '${uri.host.toLowerCase()}$port${uri.path}';
}

/// 礼物目录中当前功能需要的可信字段。
class HYPropsItem extends TarsStruct {
  int propsId = 0;
  String propsName = "";
  int propsYb = 0;
  List<HYPropsIdentity> identities = <HYPropsIdentity>[];
  String commonBannerResource = "";
  String ownBannerResource = "";
  int templateType = 0;
  int shelfStatus = 0;
  String androidLogo = "";
  String ipadLogo = "";
  String iphoneLogo = "";
  String commonBannerResourceEx = "";
  String ownBannerResourceEx = "";

  List<String> get imageCandidates => _uniqueResourceCandidates(<String>[
        for (final identity in identities) ...<String>[
          identity.propsPic108,
          identity.propsPic24,
          identity.propsPic18,
          identity.propsPicGif,
        ],
        androidLogo,
        iphoneLogo,
        ipadLogo,
      ]);

  List<String> get effectCandidates => _uniqueResourceCandidates(<String>[
        for (final identity in identities) ...<String>[
          identity.propsChatBannerResource,
          identity.propsBannerResource,
          identity.propStreamerResource,
          identity.pcBannerResource,
          identity.propH5Resource,
          identity.propsWeb,
        ],
        commonBannerResourceEx,
        ownBannerResourceEx,
        commonBannerResource,
        ownBannerResource,
      ]);

  @override
  void readFrom(TarsInputStream _is) {
    propsId = _is.read(propsId, 1, false);
    propsName = _is.read(propsName, 2, false);
    propsYb = _is.read(propsYb, 3, false);
    identities = _is.readList<HYPropsIdentity>([HYPropsIdentity()], 16, false);
    commonBannerResource = _is.read(commonBannerResource, 23, false);
    ownBannerResource = _is.read(ownBannerResource, 24, false);
    templateType = _is.read(templateType, 26, false);
    shelfStatus = _is.read(shelfStatus, 27, false);
    androidLogo = _is.read(androidLogo, 28, false);
    ipadLogo = _is.read(ipadLogo, 29, false);
    iphoneLogo = _is.read(iphoneLogo, 30, false);
    commonBannerResourceEx = _is.read(commonBannerResourceEx, 31, false);
    ownBannerResourceEx = _is.read(ownBannerResourceEx, 32, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(propsId, 1);
    _os.write(propsName, 2);
    _os.write(propsYb, 3);
    _os.write(identities, 16);
    _os.write(commonBannerResource, 23);
    _os.write(ownBannerResource, 24);
    _os.write(templateType, 26);
    _os.write(shelfStatus, 27);
    _os.write(androidLogo, 28);
    _os.write(ipadLogo, 29);
    _os.write(iphoneLogo, 30);
    _os.write(commonBannerResourceEx, 31);
    _os.write(ownBannerResourceEx, 32);
  }

  @override
  Object deepCopy() {
    return HYPropsItem()
      ..propsId = propsId
      ..propsName = propsName
      ..propsYb = propsYb
      ..identities = identities
          .map((identity) => identity.deepCopy() as HYPropsIdentity)
          .toList()
      ..commonBannerResource = commonBannerResource
      ..ownBannerResource = ownBannerResource
      ..templateType = templateType
      ..shelfStatus = shelfStatus
      ..androidLogo = androidLogo
      ..ipadLogo = ipadLogo
      ..iphoneLogo = iphoneLogo
      ..commonBannerResourceEx = commonBannerResourceEx
      ..ownBannerResourceEx = ownBannerResourceEx;
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
