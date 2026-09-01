import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:fractional_indexing_dart/fractional_indexing_dart.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/utils/duration_2_str_utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_sync_time.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/interface/sync_resource.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

class FollowBundle {
  final List<FollowUser> follows;
  final List<FollowUserTag> tags;

  FollowBundle({
    List<FollowUser>? follows,
    List<FollowUserTag>? tags,
  })  : follows = follows ?? [],
        tags = tags ?? [];
}

class FollowSyncResource
    implements
        SyncResource<FollowBundle>,
        InitialBidirectionalSyncResource<FollowBundle> {
  @override
  String get fileName => "SimpleLive_follows.json";

  String get tagFileName => "SimpleLive_Tags.json";

  @override
  Future<FollowBundle> loadLocal() async {
    // 同步时加载所有记录（包含墓碑），确保墓碑可以传播到其他设备
    var followList = DBService.instance.getAllFollowList();
    var tagList = DBService.instance.getFollowTagList();
    return FollowBundle(
      follows: followList,
      tags: tagList,
    );
  }

  @override
  FollowBundle? loadRemote(Archive archive) {
    final followFile = archive.findFile(fileName);
    final tagFile = archive.findFile(tagFileName);
    if (followFile == null || tagFile == null) return null;

    final followJsonData = jsonDecode(utf8.decode(followFile.content));
    var followRemoteList = (followJsonData['data'] as List)
        .map((e) => FollowUser.fromJson(e))
        .toList();
    final tagJsonData = jsonDecode(utf8.decode(tagFile.content));
    var tagRemoteList = (tagJsonData['data'] as List)
        .map((e) => FollowUserTag.fromJson(e))
        .toList();
    return FollowBundle(
      follows: followRemoteList,
      tags: tagRemoteList,
    );
  }

  @override
  Future<void> saveLocal(FollowBundle data) async {
    await DBService.instance.replaceFollowBundle(
      follows: {for (final item in data.follows) item.id: item},
      tags: {for (final tag in data.tags) tag.id: tag},
    );
    EventBus.instance.emit(Constant.kUpdateFollow, 0);
  }

  @override
  void saveRemote(Archive archive, FollowBundle data) {
    final followBytes = utf8.encode(jsonEncode({
      'data': data.follows.map((e) => e.toJson()).toList(),
    }));

    archive.addFile(
      ArchiveFile(
        fileName,
        followBytes.length,
        followBytes,
      ),
    );

    final tagBytes = utf8.encode(jsonEncode({
      'data': data.tags.map((e) => e.toJson()).toList(),
    }));

    archive.addFile(
      ArchiveFile(
        tagFileName,
        tagBytes.length,
        tagBytes,
      ),
    );
  }

  @override
  FollowBundle prepareInitialBidirectional(FollowBundle local) {
    return FollowBundle(
      follows: local.follows.map((item) {
        final snapshot = _copyFollow(item);
        snapshot.syncDuration = 0;
        return snapshot;
      }).toList(growable: false),
      tags: List<FollowUserTag>.of(local.tags),
    );
  }

  @override
  FollowBundle merge(
    FollowBundle local,
    FollowBundle remote,
  ) {
    DateTime curLast = DateTime.fromMillisecondsSinceEpoch(
      LocalStorageService.instance.getValue(
        LocalStorageService.kWebDAVLastRecoverTime,
        0,
      ),
    );
    var resFollows = _mergeFollowList(
        localList: local.follows, remoteList: remote.follows, curLast: curLast);

    // tags after merge, logic from data_check
    final Map<String, List<String>> tagMap = {
      for (var tag in local.tags) tag.tag: <String>[],
    };

    for (var follow in resFollows) {
      if (follow.tag != "全部") {
        tagMap.putIfAbsent(follow.tag, () => <String>[]).add(follow.id);
      }
    }
    final resTags = <FollowUserTag>[];
    String? lastKey;
    for (var entry in tagMap.entries) {
      lastKey = FractionalIndexing.generateKeyBetween(lastKey, null);
      final followUserTag = FollowUserTag(
        id: lastKey,
        tag: entry.key,
        userId: entry.value,
      );
      resTags.add(followUserTag);
    }
    return FollowBundle(follows: resFollows, tags: resTags);
  }

  // sync-double
  // database op-log maybe better
  // follow: cur! and webdav! -> keep;
  // follow: cur! and webdav? -> cur_item.add_time>cur_last->keep; else->remove;
  // follow: cur? and webdav! -> remote.item.add_time>cur_last->keep; else->remove
  //
  // tombstone logic:
  // follow.deleted=true means the user was unfollowed
  // follow.updateTime stores the timestamp of the unfollow
  //
  // follow_watchDuration = webdav_watchDuration += syncDuration
  // syncDuration = 0
  List<FollowUser> _mergeFollowList({
    required List<FollowUser> localList,
    required List<FollowUser> remoteList,
    required DateTime curLast,
  }) {
    final Map<String, FollowUser> result = {};
    final localMap = {for (var item in localList) item.id: item};
    final remoteMap = {for (var item in remoteList) item.id: item};
    for (var localItem in localList) {
      var remoteItem = remoteMap[localItem.id];
      if (remoteItem != null) {
        // 两边都有记录，需要合并
        if (localItem.deleted && remoteItem.deleted) {
          // 两边都是墓碑，保留 updateTime 更新的
          result[localItem.id] =
              localItem.deletionTimeMillis >= remoteItem.deletionTimeMillis
                  ? localItem
                  : remoteItem;
        } else if (localItem.deleted) {
          // 本地是墓碑，远程是正常记录
          // 如果本地墓碑时间晚于远程添加时间，则保留墓碑
          if (localItem.deletionTimeMillis >= remoteItem.followTimeMillis) {
            result[localItem.id] = localItem;
          } else {
            // 远程重新关注了，清除墓碑
            remoteItem.deleted = false;
            remoteItem.updateTime = 0;
            result[remoteItem.id] = remoteItem;
          }
        } else if (remoteItem.deleted) {
          // 远程是墓碑，本地是正常记录
          // 如果远程墓碑时间晚于本地添加时间，则应用远程墓碑
          if (remoteItem.deletionTimeMillis >= localItem.followTimeMillis) {
            result[remoteItem.id] = remoteItem;
          } else {
            // 本地重新关注了，保留本地
            result[localItem.id] = localItem;
          }
        } else {
          // 两边都是正常记录，合并观看时长
          final merged = _copyFollow(localItem);
          final remoteSeconds =
              (remoteItem.watchDuration ?? "00:00:00").toDuration().inSeconds;
          final localSeconds =
              (localItem.watchDuration ?? "00:00:00").toDuration().inSeconds;
          // 上次远端上传成功但本地清零失败时，两端总时长已一致，残留的
          // syncDuration 不能再次叠加。
          merged.watchDurationSec = localSeconds == remoteSeconds
              ? remoteSeconds
              : remoteSeconds + localItem.syncDuration;
          merged.watchDuration =
              Duration(seconds: merged.watchDurationSec).toHMSString();
          merged.syncDuration = 0;
          result[localItem.id] = merged;
        }
      } else {
        // 仅本地有记录
        if (localItem.deleted) {
          // 墓碑不能按同步时间自动淘汰，否则长期离线设备可能重新带回旧关注。
          result[localItem.id] = localItem;
        } else {
          // 本地是正常记录，如果添加时间在上次同步之后，保留
          if (localItem.addTime.isAfter(curLast)) {
            final snapshot = _copyFollow(localItem);
            snapshot.syncDuration = 0;
            result[localItem.id] = snapshot;
          }
        }
      }
    }

    for (var remoteItem in remoteList) {
      if (!localMap.containsKey(remoteItem.id)) {
        // 仅远程有记录
        if (remoteItem.deleted) {
          // 同样永久保留远程墓碑，直到出现时间更新的重新关注记录。
          result[remoteItem.id] = remoteItem;
        } else {
          // 远程是正常记录，如果添加时间在上次同步之后，保留
          if (remoteItem.addTime.isAfter(curLast)) {
            result[remoteItem.id] = remoteItem;
          }
        }
      }
    }
    return result.values.toList();
  }

  FollowUser _copyFollow(FollowUser item) => FollowUser.fromJson(item.toJson());
}
