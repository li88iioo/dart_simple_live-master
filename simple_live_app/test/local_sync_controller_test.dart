import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/modules/sync/local_sync/local_sync_controller.dart';
import 'package:simple_live_app/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  test('页面在延迟初始化前关闭时不会启动同步服务', () async {
    final service = _BlockingSyncService();
    Get.put<SyncService>(service);
    Get.put(LocalSyncController(null));

    await Get.delete<LocalSyncController>(force: true);
    await Future<void>.delayed(Duration.zero);

    expect(service.startCalls, 0);
    expect(service.refreshCalls, 0);
    expect(service.stopCalls, 1);
  });

  test('页面在服务启动期间关闭时不会被刷新流程重新拉起', () async {
    final service = _BlockingSyncService();
    Get.put<SyncService>(service);
    Get.put(LocalSyncController(null));

    await Future<void>.delayed(Duration.zero);
    expect(service.startCalls, 1);

    await Get.delete<LocalSyncController>(force: true);
    expect(service.stopCalls, 1);

    service.completeStart();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(service.startCalls, 1);
    expect(service.refreshCalls, 0);
  });
}

class _BlockingSyncService extends SyncService {
  final Completer<void> _startCompleter = Completer<void>();

  int startCalls = 0;
  int refreshCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> start() {
    startCalls++;
    return _startCompleter.future;
  }

  @override
  Future<void> refreshClients({bool ensureStarted = true}) async {
    refreshCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  void completeStart() {
    if (!_startCompleter.isCompleted) {
      _startCompleter.complete();
    }
  }
}
