// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

import 'huya_gift_catalog.dart';
import 'huya_tars_utils.dart';

/// 6501 的 ItemEffectBizData(type=16)，不是 UTF-8/JSON。
/// 官方网页在 gift.ts 中按 NonResourceItemEffect 读取，图标来自 sPropsUrl，
/// 特殊资源来自 vWebSpecilInfo。字段依据见 fixtures/README.md。
class HYNonResourceItemEffect extends TarsStruct {
  String propsUrl = '';
  List<HYGiftWebExtInfo> webInfo = <HYGiftWebExtInfo>[];
  int propsYb = 0;
  String propsId = '';

  List<String> get imageCandidates => normalizeHuyaGiftResourceCandidates([
        propsUrl,
        for (final info in webInfo)
          for (final identity in info.identities) ...identity.imageCandidates,
      ]);

  List<String> get effectCandidates => normalizeHuyaGiftResourceCandidates([
        for (final info in webInfo) ...[
          for (final identity in info.identities) ...identity.effectCandidates,
          for (final identity in info.godIdentities)
            ...identity.effectCandidates,
        ],
      ]);

  @override
  void readFrom(TarsInputStream _is) {
    propsUrl = _is.read(propsUrl, 0, false);
    // tag 1: SpecialInfoV2, tag 2: 移动端资源；不把其中头像/文案猜成图标。
    webInfo = _is.readList<HYGiftWebExtInfo>([HYGiftWebExtInfo()], 3, false);
    propsYb = readHuyaSignedInt(_is, 6, false);
    propsId = _is.read(propsId, 7, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(propsUrl, 0);
    _os.write(webInfo, 3);
    _os.write(propsYb, 6);
    _os.write(propsId, 7);
  }

  @override
  Object deepCopy() => HYNonResourceItemEffect()
    ..propsUrl = propsUrl
    ..webInfo = webInfo.map((e) => e.deepCopy() as HYGiftWebExtInfo).toList()
    ..propsYb = propsYb
    ..propsId = propsId;

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYGiftWebExtInfo extends TarsStruct {
  List<HYGiftIdentityGodV2> godIdentities = <HYGiftIdentityGodV2>[];
  List<HYGiftIdentityV2> identities = <HYGiftIdentityV2>[];

  @override
  void readFrom(TarsInputStream _is) {
    godIdentities =
        _is.readList<HYGiftIdentityGodV2>([HYGiftIdentityGodV2()], 0, false);
    identities = _is.readList<HYGiftIdentityV2>([HYGiftIdentityV2()], 1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(godIdentities, 0);
    _os.write(identities, 1);
  }

  @override
  Object deepCopy() => HYGiftWebExtInfo()
    ..godIdentities =
        godIdentities.map((e) => e.deepCopy() as HYGiftIdentityGodV2).toList()
    ..identities =
        identities.map((e) => e.deepCopy() as HYGiftIdentityV2).toList();

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYGiftIdentityV2 extends TarsStruct {
  String propsPic18 = '';
  String propsPic24 = '';
  String propsPicGif = '';
  String propsWeb = '';
  String streamerResource = '';
  String propsPic108 = '';
  String pcBannerResource = '';
  String bigGiftPc = '';
  String bigGiftWeb = '';
  String webStaticDown = '';
  String webDynamicDown = '';
  String pcDown = '';
  String bigGiftWebHigh = '';
  String streamerZip = '';
  String webVapJson = '';

  List<String> get imageCandidates =>
      [propsPic108, propsPic24, propsPic18, propsPicGif];

  List<String> get effectCandidates => [
        propsWeb,
        streamerResource,
        pcBannerResource,
        bigGiftPc,
        bigGiftWeb,
        webStaticDown,
        webDynamicDown,
        pcDown,
        bigGiftWebHigh,
        streamerZip,
        webVapJson
      ];

  @override
  void readFrom(TarsInputStream _is) {
    propsPic18 = _is.read(propsPic18, 0, false);
    propsPic24 = _is.read(propsPic24, 1, false);
    propsPicGif = _is.read(propsPicGif, 2, false);
    propsWeb = _is.read(propsWeb, 3, false);
    streamerResource = _is.read(streamerResource, 4, false);
    propsPic108 = _is.read(propsPic108, 6, false);
    pcBannerResource = _is.read(pcBannerResource, 7, false);
    bigGiftPc = _is.read(bigGiftPc, 8, false);
    bigGiftWeb = _is.read(bigGiftWeb, 9, false);
    webStaticDown = _is.read(webStaticDown, 11, false);
    webDynamicDown = _is.read(webDynamicDown, 12, false);
    pcDown = _is.read(pcDown, 13, false);
    bigGiftWebHigh = _is.read(bigGiftWebHigh, 14, false);
    streamerZip = _is.read(streamerZip, 16, false);
    webVapJson = _is.read(webVapJson, 17, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(propsPic18, 0);
    _os.write(propsPic24, 1);
    _os.write(propsPicGif, 2);
    _os.write(propsWeb, 3);
    _os.write(streamerResource, 4);
    _os.write(propsPic108, 6);
    _os.write(pcBannerResource, 7);
    _os.write(bigGiftPc, 8);
    _os.write(bigGiftWeb, 9);
    _os.write(webStaticDown, 11);
    _os.write(webDynamicDown, 12);
    _os.write(pcDown, 13);
    _os.write(bigGiftWebHigh, 14);
    _os.write(streamerZip, 16);
    _os.write(webVapJson, 17);
  }

  @override
  Object deepCopy() => HYGiftIdentityV2()
    ..propsPic18 = propsPic18
    ..propsPic24 = propsPic24
    ..propsPicGif = propsPicGif
    ..propsWeb = propsWeb
    ..streamerResource = streamerResource
    ..propsPic108 = propsPic108
    ..pcBannerResource = pcBannerResource
    ..bigGiftPc = bigGiftPc
    ..bigGiftWeb = bigGiftWeb
    ..webStaticDown = webStaticDown
    ..webDynamicDown = webDynamicDown
    ..pcDown = pcDown
    ..bigGiftWebHigh = bigGiftWebHigh
    ..streamerZip = streamerZip
    ..webVapJson = webVapJson;

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYGiftIdentityGodV2 extends TarsStruct {
  String pcBannerResource = '';
  String bigGiftWeb = '';
  String bigGiftPc = '';
  String bigGiftWebHigh = '';
  String webVapJson = '';

  List<String> get effectCandidates =>
      [pcBannerResource, bigGiftWeb, bigGiftPc, bigGiftWebHigh, webVapJson];

  @override
  void readFrom(TarsInputStream _is) {
    pcBannerResource = _is.read(pcBannerResource, 0, false);
    bigGiftWeb = _is.read(bigGiftWeb, 1, false);
    bigGiftPc = _is.read(bigGiftPc, 2, false);
    bigGiftWebHigh = _is.read(bigGiftWebHigh, 4, false);
    webVapJson = _is.read(webVapJson, 6, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(pcBannerResource, 0);
    _os.write(bigGiftWeb, 1);
    _os.write(bigGiftPc, 2);
    _os.write(bigGiftWebHigh, 4);
    _os.write(webVapJson, 6);
  }

  @override
  Object deepCopy() => HYGiftIdentityGodV2()
    ..pcBannerResource = pcBannerResource
    ..bigGiftWeb = bigGiftWeb
    ..bigGiftPc = bigGiftPc
    ..bigGiftWebHigh = bigGiftWebHigh
    ..webVapJson = webVapJson;

  @override
  void displayAsString(StringBuffer sb, int level) {}
}
