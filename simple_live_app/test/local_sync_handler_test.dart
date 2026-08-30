import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:simple_live_app/hive_registrar.g.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late DBService database;
  late SyncService service;
  late shelf.Handler handler;

  setUpAll(() async {
    Get.testMode = true;
    tempDirectory = await Directory.systemTemp.createTemp(
      'simple_live_local_sync_handler_test_',
    );
    Hive.init(tempDirectory.path);
    Hive.registerAdapters();

    database = Get.put(DBService());
    await database.init();

    service = Get.put(SyncService());
  });

  setUp(() async {
    await database.followBox.clear();
    await database.tagBox.clear();
    service.pairingCode.value = '12345678';
    handler = service.buildHandler(
      allowMissingClientAddress: true,
      activateWrites: true,
    );
  });

  tearDown(() async {
    await service.stop();
  });

  tearDownAll(() async {
    await Hive.close();
    Get.reset();
    await tempDirectory.delete(recursive: true);
  });

  test('本地写入与 HTTP 同步写入共享数据库串行锁', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    var queuedSyncCompleted = false;

    final holdingWrite = database.synchronizedWrite(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;

    final queuedSync = _post(
      handler,
      '/sync/follow?overlay=0',
      [_follow('queued').toJson()],
    ).then((response) {
      queuedSyncCompleted = true;
      return response;
    });
    await Future<void>.delayed(Duration.zero);
    expect(queuedSyncCompleted, isFalse);

    release.complete();
    await holdingWrite;
    final response = await queuedSync;

    expect(response.statusCode, HttpStatus.ok);
    expect(queuedSyncCompleted, isTrue);
    expect(database.followBox.containsKey('queued'), isTrue);
  });

  test('关注与标签 bundle 覆盖写入保持同一批次结果', () async {
    await database.followBox.put('old', _follow('old'));
    await database.tagBox.put(
      'old-tag',
      FollowUserTag(id: 'old-tag', tag: '旧标签', userId: const ['old']),
    );

    final tombstone = _follow(
      'huya_1',
      deleted: true,
      updateTime: DateTime.utc(2026, 8, 30, 11).millisecondsSinceEpoch,
    );
    final response = await _post(
      handler,
      '/sync/follow_bundle?overlay=1',
      {
        'follows': [tombstone.toJson()],
        'tags': [
          FollowUserTag(
            id: 'new-tag',
            tag: '新标签',
            userId: const [],
          ).toJson(),
        ],
      },
    );

    expect(response.statusCode, HttpStatus.ok);
    expect(database.followBox.keys, ['huya_1']);
    expect(database.followBox.get('huya_1')?.deleted, isTrue);
    expect(database.tagBox.keys, ['new-tag']);
  });

  test('非覆盖关注同步会传播墓碑但保留无关记录', () async {
    final followed = _follow(
      'huya_1',
      addTime: DateTime.utc(2026, 8, 30, 10),
    );
    await database.followBox.put(followed.id, followed);
    await database.followBox.put('keep', _follow('keep'));

    final response = await _post(
      handler,
      '/sync/follow?overlay=0',
      [
        _follow(
          'huya_1',
          addTime: followed.addTime,
          deleted: true,
          updateTime: DateTime.utc(2026, 8, 30, 11).millisecondsSinceEpoch,
        ).toJson(),
      ],
    );

    expect(response.statusCode, HttpStatus.ok);
    expect(database.followBox.get('huya_1')?.deleted, isTrue);
    expect(database.followBox.containsKey('keep'), isTrue);
  });

  test('旧墓碑不会因后续非覆盖同步被自动清理', () async {
    final oldTombstone = _follow(
      'old-deleted',
      deleted: true,
      updateTime: DateTime.utc(2026, 7, 1).millisecondsSinceEpoch,
    );
    await database.followBox.put(oldTombstone.id, oldTombstone);

    final response = await _post(
      handler,
      '/sync/follow?overlay=0',
      [_follow('new-follow').toJson()],
    );

    expect(response.statusCode, HttpStatus.ok);
    expect(database.followBox.get(oldTombstone.id)?.deleted, isTrue);
    expect(database.followBox.containsKey('new-follow'), isTrue);
  });

  test('bundle 字段类型无效时返回 400 且不改动数据库', () async {
    await database.followBox.put('keep', _follow('keep'));

    final response = await _post(
      handler,
      '/sync/follow_bundle?overlay=1',
      const {
        'follows': 'invalid',
        'tags': [],
      },
    );

    expect(response.statusCode, HttpStatus.badRequest);
    expect(database.followBox.keys, ['keep']);
  });

  test('生产 handler 缺少连接来源上下文时默认拒绝访问', () async {
    final strictHandler = service.buildHandler(activateWrites: true);

    final response = await _post(
      strictHandler,
      '/sync/follow?overlay=0',
      const [],
    );

    expect(response.statusCode, HttpStatus.forbidden);
  });

  test('服务停止后拒绝已经构建 handler 的新写入', () async {
    await service.stop();
    service.pairingCode.value = '12345678';

    final response = await _post(
      handler,
      '/sync/follow?overlay=0',
      [_follow('late-write').toJson()],
    );

    expect(response.statusCode, HttpStatus.serviceUnavailable);
    expect(database.followBox.containsKey('late-write'), isFalse);
  });

  test('错误配对码在达到阈值后返回 429', () async {
    service.pairingCode.value = '12345678';

    shelf.Response? response;
    for (var index = 0; index < 5; index++) {
      response = await _post(
        handler,
        '/sync/follow?overlay=0',
        const [],
        pairingCode: '00000000',
      );
    }

    expect(response?.statusCode, HttpStatus.tooManyRequests);
    expect(response?.headers[HttpHeaders.retryAfterHeader], isNotNull);
  });
}

Future<shelf.Response> _post(
  shelf.Handler handler,
  String path,
  dynamic body, {
  String pairingCode = '12345678',
}) async {
  return await handler(
    shelf.Request(
      'POST',
      Uri.parse('http://localhost$path'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        SyncService.pairingCodeHeader: pairingCode,
      },
      body: json.encode(body),
    ),
  );
}

FollowUser _follow(
  String id, {
  DateTime? addTime,
  bool deleted = false,
  int updateTime = 0,
}) {
  return FollowUser(
    id: id,
    roomId: id,
    siteId: 'huya',
    userName: id,
    face: '',
    addTime: addTime ?? DateTime.utc(2026, 8, 30, 8),
    deleted: deleted,
    updateTime: updateTime,
  );
}
