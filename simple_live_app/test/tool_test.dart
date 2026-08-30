import 'package:flutter_test/flutter_test.dart';
import 'package:pinyin/pinyin.dart';

void main() {
  test('生成中文拼音首字母', () {
    expect(PinyinHelper.getShortPinyin('zzz你好啊'), 'zzz nha');
  });

  const cases = <String, bool>{
    '/123/123': true,
    '/123/123/123/123': true,
    '123': false,
    '/123': true,
    '/123/': false,
  };

  for (final entry in cases.entries) {
    test('校验目录路径 ${entry.key}', () {
      final regex = RegExp(r'^/([^/]+)(/[^/]+)*$');
      expect(regex.hasMatch(entry.key), entry.value);
    });
  }
}
