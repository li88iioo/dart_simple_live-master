import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/common/sync_mode.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/executor/sync_executor.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/interface/sync_resource.dart';

void main() {
  test('每次选择都会替换资源列表，关闭的同步项不会残留', () {
    final executor = _executor();

    executor.replaceResourcesForTesting();
    expect(executor.selectedResourceFileNames, hasLength(5));

    executor.replaceResourcesForTesting(
      isSyncFollows: false,
      isSyncHistories: false,
      isSyncBlockWord: false,
      isSyncAccount: false,
      isSyncSetting: true,
    );

    expect(
      executor.selectedResourceFileNames,
      equals(['SimpleLive_Settings.json']),
    );
  });

  test('远端 backup.zip 不存在时按空备份处理', () async {
    final request = RequestOptions(path: '/simple_live_app/backup.zip');
    final executor = SyncExecutor.forTesting(
      recovery: () => throw DioException(
        requestOptions: request,
        response: Response<void>(
          requestOptions: request,
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      ),
      backup: (_) async => true,
    );

    await expectLater(executor.sync(SyncMode.recoveryAll), completes);
  });

  test('鉴权或其他 WebDAV 拉取错误必须上抛', () async {
    final request = RequestOptions(path: '/simple_live_app/backup.zip');
    final executor = SyncExecutor.forTesting(
      recovery: () => throw DioException(
        requestOptions: request,
        response: Response<void>(
          requestOptions: request,
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      ),
      backup: (_) async => true,
    );

    await expectLater(
      executor.sync(SyncMode.recoveryAll),
      throwsA(isA<DioException>()),
    );
  });

  test('拒绝超过下载上限的 WebDAV 备份', () async {
    final executor = SyncExecutor.forTesting(
      recovery: () async => List<int>.filled(
        SyncExecutor.maxDownloadBytes + 1,
        0,
      ),
      backup: (_) async => true,
    );

    await expectLater(
      executor.sync(SyncMode.recoveryAll),
      throwsA(isA<WebDAVBackupValidationException>()),
    );
  });

  test('拒绝条目数量过多的 ZIP', () async {
    final archive = Archive();
    for (var index = 0; index <= SyncExecutor.maxArchiveEntries; index++) {
      archive.addFile(ArchiveFile.string('entry_$index.json', '{}'));
    }
    final bytes = ZipEncoder().encode(archive);
    final executor = SyncExecutor.forTesting(
      recovery: () async => bytes,
      backup: (_) async => true,
    );

    await expectLater(
      executor.sync(SyncMode.recoveryAll),
      throwsA(isA<WebDAVBackupValidationException>()),
    );
  });

  test('拒绝声明解压体积过大的 ZIP 条目', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'large.json',
          Uint8List(SyncExecutor.maxArchiveEntryBytes + 1),
        ),
      );
    final bytes = ZipEncoder().encode(archive);
    final executor = SyncExecutor.forTesting(
      recovery: () async => bytes,
      backup: (_) async => true,
    );

    await expectLater(
      executor.sync(SyncMode.recoveryAll),
      throwsA(isA<WebDAVBackupValidationException>()),
    );
  });

  test('WebDAV 客户端返回上传失败时同步必须失败', () async {
    final executor = SyncExecutor.forTesting(
      recovery: _notFound,
      backup: (_) async => false,
    );

    await expectLater(
      executor.sync(SyncMode.uploadAll),
      throwsA(isA<StateError>()),
    );
  });

  test('双向同步上传失败时不会提前清零或覆盖本地数据', () async {
    final events = <String>[];
    final remote = Archive()..addFile(ArchiveFile.string('ordered.json', '2'));
    final executor = SyncExecutor.forTesting(
      recovery: () async => ZipEncoder().encode(remote),
      backup: (_) async {
        events.add('backup');
        return false;
      },
    )..setResourcesForTesting([_OrderedSyncResource(events)]);

    await expectLater(
      executor.sync(SyncMode.bidirectional),
      throwsA(isA<StateError>()),
    );
    expect(events, ['backup']);
  });

  test('双向同步仅在远端上传成功后保存本地合并结果', () async {
    final events = <String>[];
    final remote = Archive()..addFile(ArchiveFile.string('ordered.json', '2'));
    final executor = SyncExecutor.forTesting(
      recovery: () async => ZipEncoder().encode(remote),
      backup: (_) async {
        events.add('backup');
        return true;
      },
    )..setResourcesForTesting([_OrderedSyncResource(events)]);

    await executor.sync(SyncMode.bidirectional);
    expect(events, ['backup', 'save-local-3']);
  });
}

SyncExecutor _executor() => SyncExecutor.forTesting(
      recovery: _notFound,
      backup: (_) async => true,
    );

Future<List<int>> _notFound() {
  final request = RequestOptions(path: '/simple_live_app/backup.zip');
  throw DioException(
    requestOptions: request,
    response: Response<void>(requestOptions: request, statusCode: 404),
    type: DioExceptionType.badResponse,
  );
}

class _OrderedSyncResource implements SyncResource<int> {
  _OrderedSyncResource(this.events);

  final List<String> events;

  @override
  String get fileName => 'ordered.json';

  @override
  Future<int> loadLocal() async => 1;

  @override
  int? loadRemote(Archive archive) =>
      archive.findFile(fileName) == null ? null : 2;

  @override
  int merge(int local, int remote) => local + remote;

  @override
  Future<void> saveLocal(int data) async {
    events.add('save-local-$data');
  }

  @override
  void saveRemote(Archive archive, int data) {
    archive.addFile(ArchiveFile.string(fileName, data.toString()));
  }
}
