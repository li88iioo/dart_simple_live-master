import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/history_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/sync_service.dart';
import 'package:window_manager/window_manager.dart';

class AppShutdownService extends GetxService with WidgetsBindingObserver {
  static AppShutdownService get instance => Get.find<AppShutdownService>();

  Future<void>? _shutdownFuture;
  Future<void>? _flushFuture;

  @override
  void onInit() {
    WidgetsBinding.instance.addObserver(this);
    super.onInit();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(flushTransientState());
    }
  }

  Future<void> flushTransientState() {
    final running = _flushFuture;
    if (running != null) return running;

    late final Future<void> operation;
    operation = _performFlush().whenComplete(() {
      if (identical(_flushFuture, operation)) {
        _flushFuture = null;
      }
    });
    _flushFuture = operation;
    return operation;
  }

  Future<void> _performFlush() async {
    final tasks = <Future<void>>[];
    if (Get.isRegistered<HistoryService>()) {
      tasks.add(HistoryService.instance.flushPending());
    }
    if (Get.isRegistered<LocalStorageService>()) {
      tasks.add(LocalStorageService.instance.flush());
    }
    if (Get.isRegistered<DBService>()) {
      tasks.add(DBService.instance.flush());
    }
    tasks.add(Log.flush());

    for (final task in tasks) {
      try {
        await task;
      } catch (error, stackTrace) {
        Log.e('持久化退出状态失败：$error', stackTrace);
      }
    }
  }

  /// 统一退出入口。先停止网络监听与观看计时，再刷新 Hive，最后交还给
  /// 平台关闭窗口，避免直接 exit(0) 造成观看记录或设置丢失。
  Future<void> requestExit() {
    final running = _shutdownFuture;
    if (running != null) return running;

    late final Future<void> operation;
    operation = _performShutdown().whenComplete(() {
      if (identical(_shutdownFuture, operation)) {
        _shutdownFuture = null;
      }
    });
    _shutdownFuture = operation;
    return operation;
  }

  Future<void> _performShutdown() async {
    if (Get.isRegistered<SyncService>()) {
      try {
        await SyncService.instance.stop();
      } catch (error, stackTrace) {
        Log.e('关闭局域网同步失败：$error', stackTrace);
      }
    }
    if (Get.isRegistered<HistoryService>()) {
      try {
        await HistoryService.instance.stop();
      } catch (error, stackTrace) {
        Log.e('保存最终观看历史失败：$error', stackTrace);
      }
    }
    await flushTransientState();

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
      return;
    }
    await SystemNavigator.pop(animated: true);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
