import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/app/utils/listen_fourth_button.dart';
import 'package:simple_live_app/firebase_options.dart';
import 'package:simple_live_app/hive_registrar.g.dart';
import 'package:simple_live_app/modules/other/debug_log_page.dart';
import 'package:simple_live_app/modules/settings/appstyle_settings/appstyle_setting_contorller.dart';
import 'package:simple_live_app/routes/app_analytics_observer.dart';
import 'package:simple_live_app/routes/app_pages.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/app_shutdown_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/platform_service.dart';
import 'package:simple_live_app/services/firebase_service.dart' as app_firebase;
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/history_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/migration_service.dart';
import 'package:simple_live_app/services/sync_service.dart';
import 'package:simple_live_app/services/window_service.dart';
import 'package:simple_live_app/src/rust/frb_generated.dart';
import 'package:simple_live_app/widgets/desktop/slive_linux_window_frame.dart';
import 'package:simple_live_app/widgets/status/app_loadding_widget.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  //设置状态栏为透明
  const systemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
  );
  SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  runApp(const _SliveBootstrapApp());
}

Future<void> bootstrapApplication() async {
  MediaKit.ensureInitialized();

  // Rust 初始化与 Hive 迁移、服务注册彼此独立，并行执行可以显著缩短冷启动
  // 的纯等待时间；实际页面仍会等必要的本地状态准备完成后再进入。
  final rustInitialization = RustLib.init();
  await MigrationService.migrateData();
  await Hive.initFlutter(
    (!Platform.isAndroid && !Platform.isIOS)
        ? (await getApplicationSupportDirectory()).path
        : null,
  );
  await initServices();
  await Future.wait<void>([
    rustInitialization,
    MigrationService.migrateDataByVersion(),
  ]);
  await initWindow();
}

Future initWindow() async {
  if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    return;
  }
  await windowManager.ensureInitialized();
  await WindowService.instance.init();
}

Future initServices() async {
  Hive.registerAdapters();

  final localStorageService = Get.put(LocalStorageService());
  final dbService = Get.put(DBService());

  // 包信息、本地设置和业务数据库互不依赖，并行打开，避免串行 I/O 放大
  // 首次启动空白时间。
  Log.d("Init LocalStorage Service");
  final results = await Future.wait<Object?>([
    PackageInfo.fromPlatform(),
    localStorageService.init(),
    dbService.init(),
  ]);
  Utils.packageInfo = results.first! as PackageInfo;
  //初始化设置控制器
  Get.put(AppSettingsController());

  await Get.put(AppStyleSettingController()).init();

  Get.put(BiliBiliAccountService());

  Get.put(PlatformService());

  Get.lazyPut<SyncService>(() => SyncService(), fenix: true);

  Get.put(FollowService());

  Get.put(HistoryService());

  Get.put(AppShutdownService());

  // 移动平台不使用 windowManager
  if (!Platform.isAndroid && !Platform.isIOS) {
    Get.put(WindowService());
  }

  initCoreLog();
}

Future<void> startDeferredServices() async {
  final tasks = <Future<void>>[
    BiliBiliAccountService.instance.loadUserInfo(),
    PlatformService.instance.loadDouyinUserInfo(),
  ];

  // Firebase 与账号资料刷新都不是首帧依赖，首屏稳定后再初始化，避免把
  // 网络和平台通道等待叠加到冷启动关键路径。
  if (Platform.isAndroid) {
    tasks.add(_initializeFirebase());
  }

  await Future.wait<void>(
    tasks.map(
      (task) async {
        try {
          await task;
        } catch (error, stackTrace) {
          Log.e('Deferred service initialization failed: $error', stackTrace);
        }
      },
    ),
  );
}

Future<void> _initializeFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  if (!Get.isRegistered<app_firebase.FirebaseService>()) {
    Get.put(app_firebase.FirebaseService());
  }
}

class _SliveBootstrapApp extends StatefulWidget {
  const _SliveBootstrapApp();

  @override
  State<_SliveBootstrapApp> createState() => _SliveBootstrapAppState();
}

class _SliveBootstrapAppState extends State<_SliveBootstrapApp> {
  late final Future<void> _initialization = bootstrapApplication();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.error == null) {
          return const MyApp();
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff5274a9),
              surface: const Color(0xfff6f3ed),
            ),
            scaffoldBackgroundColor: const Color(0xfff6f3ed),
            useMaterial3: true,
          ),
          home: _StartupScreen(error: snapshot.error),
        );
      },
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xfffaf7f2), Color(0xffeef3f7)],
          ),
        ),
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: hasError ? 'Slive 启动失败' : 'Slive 正在启动',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Icon(
                    hasError
                        ? Icons.error_outline_rounded
                        : Icons.live_tv_rounded,
                    size: 31,
                    color: hasError
                        ? const Color(0xffba5b58)
                        : const Color(0xff5274a9),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  hasError ? '启动未完成' : 'Slive',
                  style: const TextStyle(
                    color: Color(0xff2b2623),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasError ? '请重新启动应用后再试' : '正在准备你的直播空间',
                  style: const TextStyle(
                    color: Color(0xff7a716a),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!hasError) ...[
                  const SizedBox(height: 20),
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void initCoreLog() {
  //日志信息
  CoreLog.enableLog =
      !kReleaseMode || AppSettingsController.instance.logEnable.value;
  CoreLog.requestLogType = RequestLogType.short;
  CoreLog.onPrintLog = (level, msg) {
    switch (level) {
      case Level.debug:
        Log.d(msg);
        break;
      case Level.error:
        Log.e(msg, StackTrace.current);
        break;
      case Level.info:
        Log.i(msg);
        break;
      case Level.warning:
        Log.w(msg);
        break;
      default:
        Log.logPrint(msg);
    }
  };
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(startDeferredServices());
    });
  }

  @override
  Widget build(BuildContext context) {
    final styleController = AppStyleSettingController.instance;
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return Obx(() {
          final isDynamicColor = styleController.isDynamic.value;
          final styleColor = Color(styleController.styleColor.value);
          final backgroundStyle = styleController.backgroundStyle;
          // 背景动态取色始终基于系统的浅色中性色，再由主题层派生深色背景，
          // 避免把高饱和强调色或暗色 surface 直接放大为整页底色。
          final dynamicBackgroundSurface =
              lightDynamic?.surfaceContainerLowest ?? lightDynamic?.surface;
          final lightColorScheme =
              lightDynamic != null && darkDynamic != null && isDynamicColor
                  ? lightDynamic
                  : ColorScheme.fromSeed(
                      seedColor: styleColor,
                      brightness: Brightness.light,
                    );
          final darkColorScheme =
              lightDynamic != null && darkDynamic != null && isDynamicColor
                  ? darkDynamic
                  : ColorScheme.fromSeed(
                      seedColor: styleColor,
                      brightness: Brightness.dark,
                    );
          return GetMaterialApp(
            title: "Slive",
            theme: AppStyle.light(
              fontFamily: styleController.curFontName.value,
              colorScheme: lightColorScheme,
              glassMode: styleController.glassMode.value,
              backgroundStyle: backgroundStyle,
              dynamicBackgroundSurface: dynamicBackgroundSurface,
            ),
            darkTheme: AppStyle.darkTheme(
              fontFamily: styleController.curFontName.value,
              colorScheme: darkColorScheme,
              glassMode: styleController.glassMode.value,
              backgroundStyle: backgroundStyle,
              dynamicBackgroundSurface: dynamicBackgroundSurface,
            ),
            themeMode: ThemeMode
                .values[Get.find<AppSettingsController>().themeMode.value],
            initialRoute: RoutePath.kIndex,
            getPages: AppPages.routes,
            // 普通页面交给 Flutter 当前平台的原生转场实现。Android 使用
            // PredictiveBackPageTransitionsBuilder，并在合适时动画化页面快照，
            // 避免每一帧重新栅格化整棵设置页组件树。
            defaultTransition: Transition.native,
            transitionDuration: SliveMotion.route,
            popGesture: Platform.isIOS || Platform.isMacOS,
            //国际化
            locale: const Locale("zh", "CN"),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale("zh", "CN")],
            logWriterCallback: (text, {bool? isError}) {
              Log.addDebugLog(
                  text, (isError ?? false) ? Colors.red : Colors.grey);
              Log.writeLog(text, (isError ?? false) ? Level.error : Level.info);
            },
            //debugShowCheckedModeBanner: false,
            navigatorObservers: [
              FlutterSmartDialog.observer,
              if (Platform.isAndroid) AppAnalyticsObserver.observer
            ],
            builder: FlutterSmartDialog.init(
              loadingBuilder: ((msg) => const AppLoaddingWidget()),
              // 尊重系统字体设置，同时限制极端缩放，避免移动端控件跳位。
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                final appContent = MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(
                      mediaQuery.textScaler.scale(1).clamp(0.9, 1.5).toDouble(),
                    ),
                  ),
                  child: Stack(
                    children: [
                      //侧键返回
                      _AppInteractionShell(child: child!),

                      //查看DEBUG日志按钮
                      //只在Debug、Profile模式显示
                      Visibility(
                        visible: !kReleaseMode,
                        child: Positioned(
                          right: 12,
                          bottom: 100 + context.mediaQueryViewPadding.bottom,
                          child: Opacity(
                            opacity: 0.4,
                            child: ElevatedButton(
                              child: const Text("DEBUG LOG"),
                              onPressed: () {
                                Get.bottomSheet(
                                  const DebugLogPage(),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (Platform.isLinux && Get.isRegistered<WindowService>()) {
                  return SliveLinuxWindowFrame(child: appContent);
                }
                return appContent;
              },
            ),
          );
        });
      },
    );
  }
}

class _AppInteractionShell extends StatefulWidget {
  const _AppInteractionShell({required this.child});

  final Widget child;

  @override
  State<_AppInteractionShell> createState() => _AppInteractionShellState();
}

class _AppInteractionShellState extends State<_AppInteractionShell> {
  final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: 'SliveGlobalKeyboard',
  );

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleBackAction() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
        EventBus.instance.emit(EventBus.kEscapePressed, 0);
        return;
      }
    }
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
    }
  }

  Future<void> _handleKeyEvent(KeyEvent event) async {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      await _handleBackAction();
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.space) {
      EventBus.instance.emit(EventBus.kSpacePressed, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      excludeFromSemantics: true,
      gestures: <Type, GestureRecognizerFactory>{
        FourthButtonTapGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            FourthButtonTapGestureRecognizer>(
          FourthButtonTapGestureRecognizer.new,
          (instance) {
            instance.onTapDown = (_) => unawaited(_handleBackAction());
          },
        ),
      },
      child: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: (event) => unawaited(_handleKeyEvent(event)),
        child: widget.child,
      ),
    );
  }
}
