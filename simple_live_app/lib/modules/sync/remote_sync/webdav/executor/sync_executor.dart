import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/common/sync_mode.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/interface/sync_resource.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/resources/blockwords_sync_resource.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/resources/follow_sync_resource.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/resources/history_sync_resource.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/resources/settings_sync_resource.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/resources/user_account_cookie_sync_resource.dart';
import 'package:simple_live_app/requests/webdav_client.dart';

class SyncExecutor {
  static final SyncExecutor instance = SyncExecutor._();

  static const int maxDownloadBytes = 16 * 1024 * 1024;
  static const int maxArchiveEntries = 32;
  static const int maxArchiveEntryBytes = 8 * 1024 * 1024;
  static const int maxArchiveUncompressedBytes = 32 * 1024 * 1024;

  late _WebDAVSyncTransport _transport;
  bool _configured = false;
  List<SyncResource> _resources = <SyncResource>[];

  SyncExecutor._();

  @visibleForTesting
  SyncExecutor.forTesting({
    required Future<List<int>> Function() recovery,
    required Future<bool> Function(Uint8List data) backup,
  })  : _transport = _CallbackWebDAVSyncTransport(recovery, backup),
        _configured = true;

  void buildExecutorAttr(
    DAVClient davClient, {
    bool isSyncFollows = true,
    bool isSyncHistories = true,
    bool isSyncBlockWord = true,
    bool isSyncAccount = true,
    bool isSyncSetting = true,
  }) {
    _transport = _DAVClientSyncTransport(davClient);
    _configured = true;
    _replaceResources(
      isSyncFollows: isSyncFollows,
      isSyncHistories: isSyncHistories,
      isSyncBlockWord: isSyncBlockWord,
      isSyncAccount: isSyncAccount,
      isSyncSetting: isSyncSetting,
    );
  }

  @visibleForTesting
  void replaceResourcesForTesting({
    bool isSyncFollows = true,
    bool isSyncHistories = true,
    bool isSyncBlockWord = true,
    bool isSyncAccount = true,
    bool isSyncSetting = true,
  }) {
    _replaceResources(
      isSyncFollows: isSyncFollows,
      isSyncHistories: isSyncHistories,
      isSyncBlockWord: isSyncBlockWord,
      isSyncAccount: isSyncAccount,
      isSyncSetting: isSyncSetting,
    );
  }

  @visibleForTesting
  List<String> get selectedResourceFileNames =>
      List.unmodifiable(_resources.map((resource) => resource.fileName));

  @visibleForTesting
  void setResourcesForTesting(List<SyncResource> resources) {
    _resources = List<SyncResource>.of(resources);
  }

  void _replaceResources({
    required bool isSyncFollows,
    required bool isSyncHistories,
    required bool isSyncBlockWord,
    required bool isSyncAccount,
    required bool isSyncSetting,
  }) {
    _resources = <SyncResource>[
      if (isSyncFollows) FollowSyncResource(),
      if (isSyncHistories) HistorySyncResource(),
      if (isSyncBlockWord) BlockwordsSyncResource(),
      if (isSyncAccount) UserAccountCookieSyncResource(),
      if (isSyncSetting) SettingsSyncResource(),
    ];
  }

  // fetch -> local -> remote -> select sync-mode
  Future<void> sync(SyncMode mode) async {
    if (!_configured) {
      throw StateError('SyncExecutor 尚未配置 WebDAV 客户端');
    }

    final remoteArchive = await _doWebDAVFetch();
    final uploadArchive = Archive();
    final pendingLocalSaves = <Future<void> Function()>[];

    for (final resource in _resources) {
      final local = await resource.loadLocal();
      final remote =
          remoteArchive == null ? null : resource.loadRemote(remoteArchive);

      switch (mode) {
        case SyncMode.uploadAll:
          resource.saveRemote(uploadArchive, local);
          break;
        case SyncMode.recoveryAll:
          if (remote != null) {
            await resource.saveLocal(remote);
          }
          break;
        case SyncMode.bidirectional:
          final merged = remote == null
              ? resource is InitialBidirectionalSyncResource
                  ? (resource as InitialBidirectionalSyncResource)
                      .prepareInitialBidirectional(local)
                  : local
              : resource.merge(local, remote);
          // 先生成并上传远端快照，上传确认成功后再清零本地同步增量。
          // 若网络失败，本地仍保留增量，下次同步不会静默丢失观看时长。
          pendingLocalSaves.add(() => resource.saveLocal(merged));
          resource.saveRemote(uploadArchive, merged);
          break;
      }
    }

    if (mode != SyncMode.recoveryAll) {
      final zipBytes = ZipEncoder().encode(uploadArchive);
      if (zipBytes.length > maxDownloadBytes) {
        throw WebDAVBackupValidationException(
          '生成的 WebDAV 备份超过 ${maxDownloadBytes ~/ (1024 * 1024)} MiB',
        );
      }
      final success = await _transport.backup(Uint8List.fromList(zipBytes));
      if (!success) {
        throw StateError('WebDAV 备份上传失败');
      }
    }

    for (final saveLocal in pendingLocalSaves) {
      await saveLocal();
    }
  }

  /// 远端确实不存在 backup.zip 时返回 null；其余网络、鉴权和格式错误上抛。
  Future<Archive?> _doWebDAVFetch() async {
    late final List<int> data;
    try {
      data = await _transport.recovery();
    } catch (error, stackTrace) {
      if (_isNotFound(error)) return null;
      Log.e('WebDAV 恢复失败：$error', stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }

    if (data.isEmpty) {
      throw const WebDAVBackupValidationException('WebDAV 备份文件为空');
    }
    if (data.length > maxDownloadBytes) {
      throw WebDAVBackupValidationException(
        'WebDAV 备份下载大小超过 ${maxDownloadBytes ~/ (1024 * 1024)} MiB',
      );
    }

    final bytes = Uint8List.fromList(data);
    return Isolate.run<Archive>(() => _decodeArchiveWithLimits(bytes));
  }

  static bool _isNotFound(Object error) =>
      error is DioException && error.response?.statusCode == 404;

  static Archive _decodeArchiveWithLimits(Uint8List data) {
    var entryCount = 0;
    var totalUncompressedBytes = 0;

    return ZipDecoder().decodeBytes(
      data,
      callback: (entry) {
        entryCount++;
        if (entryCount > maxArchiveEntries) {
          throw const WebDAVBackupValidationException('WebDAV 备份条目数量过多');
        }
        if (!entry.isFile || entry.isSymbolicLink) {
          throw const WebDAVBackupValidationException('WebDAV 备份包含不允许的条目类型');
        }
        if (entry.name.contains('/') ||
            entry.name.contains('\\') ||
            entry.name.contains('..') ||
            !entry.name.endsWith('.json')) {
          throw WebDAVBackupValidationException(
            'WebDAV 备份包含非法条目：${entry.name}',
          );
        }
        if (entry.size < 0 || entry.size > maxArchiveEntryBytes) {
          throw WebDAVBackupValidationException(
            'WebDAV 备份条目过大：${entry.name}',
          );
        }
        totalUncompressedBytes += entry.size;
        if (totalUncompressedBytes > maxArchiveUncompressedBytes) {
          throw const WebDAVBackupValidationException('WebDAV 备份解压后体积过大');
        }
      },
    );
  }
}

abstract interface class _WebDAVSyncTransport {
  Future<List<int>> recovery();

  Future<bool> backup(Uint8List data);
}

class _DAVClientSyncTransport implements _WebDAVSyncTransport {
  const _DAVClientSyncTransport(this.client);

  final DAVClient client;

  @override
  Future<bool> backup(Uint8List data) => client.backup(data);

  @override
  Future<List<int>> recovery() => client.recovery();
}

class _CallbackWebDAVSyncTransport implements _WebDAVSyncTransport {
  const _CallbackWebDAVSyncTransport(this._recovery, this._backup);

  final Future<List<int>> Function() _recovery;
  final Future<bool> Function(Uint8List data) _backup;

  @override
  Future<bool> backup(Uint8List data) => _backup(data);

  @override
  Future<List<int>> recovery() => _recovery();
}

class WebDAVBackupValidationException implements Exception {
  const WebDAVBackupValidationException(this.message);

  final String message;

  @override
  String toString() => 'WebDAVBackupValidationException: $message';
}
