import 'dart:io';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:window_manager/window_manager.dart';

class WindowService extends GetxService implements WindowListener {
  static WindowService get instance => Get.find<WindowService>();

  final RxBool isPIP = false.obs;
  final RxBool isMaximized = false.obs;
  final RxBool isFullScreen = false.obs;
  final RxBool isFocused = true.obs;

  WindowService() {
    windowManager.addListener(this);
  }

  @override
  void onClose() {
    windowManager.removeListener(this);
    super.onClose();
  }

  Future<void> init() async {
    final windowOptions = WindowOptions(
      minimumSize: const Size(280, 280),
      center: false,
      title: 'Slive',
      // Linux 使用应用内标题栏；原生装饰始终保持隐藏，避免全屏/小窗
      // 往返时出现双标题栏和内容区域跳动。
      titleBarStyle:
          Platform.isLinux ? TitleBarStyle.hidden : TitleBarStyle.normal,
      windowButtonVisibility: !Platform.isLinux,
    );

    await windowManager.waitUntilReadyToShow(windowOptions);
    await resize();
    await _syncWindowState();
    await windowManager.show();
    await windowManager.focus();
    isFocused.value = true;
  }

  Future<void> resize() async {
    // 初始分辨率默认 1920×1080
    final width = LocalStorageService.instance
        .getValue(LocalStorageService.kWindowWidth, 1280.0);
    final height = LocalStorageService.instance
        .getValue(LocalStorageService.kWindowHeight, 720.0);
    final x = LocalStorageService.instance
        .getValue(LocalStorageService.kWindowX, 320.0);
    final y = LocalStorageService.instance
        .getValue(LocalStorageService.kWindowY, 180.0);
    await windowManager.setBounds(Rect.fromLTWH(x, y, width, height));
  }

  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    isMaximized.value = await windowManager.isMaximized();
  }

  void setPIP(bool value) {
    isPIP.value = value;
  }

  void setFullScreenState(bool value) {
    isFullScreen.value = value;
  }

  Future<void> _syncWindowState() async {
    isMaximized.value = await windowManager.isMaximized();
    isFullScreen.value = await windowManager.isFullScreen();
  }

  @override
  void onWindowBlur() {
    isFocused.value = false;
  }

  @override
  void onWindowClose() {
    if (Platform.isLinux) {
      exit(0);
    }
  }

  @override
  void onWindowDocked() {}

  @override
  void onWindowEnterFullScreen() {
    isFullScreen.value = true;
  }

  @override
  void onWindowEvent(String eventName) {}

  @override
  void onWindowFocus() {
    isFocused.value = true;
  }

  @override
  void onWindowLeaveFullScreen() {
    isFullScreen.value = false;
  }

  @override
  void onWindowMaximize() {
    isMaximized.value = true;
  }

  @override
  void onWindowMinimize() {
    isFocused.value = false;
  }

  @override
  Future<void> onWindowMove() async {}

  @override
  Future<void> onWindowMoved() async {
    if (!isPIP.value) {
      final bounds = await windowManager.getBounds();
      _saveBounds(bounds);
    }
  }

  @override
  Future<void> onWindowResize() async {}

  @override
  Future<void> onWindowResized() async {
    if (!isPIP.value) {
      final bounds = await windowManager.getBounds();
      _saveBounds(bounds);
    }
  }

  @override
  void onWindowRestore() {
    isFocused.value = true;
  }

  @override
  void onWindowUndocked() {}

  @override
  void onWindowUnmaximize() {
    isMaximized.value = false;
  }

  void _saveBounds(Rect bounds) {
    LocalStorageService.instance
        .setValue(LocalStorageService.kWindowX, bounds.left);
    LocalStorageService.instance
        .setValue(LocalStorageService.kWindowY, bounds.top);
    LocalStorageService.instance
        .setValue(LocalStorageService.kWindowWidth, bounds.width);
    LocalStorageService.instance
        .setValue(LocalStorageService.kWindowHeight, bounds.height);
  }
}
