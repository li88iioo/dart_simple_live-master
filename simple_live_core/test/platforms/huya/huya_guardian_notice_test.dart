import 'dart:typed_data';

import 'package:simple_live_core/src/platforms/huya/huya_guardian_notice.dart';
import 'package:tars_dart/tars/codec/tars_decode_exception.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:test/test.dart';

const _presenterUid = 0x100000001;
const _guardianUid = 0x200000003;

// 按官方字段 tag 独立构造输入，不调用被测结构的 writeTo。
TarsOutputStream _fullWire({int noticeType = 0}) {
  return TarsOutputStream()
    ..writeInt(_presenterUid, 0)
    ..writeString('主播甲', 1)
    ..writeInt(12, 2)
    ..writeInt(_guardianUid, 3)
    ..writeString('守护用户🌟', 4)
    ..writeInt(noticeType, 5)
    ..writeInt(45, 6)
    ..writeInt(9, 7)
    ..writeInt(6, 8)
    ..writeString('guardian-avatar', 9)
    ..writeInt(1234, 10)
    ..writeInt(919, 11)
    ..writeString('anchor-avatar', 12)
    ..writeInt(0x100000005, 13)
    ..writeInt(0x200000007, 14)
    ..writeInt(128, 15)
    ..writeString('原始守护名称', 16)
    ..writeInt(837, 17);
}

TarsOutputStream _criticalWire({
  int noticeType = 0,
  int? omittedTag,
  int? stringTag,
}) {
  final output = TarsOutputStream();
  for (final entry in <int, int>{
    0: _presenterUid,
    3: _guardianUid,
    5: noticeType,
  }.entries) {
    if (entry.key == omittedTag) continue;
    if (entry.key == stringTag) {
      output.writeString('not-an-integer', entry.key);
    } else {
      output.writeInt(entry.value, entry.key);
    }
  }
  // 未知尾字段同时避免底层 skipToTag 对正常 optional EOF 的重复日志。
  output.writeInt(123, 18);
  return output;
}

HYGuardianPresenterInfoNotice _decode(TarsOutputStream output) {
  return HYGuardianPresenterInfoNotice()
    ..readFrom(TarsInputStream(output.toUint8List()));
}

List<Object> _values(HYGuardianPresenterInfoNotice notice) => [
      notice.presenterUid,
      notice.presenterNick,
      notice.level,
      notice.guardianUid,
      notice.guardianNick,
      notice.noticeType,
      notice.openDays,
      notice.lastLevel,
      notice.nobleLevel,
      notice.guardianLogo,
      notice.gameId,
      notice.guardType,
      notice.anchorLogo,
      notice.commemorateDay,
      notice.endTime,
      notice.accompanyDay,
      notice.guardName,
      notice.opType,
    ];

void main() {
  group('HYGuardianPresenterInfoNotice', () {
    test('定义 NEW=0 和 ENTER=1，但不限制其它原始类型值', () {
      expect(HYGuardianPresenterInfoNotice.NEW, 0);
      expect(HYGuardianPresenterInfoNotice.ENTER, 1);
    });

    test('独立 wire 解出 18 字段并保留超过 32 位的 UID 和尾部整数', () {
      final notice = _decode(_fullWire());

      expect(_values(notice), [
        _presenterUid,
        '主播甲',
        12,
        _guardianUid,
        '守护用户🌟',
        0,
        45,
        9,
        6,
        'guardian-avatar',
        1234,
        919,
        'anchor-avatar',
        0x100000005,
        0x200000007,
        128,
        '原始守护名称',
        837,
      ]);
    });

    test('只有关键 tag 时其它字段保持协议默认值', () {
      final notice = _decode(_criticalWire());

      expect(_values(notice), [
        _presenterUid,
        '',
        0,
        _guardianUid,
        '',
        0,
        0,
        0,
        0,
        '',
        0,
        0,
        '',
        0,
        0,
        0,
        '',
        0,
      ]);
    });

    test('旧版本缺少 tag 12–17 时仍保留 tag 11，不虚构尾字段', () {
      final output = TarsOutputStream()
        ..writeInt(_presenterUid, 0)
        ..writeInt(_guardianUid, 3)
        ..writeInt(1, 5)
        ..writeInt(919, 11)
        ..writeInt(123, 18);
      final notice = _decode(output);

      expect(notice.noticeType, 1);
      expect(notice.guardType, 919);
      expect(notice.anchorLogo, '');
      expect(notice.commemorateDay, 0);
      expect(notice.endTime, 0);
      expect(notice.accompanyDay, 0);
      expect(notice.guardName, '');
      expect(notice.opType, 0);
    });

    for (final noticeType in [0, 1, -7, 2, 1234]) {
      test('原样保留 noticeType=$noticeType，不强转 NEW/ENTER', () {
        final notice = _decode(_criticalWire(noticeType: noticeType));

        expect(notice.noticeType, noticeType);
      });
    }

    test('按实际 wire 宽度恢复符号位，不把正数 128–255 当作负数', () {
      for (final value in [-32769, -129, -128, -1, 127, 128, 249, 255, 32768]) {
        final notice = _decode(_criticalWire(noticeType: value));

        expect(notice.noticeType, value, reason: 'noticeType=$value');
      }
    });

    test('所有整数字段均保留负数原始值，不在协议层推断有效范围', () {
      final output = TarsOutputStream()
        ..writeInt(-1, 0)
        ..writeInt(-2, 2)
        ..writeInt(-3, 3)
        ..writeInt(-4, 5)
        ..writeInt(-5, 6)
        ..writeInt(-6, 7)
        ..writeInt(-7, 8)
        ..writeInt(-8, 10)
        ..writeInt(-9, 11)
        ..writeInt(-10, 13)
        ..writeInt(-11, 14)
        ..writeInt(-12, 15)
        ..writeInt(-13, 17);
      final notice = _decode(output);

      expect(_values(notice), [
        -1,
        '',
        -2,
        -3,
        '',
        -4,
        -5,
        -6,
        -7,
        '',
        -8,
        -9,
        '',
        -10,
        -11,
        -12,
        '',
        -13,
      ]);
    });

    for (final tag in [0, 3, 5]) {
      test('缺少关键 tag $tag 时拒绝解码，不以默认值补齐', () {
        expect(
          () => _decode(_criticalWire(omittedTag: tag)),
          throwsA(isA<TarsDecodeException>()),
        );
      });

      test('关键 tag $tag 的 wire 类型为 String 时拒绝解码', () {
        expect(
          () => _decode(_criticalWire(stringTag: tag)),
          throwsA(isA<TarsDecodeException>()),
        );
      });
    }

    test('空 payload 不会产生默认 NEW 通知', () {
      expect(
        () => HYGuardianPresenterInfoNotice()
          ..readFrom(TarsInputStream(Uint8List(0))),
        throwsA(isA<TarsDecodeException>()),
      );
    });

    test('required 检查字段存在而非非零，显式 ZERO_TAG 合法', () {
      final output = TarsOutputStream()
        ..writeInt(0, 0)
        ..writeInt(0, 3)
        ..writeInt(0, 5)
        ..writeInt(123, 18);
      final notice = _decode(output);

      expect(notice.presenterUid, 0);
      expect(notice.guardianUid, 0);
      expect(notice.noticeType, 0);
    });

    test('未知尾 tag 不影响扩展 tag 16/17，保留后续读取位置', () {
      final output = _fullWire(noticeType: 1)
        ..writeString('future-field', 18)
        ..writeInt(0x300000009, 255);
      final input = TarsInputStream(output.toUint8List());
      final notice = HYGuardianPresenterInfoNotice()..readFrom(input);

      expect(notice.noticeType, 1);
      expect(notice.guardName, '原始守护名称');
      expect(notice.opType, 837);
      expect(input.readString(18, true), 'future-field');
      expect(input.readInt(255, true), 0x300000009);
    });

    test('writeTo 输出可由独立 tag 读取器验证，不用自身 readFrom 自证', () {
      final notice = HYGuardianPresenterInfoNotice()
        ..presenterUid = _presenterUid
        ..presenterNick = '主播甲'
        ..level = 12
        ..guardianUid = _guardianUid
        ..guardianNick = '守护用户🌟'
        ..noticeType = 1234
        ..openDays = 45
        ..lastLevel = 9
        ..nobleLevel = 6
        ..guardianLogo = 'guardian-avatar'
        ..gameId = 1234
        ..guardType = 919
        ..anchorLogo = 'anchor-avatar'
        ..commemorateDay = 0x100000005
        ..endTime = 0x200000007
        ..accompanyDay = 128
        ..guardName = '原始守护名称'
        ..opType = 837;
      final output = TarsOutputStream();
      notice.writeTo(output);
      final input = TarsInputStream(output.toUint8List());
      final expectedByTag = <int, Object>{
        0: _presenterUid,
        1: '主播甲',
        2: 12,
        3: _guardianUid,
        4: '守护用户🌟',
        5: 1234,
        6: 45,
        7: 9,
        8: 6,
        9: 'guardian-avatar',
        10: 1234,
        11: 919,
        12: 'anchor-avatar',
        13: 0x100000005,
        14: 0x200000007,
        15: 128,
        16: '原始守护名称',
        17: 837,
      };

      for (final entry in expectedByTag.entries) {
        expect(
          input.read(entry.value, entry.key, true),
          entry.value,
          reason: 'tag ${entry.key}',
        );
      }
    });

    test('deepCopy 复制全部原始值，修改副本不影响原对象', () {
      final original = _decode(_fullWire(noticeType: -7));
      final copy = original.deepCopy();

      expect(identical(original, copy), isFalse);
      expect(_values(copy), _values(original));
      copy
        ..guardianNick = '副本用户'
        ..noticeType = 1
        ..opType = 0;
      expect(original.guardianNick, '守护用户🌟');
      expect(original.noticeType, -7);
      expect(original.opType, 837);
    });
  });
}
