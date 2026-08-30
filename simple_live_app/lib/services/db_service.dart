import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fractional_indexing_dart/fractional_indexing_dart.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:synchronized/synchronized.dart';

class DBService extends GetxService {
  static DBService get instance => Get.find<DBService>();

  late Box<History> historyBox;
  late Box<FollowUser> followBox;
  late Box<FollowUserTag> tagBox;

  final Lock _writeLock = Lock();

  Future init() async {
    historyBox = await Hive.openBox('History');
    followBox = await Hive.openBox('FollowUser');
    tagBox = await Hive.openBox('FollowUserTag');
  }

  Future<T> synchronizedWrite<T>(FutureOr<T> Function() action) {
    return _writeLock.synchronized(action);
  }

  Future<void> clearFollowTag() {
    return synchronizedWrite(() => tagBox.clear());
  }

  bool getFollowTagExist(String id) {
    return tagBox.containsKey(id);
  }

  List<FollowUserTag> getFollowTagList() {
    return tagBox.values.toList();
  }

  Future<void> updateFollowTag(FollowUserTag followTag) {
    return synchronizedWrite(() => tagBox.put(followTag.id, followTag));
  }

  Future<FollowUserTag> addFollowTag(String tag) {
    return synchronizedWrite(() async {
      if (getFollowTagExistByTag(tag)) {
        return getFollowTag(tag)!;
      }
      final lastKey = tagBox.keys.lastOrNull as String?;
      final uniqueId = FractionalIndexing.generateKeyBetween(lastKey, null);
      final followUserTag = FollowUserTag(
        id: uniqueId,
        tag: tag,
        userId: [],
      );
      await tagBox.put(uniqueId, followUserTag);
      return followUserTag;
    });
  }

  Future<void> deleteFollowTag(String id) {
    return synchronizedWrite(() => tagBox.delete(id));
  }

  FollowUserTag? getFollowTag(String tag) {
    return tagBox.values.firstWhereOrNull((item) => item.tag == tag);
  }

  bool getFollowTagExistByTag(String tag) {
    return tagBox.values.any((item) => item.tag == tag);
  }

  bool getFollowExist(String id) {
    final follow = followBox.get(id);
    return follow != null && !follow.deleted;
  }

  List<FollowUser> getFollowList() {
    return followBox.values.where((follow) => !follow.deleted).toList();
  }

  /// 获取所有关注列表（包含墓碑记录），用于同步。
  List<FollowUser> getAllFollowList() {
    return followBox.values.toList();
  }

  Future<void> addFollow(FollowUser follow) {
    return synchronizedWrite(() => followBox.put(follow.id, follow));
  }

  Future<void> deleteFollow(String id) {
    return synchronizedWrite(() => followBox.delete(id));
  }

  History? getHistory(String id) {
    return historyBox.get(id);
  }

  Future<void> addOrUpdateHistory(History history) {
    return synchronizedWrite(() => historyBox.put(history.id, history));
  }

  Future<void> delHistory(String id) {
    return synchronizedWrite(() => historyBox.delete(id));
  }

  List<History> getHistories() {
    final histories = historyBox.values.toList();
    histories.sort((a, b) => b.updateTime.compareTo(a.updateTime));
    return histories;
  }

  Future<void> clearHistory() {
    return synchronizedWrite(() => historyBox.clear());
  }

  Future<void> replaceFollows(Map<String, FollowUser> follows) {
    return synchronizedWrite(() => _stageExactBox(followBox, follows));
  }

  Future<void> replaceFollowTags(Map<String, FollowUserTag> tags) {
    return synchronizedWrite(() => _stageExactBox(tagBox, tags));
  }

  Future<void> replaceHistories(Map<String, History> histories) {
    return synchronizedWrite(() => _stageExactBox(historyBox, histories));
  }

  Future<void> replaceFollowBundle({
    required Map<String, FollowUser> follows,
    required Map<String, FollowUserTag> tags,
  }) {
    return synchronizedWrite(() async {
      await _putTarget(followBox, follows);
      await _putTarget(tagBox, tags);
      await _deleteStaleKeys(tagBox, tags.keys);
      await _deleteStaleKeys(followBox, follows.keys);
    });
  }

  Future<void> _stageExactBox<E>(Box<E> box, Map<String, E> target) async {
    await _putTarget(box, target);
    await _deleteStaleKeys(box, target.keys);
  }

  Future<void> _putTarget<E>(Box<E> box, Map<String, E> target) async {
    if (target.isNotEmpty) {
      await box.putAll(target);
    }
  }

  Future<void> _deleteStaleKeys<E>(
    Box<E> box,
    Iterable<String> retainedKeys,
  ) async {
    final retained = retainedKeys.toSet();
    final staleKeys = box.keys.where((key) => !retained.contains(key)).toList();
    if (staleKeys.isNotEmpty) {
      await box.deleteAll(staleKeys);
    }
  }
}
