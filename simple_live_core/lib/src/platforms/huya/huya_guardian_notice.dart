import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

import 'huya_tars_utils.dart';

/// 官方 GuardianPresenterInfoNotice（URI 1020001）的原始字段。
///
/// 协议来源：官方 taf-signal.global.0.1.2.prod.js 的 readFrom/writeTo。
/// NEW 包含开通、续期或升级通知，ENTER 是进场，不能把 ENTER 当作续费。
/// 不推断 guardType/opType 的枚举或时间单位，也不将 openDays 转为礼物数量。
class HYGuardianPresenterInfoNotice extends TarsStruct {
  static const int NEW = 0;
  static const int ENTER = 1;

  int presenterUid = 0;
  String presenterNick = '';
  int level = 0;
  int guardianUid = 0;
  String guardianNick = '';
  int noticeType = NEW;
  int openDays = 0;
  int lastLevel = 0;
  int nobleLevel = 0;
  String guardianLogo = '';
  int gameId = 0;
  int guardType = 0;
  String anchorLogo = '';
  int commemorateDay = 0;
  int endTime = 0;
  int accompanyDay = 0;
  String guardName = '';
  int opType = 0;

  @override
  void readFrom(TarsInputStream input) {
    // 身份和通知类型必须真实存在，不能靠默认的 0 虚构 NEW 通知。
    presenterUid = readHuyaSignedInt(input, 0, true);
    presenterNick = input.readString(1, false);
    level = readHuyaSignedInt(input, 2, false);
    guardianUid = readHuyaSignedInt(input, 3, true);
    guardianNick = input.readString(4, false);
    noticeType = readHuyaSignedInt(input, 5, true);
    openDays = readHuyaSignedInt(input, 6, false);
    lastLevel = readHuyaSignedInt(input, 7, false);
    nobleLevel = readHuyaSignedInt(input, 8, false);
    guardianLogo = input.readString(9, false);
    gameId = readHuyaSignedInt(input, 10, false);
    guardType = readHuyaSignedInt(input, 11, false);
    anchorLogo = input.readString(12, false);
    commemorateDay = readHuyaSignedInt(input, 13, false);
    endTime = readHuyaSignedInt(input, 14, false);
    accompanyDay = readHuyaSignedInt(input, 15, false);
    guardName = input.readString(16, false);
    opType = readHuyaSignedInt(input, 17, false);
  }

  @override
  void writeTo(TarsOutputStream output) {
    output.writeInt(presenterUid, 0);
    output.writeString(presenterNick, 1);
    output.writeInt(level, 2);
    output.writeInt(guardianUid, 3);
    output.writeString(guardianNick, 4);
    output.writeInt(noticeType, 5);
    output.writeInt(openDays, 6);
    output.writeInt(lastLevel, 7);
    output.writeInt(nobleLevel, 8);
    output.writeString(guardianLogo, 9);
    output.writeInt(gameId, 10);
    output.writeInt(guardType, 11);
    output.writeString(anchorLogo, 12);
    output.writeInt(commemorateDay, 13);
    output.writeInt(endTime, 14);
    output.writeInt(accompanyDay, 15);
    output.writeString(guardName, 16);
    output.writeInt(opType, 17);
  }

  @override
  HYGuardianPresenterInfoNotice deepCopy() {
    return HYGuardianPresenterInfoNotice()
      ..presenterUid = presenterUid
      ..presenterNick = presenterNick
      ..level = level
      ..guardianUid = guardianUid
      ..guardianNick = guardianNick
      ..noticeType = noticeType
      ..openDays = openDays
      ..lastLevel = lastLevel
      ..nobleLevel = nobleLevel
      ..guardianLogo = guardianLogo
      ..gameId = gameId
      ..guardType = guardType
      ..anchorLogo = anchorLogo
      ..commemorateDay = commemorateDay
      ..endTime = endTime
      ..accompanyDay = accompanyDay
      ..guardName = guardName
      ..opType = opType;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}
