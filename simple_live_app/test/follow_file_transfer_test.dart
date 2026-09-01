import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/follow_service.dart';

void main() {
  group('关注列表文件传输', () {
    test('导出通过 saveFile 直接写入 UTF-8 bytes', () async {
      final picker = _RecordingFilePicker('/selected/follow.json');
      const jsonText = '{"name":"测试用户"}';

      final saved = await saveFollowJsonExport(
        filePicker: picker,
        jsonText: jsonText,
        now: DateTime.fromMillisecondsSinceEpoch(1234000),
      );

      expect(saved, isTrue);
      expect(picker.dialogTitle, '导出关注列表');
      expect(picker.fileName, 'SimpleLive_1234.json');
      expect(picker.type, FileType.custom);
      expect(picker.allowedExtensions, const ['json']);
      expect(picker.bytes, Uint8List.fromList(utf8.encode(jsonText)));
    });

    test('用户取消导出时不报告成功', () async {
      final saved = await saveFollowJsonExport(
        filePicker: _RecordingFilePicker(null),
        jsonText: '{}',
        now: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(saved, isFalse);
    });

    test('导入优先读取 SAF 返回的内存数据', () async {
      final file = PlatformFile(
        name: 'follow.json',
        size: 18,
        bytes: Uint8List.fromList(
          const [
            123,
            34,
            110,
            97,
            109,
            101,
            34,
            58,
            34,
            230,
            181,
            139,
            232,
            175,
            149,
            34,
            125
          ],
        ),
      );

      expect(await readFollowJsonImport(file), '{"name":"测试"}');
    });

    test('桌面导入可回退到选择器返回的文件路径', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'slive-follow-import-',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));
      final jsonFile = File('${tempDirectory.path}/follow.json');
      await jsonFile.writeAsString('{"siteId":"huya"}');

      final content = await readFollowJsonImport(
        PlatformFile(
          name: 'follow.json',
          size: await jsonFile.length(),
          path: jsonFile.path,
        ),
      );

      expect(content, '{"siteId":"huya"}');
    });

    test('选择器既未返回 bytes 也未返回路径时明确失败', () async {
      final file = PlatformFile(name: 'follow.json', size: 0);

      await expectLater(
        readFollowJsonImport(file),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  test('Android 主清单不再声明广泛存储权限', () async {
    final manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();

    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, isNot(contains('WRITE_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('READ_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('MANAGE_EXTERNAL_STORAGE')));
  });
}

class _RecordingFilePicker extends FilePicker {
  _RecordingFilePicker(this.result);

  final String? result;
  String? dialogTitle;
  String? fileName;
  FileType? type;
  List<String>? allowedExtensions;
  Uint8List? bytes;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    this.dialogTitle = dialogTitle;
    this.fileName = fileName;
    this.type = type;
    this.allowedExtensions = allowedExtensions;
    this.bytes = bytes;
    return result;
  }
}
