import 'dart:async';
import 'dart:io';
import 'package:auto_orientation_v2/auto_orientation_v2.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter_image_gallery_saver/flutter_image_gallery_saver.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/services/window_service.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/custom_throttle.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

mixin PlayerMixin {
  GlobalKey<VideoState> globalPlayerKey = GlobalKey<VideoState>();
  GlobalKey globalDanmuKey = GlobalKey();

  /// 播放器实例
  late final player = Player(
    configuration: PlayerConfiguration(
      title: "Slive Player",
      logLevel: AppSettingsController.instance.logEnable.value
          ? MPVLogLevel.debug
          : MPVLogLevel.error,
    ),
  );

  /// 初始化播放器并设置 ao 参数
  Future<void> initializePlayer() async {
    var pp = player.platform as NativePlayer;
    // 设置音频输出驱动
    if (AppSettingsController.instance.customPlayerOutput.value) {
      await pp.setProperty(
        'ao',
        AppSettingsController.instance.audioOutputDriver.value,
      );
    } else if (Platform.isLinux) {
      await pp.setProperty('ao', 'alsa');
    }
    // media_kit 仓库更新导致的问题，临时解决办法
    if (Platform.isAndroid) {
      // 通过错误参数强制media_kit不seek, 解决了加载-pause-seek 在直播流上的开屏问题
      await pp.setProperty('force-seekable', 'yes');
    }
    // 低内存管理
    //
    // 根据：https://mpv.io/manual/stable/#cache
    // --cache=<yes|no|auto>// --cache-secs=<seconds>
    // --demuxer-seekable-cache=<yes|no|auto>
    // --demuxer-max-back-bytes=<bytesize>
    // --demuxer-donate-buffer==<yes|no>
    //
    // 内存换空间, 同时通过调整参数禁用mpv回放缓存（直播暂时不需要）
    // hls流/令牌流/.. 根据mdk-sdk作者回复, rtsp 在 ffmpeg存在内存泄露, 这意味着我们只能等待修复
    // temporary fix of android platform
    if (!Platform.isAndroid) {
      await pp.setProperty("cache", "no");
      await pp.setProperty("cache-secs", "0");
      await pp.setProperty('demuxer-seekable-cache', 'no');
      await pp.setProperty('demuxer-donate-buffer', 'no');
      await pp.setProperty("demuxer-max-back-bytes", "0");
    }
    // 在所有平台上正确启用双重缓存,覆写mpv设置
    if (AppSettingsController.instance.videoDoubleBuffering.value) {
      final directory = await getTemporaryDirectory();
      await pp.setProperty("cache", "yes");
      await pp.setProperty("cache-secs", "3");
      await pp.setProperty('demuxer-seekable-cache', 'yes');
      await pp.setProperty('demuxer-donate-buffer', 'yes');
      await pp.setProperty("demuxer-cache-dir", directory.path);
    }
    // bili/douyin流存在时间戳跳变问题
    // 真机建议-空间换内存-暂时不需要
    //  windows:
    //  icc-cache-dir = "~~/cache/icc";
    //  gpu-shader-cache-dir = "~~/cache/shader"
    //  watch-later-dir = "~~/cache/watch_later"
  }

  /// 视频控制器
  late final videoController = VideoController(
    player,
    configuration: AppSettingsController.instance.customPlayerOutput.value
        ? VideoControllerConfiguration(
            vo: AppSettingsController.instance.videoOutputDriver.value,
            hwdec: AppSettingsController.instance.videoHardwareDecoder.value,
          )
        : AppSettingsController.instance.playerCompatMode.value
            ? const VideoControllerConfiguration(
                vo: 'mediacodec_embed',
                hwdec: 'mediacodec',
              )
            : VideoControllerConfiguration(
                enableHardwareAcceleration:
                    AppSettingsController.instance.hardwareDecode.value,
                androidAttachSurfaceAfterVideoParameters: false,
              ),
  );
}
mixin PlayerStateMixin on PlayerMixin {
  ///音量控制条计时器
  Timer? hidevolumeTimer;

  /// 是否进入桌面端小窗
  RxBool smallWindowState = false.obs;

  /// 是否显示弹幕
  RxBool showDanmakuState = false.obs;

  /// 是否显示控制器
  RxBool showControlsState = false.obs;

  /// 是否显示设置窗口
  RxBool showSettingState = false.obs;

  /// 是否显示弹幕设置窗口
  RxBool showDanmakuSettingState = false.obs;

  /// 是否处于锁定控制器状态
  RxBool lockControlsState = false.obs;

  /// 是否处于全屏状态
  RxBool fullScreenState = false.obs;

  /// 显示手势Tip
  RxBool showGestureTip = false.obs;

  /// 手势Tip文本
  RxString gestureTipText = "".obs;

  /// 显示提示底部Tip
  RxBool showBottomTip = false.obs;

  /// 是否显示OSD统计信息
  RxBool showOSDStats = false.obs;

  /// 是否处于暂停状态
  RxBool playerPausedState = false.obs;

  /// 提示底部Tip文本
  RxString bottomTipText = "".obs;

  /// 自动隐藏控制器计时器
  Timer? hideControlsTimer;

  /// 自动隐藏提示计时器
  Timer? hideSeekTipTimer;

  /// 是否为竖屏直播间
  var isVertical = false.obs;

  Widget? danmakuView;

  var showQualites = false.obs;
  var showLines = false.obs;

  /// 隐藏控制器
  void hideControls() {
    showControlsState.value = false;
    hideControlsTimer?.cancel();
  }

  void setLockState() {
    lockControlsState.value = !lockControlsState.value;
    if (lockControlsState.value) {
      showControlsState.value = false;
    } else {
      showControlsState.value = true;
    }
  }

  /// 显示控制器
  void showControls() {
    showControlsState.value = true;
    resetHideControlsTimer();
  }

  /// 开始隐藏控制器计时
  /// - 当点击控制器上时功能时需要重新计时
  void resetHideControlsTimer() {
    hideControlsTimer?.cancel();

    hideControlsTimer = Timer(
      const Duration(
        seconds: 5,
      ),
      hideControls,
    );
  }

  void updateScaleMode() {
    var boxFit = BoxFit.contain;
    double? aspectRatio;
    if (player.state.width != null && player.state.height != null) {
      aspectRatio = player.state.width! / player.state.height!;
    }

    if (AppSettingsController.instance.scaleMode.value == 0) {
      boxFit = BoxFit.contain;
    } else if (AppSettingsController.instance.scaleMode.value == 1) {
      boxFit = BoxFit.fill;
    } else if (AppSettingsController.instance.scaleMode.value == 2) {
      boxFit = BoxFit.cover;
    } else if (AppSettingsController.instance.scaleMode.value == 3) {
      boxFit = BoxFit.contain;
      aspectRatio = 16 / 9;
    } else if (AppSettingsController.instance.scaleMode.value == 4) {
      boxFit = BoxFit.contain;
      aspectRatio = 4 / 3;
    }
    globalPlayerKey.currentState?.update(
      aspectRatio: aspectRatio,
      fit: boxFit,
    );
  }
}
mixin PlayerDanmakuMixin on PlayerStateMixin {
  /// 弹幕控制器
  late DanmakuController? danmakuController;

  void initDanmakuController(DanmakuController e) {
    danmakuController = e;
  }

  void updateDanmuOption(DanmakuOption? option) {
    if (option == null) return;
    danmakuController?.updateOption(option);
  }

  void disposeDanmakuController() {
    danmakuController?.clear();
  }

  void addDanmaku(List<DanmakuContentItem> items) {
    if (!showDanmakuState.value) {
      return;
    }
    for (var item in items) {
      danmakuController?.addDanmaku(item);
    }
  }
}
mixin PlayerSystemMixin on PlayerMixin, PlayerStateMixin, PlayerDanmakuMixin {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  final screenBrightness = ScreenBrightness();
  final VolumeController volumeController = VolumeController.instance;
  final pip = Floating();
  StreamSubscription<PiPStatus>? _pipSubscription;
  bool _systemUiChanged = false;
  bool _orientationChanged = false;
  bool _brightnessChanged = false;

  /// 初始化一些系统状态
  void initSystem() async {
    if (Platform.isAndroid || Platform.isIOS) {
      volumeController.showSystemUI = false;
    }

    // 屏幕常亮
    //WakelockPlus.enable();

    // 开始隐藏计时
    resetHideControlsTimer();
  }

  /// 释放一些系统状态
  Future resetSystem() async {
    _pipSubscription?.cancel();
    // 普通竖屏观看不会改系统 UI、方向或亮度，退出时不要无条件触发
    // WindowInsets/配置更新，避免返回动画结束后又发生一次整窗布局。
    if (_systemUiChanged) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      _systemUiChanged = false;
    }
    if (_orientationChanged) {
      await setPortraitOrientation();
      _orientationChanged = false;
    }
    if (_brightnessChanged &&
        (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      try {
        await screenBrightness.resetApplicationScreenBrightness();
      } catch (e) {
        Log.logPrint(e);
      }
      _brightnessChanged = false;
    }

    await WakelockPlus.disable();
  }

  /// 进入全屏
  void enterFullScreen() async {
    fullScreenState.value = true;
    if (Platform.isAndroid || Platform.isIOS) {
      //全屏
      _systemUiChanged = true;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      if (!isVertical.value) {
        //横屏
        _orientationChanged = true;
        setLandscapeOrientation();
      }
    } else {
      WindowService.instance.setFullScreenState(true);
      // Linux 原生标题栏由根窗口壳永久隐藏；只在其它桌面平台
      // 沿用原有标题栏切换，避免退出全屏时出现双标题栏。
      if (!Platform.isLinux && await windowManager.isMaximized()) {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      }
      await windowManager.setFullScreen(true);
    }
    //danmakuController?.clear();
  }

  /// 退出全屏
  void exitFull() async {
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      _systemUiChanged = false;
      setPortraitOrientation();
      _orientationChanged = false;
    } else {
      WindowService.instance.setFullScreenState(false);
      final isMaximized = await windowManager.isMaximized();
      await windowManager.setFullScreen(false);
      if (!Platform.isLinux && isMaximized) {
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      }
    }
    fullScreenState.value = false;

    //danmakuController?.clear();
  }

  Size? _lastWindowSize;
  Offset? _lastWindowPosition;

  ///小窗模式()
  void enterSmallWindow() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      fullScreenState.value = true;
      smallWindowState.value = true;
      WindowService.instance.setPIP(smallWindowState.value);

      // 读取窗口大小
      _lastWindowSize = await windowManager.getSize();
      _lastWindowPosition = await windowManager.getPosition();

      if (!Platform.isLinux) {
        windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      }
      // 获取视频窗口大小
      var width = player.state.width ?? 16;
      var height = player.state.height ?? 9;

      // 横屏还是竖屏
      if (height > width) {
        var aspectRatio = width / height;
        windowManager.setSize(Size(400, 400 / aspectRatio));
      } else {
        var aspectRatio = height / width;
        windowManager.setSize(Size(280 / aspectRatio, 280));
      }

      windowManager.setAlwaysOnTop(true);
    }
  }

  ///退出小窗模式()
  void exitSmallWindow() {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      fullScreenState.value = false;
      smallWindowState.value = false;
      WindowService.instance.setPIP(smallWindowState.value);
      if (!Platform.isLinux) {
        windowManager.setTitleBarStyle(TitleBarStyle.normal);
      }
      windowManager.setSize(_lastWindowSize!);
      windowManager.setPosition(_lastWindowPosition!);
      windowManager.setAlwaysOnTop(false);
      //windowManager.setAlignment(Alignment.center);
    }
  }

  /// 设置横屏
  Future setLandscapeOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.landscapeAutoMode();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  /// 设置竖屏
  Future setPortraitOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.portraitAutoMode();
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  /// 是否是IOS16以下
  Future<bool> beforeIOS16() async {
    if (Platform.isIOS) {
      var info = await deviceInfo.iosInfo;
      var version = info.systemVersion;
      var versionInt = int.tryParse(version.split('.').first) ?? 0;
      return versionInt < 16;
    } else {
      return false;
    }
  }

  Future saveScreenshot() async {
    final imageSaver = ImageGallerySaver();
    try {
      SmartDialog.showLoading(msg: "正在保存截图");
      //检查相册权限,仅iOS需要
      var permission = await Utils.checkPhotoPermission();
      if (!permission) {
        SmartDialog.showToast("没有相册权限");
        SmartDialog.dismiss(status: SmartStatus.loading);
        return;
      }

      var imageData = await player.screenshot();
      if (imageData == null) {
        SmartDialog.showToast("截图失败,数据为空");
        SmartDialog.dismiss(status: SmartStatus.loading);
        return;
      }

      if (Platform.isIOS || Platform.isAndroid) {
        await imageSaver.saveImage(
          imageData,
        );
        SmartDialog.showToast("已保存截图至相册");
      } else {
        //选择保存文件夹
        var path = await FilePicker.platform.saveFile(
          allowedExtensions: ["jpg"],
          type: FileType.image,
          fileName: "${DateTime.now().millisecondsSinceEpoch}.jpg",
        );
        if (path == null) {
          SmartDialog.showToast("取消保存");
          SmartDialog.dismiss(status: SmartStatus.loading);
          return;
        }
        var file = File(path);
        await file.writeAsBytes(imageData);
        SmartDialog.showToast("已保存截图至${file.path}");
      }
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("截图失败");
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  /// 开启小窗播放前弹幕状态
  bool danmakuStateBeforePIP = false;

  Future enablePIP() async {
    if (!Platform.isAndroid) {
      return;
    }
    if (await pip.isPipAvailable == false) {
      SmartDialog.showToast("设备不支持小窗播放");
      return;
    }
    danmakuStateBeforePIP = showDanmakuState.value;
    //关闭并清除弹幕
    if (AppSettingsController.instance.pipHideDanmu.value &&
        danmakuStateBeforePIP) {
      showDanmakuState.value = false;
    }
    danmakuController?.clear();
    //关闭控制器
    showControlsState.value = false;

    //监听事件
    var width = player.state.width ?? 0;
    var height = player.state.height ?? 0;
    Rational ratio = const Rational.landscape();
    if (height > width) {
      ratio = const Rational.vertical();
    } else {
      ratio = const Rational.landscape();
    }
    await pip.enable(
      ImmediatePiP(
        aspectRatio: ratio,
      ),
    );

    _pipSubscription ??= pip.pipStatusStream.listen((event) {
      if (event == PiPStatus.disabled) {
        // 返回前台时恢复弹幕
        danmakuController?.resume();
        showDanmakuState.value = danmakuStateBeforePIP;
      }
      Log.w(event.toString());
    });
  }
}
mixin PlayerGestureControlMixin
    on PlayerStateMixin, PlayerMixin, PlayerSystemMixin {
  /// 单击显示/隐藏控制器
  void onTap() {
    if (showControlsState.value) {
      hideControls();
    } else {
      showControls();
    }
  }

  //桌面端操控
  void onEnter(PointerEnterEvent event) {
    if (!showControlsState.value) {
      showControls();
    }
  }

  void onExit(PointerExitEvent event) {
    if (showControlsState.value) {
      hideControls();
    }
  }

  void onHover(PointerHoverEvent event, BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final targetPosition = screenHeight * 0.25; // 计算屏幕顶部25%的位置
    if (event.position.dy <= targetPosition ||
        event.position.dy >= targetPosition * 3) {
      if (!showControlsState.value) {
        showControls();
      }
    }
  }

  /// 双击全屏/退出全屏
  void onDoubleTap(TapDownDetails details) {
    if (lockControlsState.value) {
      return;
    }
    if (fullScreenState.value) {
      exitFull();
    } else {
      enterFullScreen();
    }
  }

  bool verticalDragging = false;
  bool leftVerticalDrag = false;
  var _currentVolume = 0.0;
  var _currentBrightness = 1.0;
  var verStartPosition = 0.0;

  DelayedThrottle? throttle;

  /// 竖向手势开始
  void onVerticalDragStart(DragStartDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }

    final dy = details.globalPosition.dy;
    // 开始位置必须是中间2/4的位置
    if (dy < Get.height * 0.25 || dy > Get.height * 0.75) {
      return;
    }

    verStartPosition = dy;
    leftVerticalDrag = details.globalPosition.dx < Get.width / 2;

    throttle = DelayedThrottle(200);

    verticalDragging = true;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      showGestureTip.value = true;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      _currentVolume = await volumeController.getVolume();
    }
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      _currentBrightness = await screenBrightness.application;
    }
  }

  /// 竖向手势更新
  void onVerticalDragUpdate(DragUpdateDetails e) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    if (verticalDragging == false) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    //String text = "";
    //double value = 0.0;

    Log.logPrint("$verStartPosition/${e.globalPosition.dy}");

    if (leftVerticalDrag) {
      setGestureBrightness(e.globalPosition.dy);
    } else {
      setGestureVolume(e.globalPosition.dy);
    }
  }

  int lastVolume = -1; // it's ok to be -1

  void setGestureVolume(double dy) {
    double value = 0.0;
    double seek;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / (Get.height * 0.5));

      seek = _currentVolume - value;
      if (seek < 0) {
        seek = 0;
      }
    } else {
      value = ((dy - verStartPosition) / (Get.height * 0.5));
      seek = value.abs() + _currentVolume;
      if (seek > 1) {
        seek = 1;
      }
    }
    int volume = _convertVolume((seek * 100).round());
    if (volume == lastVolume) {
      return;
    }
    lastVolume = volume;
    // update UI outside throttle to make it more fluent
    gestureTipText.value = "音量 $volume%";
    throttle?.invoke(() async => await _realSetVolume(volume));
  }

  // 0 to 100, 5 step each
  int _convertVolume(int volume) {
    return (volume / 5).round() * 5;
  }

  Future _realSetVolume(int volume) async {
    Log.logPrint(volume);
    volumeController.setVolume(volume / 100);
  }

  void setGestureBrightness(double dy) {
    double value = 0.0;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / (Get.height * 0.5));

      var seek = _currentBrightness - value;
      if (seek < 0) {
        seek = 0;
      }
      _brightnessChanged = true;
      screenBrightness.setApplicationScreenBrightness(seek);

      gestureTipText.value = "亮度 ${(seek * 100).toInt()}%";
      Log.logPrint(value);
    } else {
      value = ((dy - verStartPosition) / (Get.height * 0.5));
      var seek = value.abs() + _currentBrightness;
      if (seek > 1) {
        seek = 1;
      }

      _brightnessChanged = true;
      screenBrightness.setApplicationScreenBrightness(seek);
      gestureTipText.value = "亮度 ${(seek * 100).toInt()}%";
      Log.logPrint(value);
    }
  }

  /// 竖向手势完成
  void onVerticalDragEnd(DragEndDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    throttle = null;
    verticalDragging = false;
    leftVerticalDrag = false;
    showGestureTip.value = false;
  }
}

class PlayerController extends BaseController
    with
        PlayerMixin,
        PlayerStateMixin,
        PlayerDanmakuMixin,
        PlayerSystemMixin,
        PlayerGestureControlMixin {
  /// 路由转场结束前先显示静态播放器占位，避免 media_kit 原生播放器、
  /// 事件流和 Video Surface 在导航首帧同步创建。
  final RxBool playerRuntimeReady = false.obs;
  Completer<void>? _playerRuntimeCompleter;
  bool _playerRuntimeInitialized = false;
  bool _playerRuntimeScheduled = false;
  bool _closing = false;

  @override
  void onInit() {
    initSystem();
    _schedulePlayerRuntimeInitialization();
    super.onInit();
  }

  void _schedulePlayerRuntimeInitialization() {
    if (_playerRuntimeScheduled || _playerRuntimeInitialized) return;
    _playerRuntimeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(
        SliveMotion.route,
      );
      if (!_closing && !isClosed) {
        try {
          await ensurePlayerRuntimeReady();
        } catch (_) {
          // 初始化错误已经记录；后续播放地址加载会走现有错误处理。
        }
      }
    });
  }

  Future<void> ensurePlayerRuntimeReady() {
    final existing = _playerRuntimeCompleter;
    if (existing != null) return existing.future;
    if (_playerRuntimeInitialized) return Future<void>.value();

    final completer = Completer<void>();
    _playerRuntimeCompleter = completer;
    () async {
      try {
        if (_closing || isClosed) {
          completer.complete();
          return;
        }
        _playerRuntimeInitialized = true;
        initStream();
        await player.setVolume(
          AppSettingsController.instance.playerVolume.value,
        );
        if (!_closing && !isClosed) {
          playerRuntimeReady.value = true;
        }
      } catch (error, stackTrace) {
        Log.e('播放器运行时初始化失败: $error', stackTrace);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        return;
      }
      if (!completer.isCompleted) completer.complete();
    }();
    return completer.future;
  }

  StreamSubscription<String>? _errorSubscription;
  StreamSubscription? _completedSubscription;
  StreamSubscription? _widthSubscription;
  StreamSubscription? _heightSubscription;
  StreamSubscription? _logSubscription;
  StreamSubscription? _playingSubscription;
  StreamSubscription? _escSubscription;
  StreamSubscription? _spaceSubscription;

  void initStream() {
    _errorSubscription = player.stream.error.listen((event) {
      Log.d("播放器错误：$event");
      // 跳过无音频输出的错误
      // Could not open/initialize audio device -> no sound.
      if (event.contains('no sound.')) {
        return;
      }
      //SmartDialog.showToast(event);
      mediaError(event);
    });

    _playingSubscription = player.stream.playing.listen((event) {
      playerPausedState.value = !event;
      if (event) {
        WakelockPlus.enable();
        danmakuController?.resume();
        Log.d("Playing");
      } else {
        WakelockPlus.disable();
        danmakuController?.pause();
        Log.d("Paused");
      }
    });

    _completedSubscription = player.stream.completed.listen((event) {
      if (event) {
        mediaEnd();
      }
    });
    _logSubscription = player.stream.log.listen((event) {
      Log.d("播放器日志：$event");
    });
    _widthSubscription = player.stream.width.listen((event) {
      Log.d(
          'width:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      if (player.state.width == null) {
        return;
      } else {
        // 可获取直播流size时且不为全屏模式时判断是否进入全屏模式
        isVertical.value = player.state.height! > player.state.width!;
        if (AppSettingsController.instance.autoFullScreen.value &&
            !fullScreenState.value) {
          enterFullScreen();
        }
      }
    });
    _heightSubscription = player.stream.height.listen((event) {
      Log.d(
          'height:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
    });
    _escSubscription =
        EventBus.instance.listen(EventBus.kEscapePressed, (event) {
      exitFull();
    });
    _spaceSubscription =
        EventBus.instance.listen(EventBus.kSpacePressed, (event) {
      togglePlayPause();
    });
  }

  void disposeStream() {
    _errorSubscription?.cancel();
    _completedSubscription?.cancel();
    _widthSubscription?.cancel();
    _heightSubscription?.cancel();
    _logSubscription?.cancel();
    _pipSubscription?.cancel();
    _playingSubscription?.cancel();
    _escSubscription?.cancel();
    _spaceSubscription?.cancel();
  }

  void mediaEnd() {
    WakelockPlus.disable();
  }

  void mediaError(String error) {
    // 弱网调整：用户自责
    // WakelockPlus.disable();
  }

  Future<void> toggleOSDStats() async {
    showOSDStats.value = !showOSDStats.value;
    if (player.platform is NativePlayer) {
      await (player.platform as NativePlayer).command([
        'script-binding',
        'stats/display-page-1-toggle',
      ]);
    }
  }

  /// 切换播放/暂停
  void togglePlayPause() {
    player.playOrPause();
  }

  void showDebugInfo() {
    Utils.showBottomSheet(
      title: "播放信息",
      child: ListView(
        children: [
          Obx(() => SwitchListTile(
              title: const Text("OSD 显示"),
              value: showOSDStats.value,
              onChanged: (value) => toggleOSDStats())),
          ListTile(
            title: const Text("Resolution"),
            subtitle: Text('${player.state.width}x${player.state.height}'),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      "Resolution\n${player.state.width}x${player.state.height}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("VideoParams"),
            subtitle: Text(player.state.videoParams.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "VideoParams\n${player.state.videoParams}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioParams"),
            subtitle: Text(player.state.audioParams.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "AudioParams\n${player.state.audioParams}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("Media"),
            subtitle: Text(player.state.playlist.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "Media\n${player.state.playlist}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioTrack"),
            subtitle: Text(player.state.track.audio.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "AudioTrack\n${player.state.track.audio}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("VideoTrack"),
            subtitle: Text(player.state.track.video.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "VideoTrack\n${player.state.track.audio}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioBitrate"),
            subtitle: Text(player.state.audioBitrate.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "AudioBitrate\n${player.state.audioBitrate}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("Volume"),
            subtitle: Text(player.state.volume.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "Volume\n${player.state.volume}",
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    Log.w("播放器关闭");
    _closing = true;
    if (smallWindowState.value) {
      exitSmallWindow();
    }

    final runtimeInitialized = _playerRuntimeInitialized;
    final closingDanmakuController = danmakuController;
    danmakuController = null;
    if (runtimeInitialized) {
      disposeStream();
    }
    super.onClose();

    if (runtimeInitialized) {
      // 路由销毁后先停声，但不在返回动画的完成帧销毁 native player。
      // pause 是异步平台命令；不等待它，避免阻塞 GetX 的 route dispose。
      unawaited(player.pause());
    }

    // player.dispose 会释放 Texture/native 解码器，和 WebSocket/Rust 清理
    // 同帧执行时真机会连续出现 25~50ms 长帧。先错开时间，再交给 idle
    // 优先级；若用户已经开始滚动，清理会自动让位给 animation 帧。
    Future<void>.delayed(SliveMotion.playerCleanup, () {
      SchedulerBinding.instance.scheduleTask<void>(
        () async {
          closingDanmakuController?.clear();
          await resetSystem();
          if (runtimeInitialized) {
            await player.dispose();
          }
        },
        Priority.idle,
        debugLabel: 'slive-player-cleanup',
      );
    });
  }
}
