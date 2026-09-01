import 'dart:async';
import 'dart:io';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/app/utils/sandbox.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/live_room/chat/bounded_deferred_buffer.dart';
import 'package:simple_live_app/modules/live_room/chat/danmaku_shield_matcher.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_event.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_app/modules/settings/danmu_settings_page.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/history_service.dart';
import 'package:simple_live_app/src/rust/api/danmaku_mask.dart';
import 'package:simple_live_app/widgets/desktop_refresh_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LiveRoomController extends PlayerController with WidgetsBindingObserver {
  final Site pSite;
  final String pRoomId;
  late LiveDanmaku liveDanmaku;
  late DanmakuMask rustDanmakuMask;

  List<LiveMessage> danmakuBuffer = [];
  Timer? _routeStartTimer;
  Timer? danmakuTimer;
  Timer? _superChatTimer;
  bool _isProcessingBuffer = false;

  LiveRoomController({
    required this.pSite,
    required this.pRoomId,
  }) {
    rxSite = pSite.obs;
    rxRoomId = pRoomId.obs;
    liveDanmaku = site.liveSite.getDanmaku();
    // 抖音应该默认是竖屏的
    if (site.id == "douyin") {
      isVertical.value = true;
    }
  }

  late Rx<Site> rxSite;
  Site get site => rxSite.value;
  late Rx<String> rxRoomId;
  String get roomId => rxRoomId.value;

  Rx<LiveRoomDetail?> detail = Rx<LiveRoomDetail?>(null);
  var online = 0.obs;
  var fansCount = 0.obs;
  final RxnInt vipCount = RxnInt();
  var followed = false.obs;
  var liveStatus = false.obs;
  RxList<LiveSuperChatMessage> superChats = RxList<LiveSuperChatMessage>();

  /// 滚动控制
  final ScrollController scrollController = ScrollController();

  /// 聊天信息
  RxList<LiveMessage> messages = RxList<LiveMessage>();
  final BoundedDeferredBuffer<LiveMessage> _chatMessageBuffer =
      BoundedDeferredBuffer<LiveMessage>(maxVisible: 400, maxDeferred: 100);
  final DanmakuShieldMatcher _shieldMatcher = DanmakuShieldMatcher();
  int _shieldedMessageCount = 0;

  /// 虎牙礼物特效只保留一个活动项和少量待显示项，防止礼物高峰堆积动画。
  final Rxn<HuyaGiftDanmakuEvent> activeHuyaGiftEffect =
      Rxn<HuyaGiftDanmakuEvent>();
  final HuyaGiftDanmakuQueue _huyaGiftQueue =
      HuyaGiftDanmakuQueue(maxPending: 3);
  Timer? _huyaGiftEffectTimer;
  Worker? _huyaGiftSettingWorker;
  Worker? _huyaGiftLiveStatusWorker;
  int _huyaGiftEffectSequence = 0;

  /// 清晰度数据
  RxList<LivePlayQuality> qualites = RxList<LivePlayQuality>();

  /// 当前清晰度
  var currentQuality = -1;
  var currentQualityInfo = "".obs;

  /// 线路数据
  RxList<String> playUrls = RxList<String>();

  Map<String, String>? playHeaders;

  /// 当前线路
  var currentLineIndex = -1;
  var currentLineInfo = "".obs;

  /// 退出倒计时
  var countdown = 60.obs;

  Timer? autoExitTimer;
  Timer? _autoExitGraceTimer;

  /// 设置的自动关闭时间（分钟）
  var autoExitMinutes = 60.obs;

  ///是否延迟自动关闭
  var delayAutoExit = false.obs;

  /// 是否启用自动关闭
  var autoExitEnable = false.obs;

  /// 是否禁用自动滚动聊天栏
  /// - 当用户向上滚动聊天栏时，不再自动滚动
  var disableAutoScroll = false.obs;

  /// 是否处于后台
  var isBackground = false;

  /// 直播间加载失败
  var loadError = false.obs;
  Error? error;

  @override
  void onInit() {
    WidgetsBinding.instance.addObserver(this);
    initAutoExit();
    showDanmakuState.value = AppSettingsController.instance.danmuEnable.value;
    _huyaGiftSettingWorker = ever<bool>(
      AppSettingsController.instance.huyaGiftDanmakuEnable,
      (enabled) {
        if (!enabled) _clearHuyaGiftEffects();
      },
    );
    _huyaGiftLiveStatusWorker = ever<bool>(liveStatus, (isLive) {
      if (!isLive) _clearHuyaGiftEffects();
    });
    followed.value =
        FollowService.instance.getFollowExist("${site.id}_$roomId");
    // 等顶层路由转场完成后再启动关注数据和直播间网络请求。之前只延后一帧，
    // 房间详情、WebSocket 与响应式更新仍会撞进 180ms 的进入动画窗口。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      _routeStartTimer = Timer(SliveMotion.route, () {
        _routeStartTimer = null;
        if (isClosed) return;
        if (FollowService.instance.followList.isEmpty) {
          FollowService.instance.loadData();
        }
        loadData();
      });
    });

    scrollController.addListener(scrollListener);

    _initDanmakuMask();
    super.onInit();
  }

  void _initDanmakuMask() async {
    rustDanmakuMask = DanmakuMask(
      baseWindowMs: AppSettingsController.instance.danmuWindowMs.value * 1000,
      bucketCount: AppSettingsController.instance.danmuWindowMs.value,
      useNormalization:
          AppSettingsController.instance.danmuTextNormalization.value,
      useFrequencyControl:
          AppSettingsController.instance.danmuFrequencyControl.value,
      maxFrequency: AppSettingsController.instance.danmuMaxFrequency.value,
      adaptiveWindow: false,
    );
  }

  void _scheduleDanmakuBufferProcessing() {
    if (isBackground || danmakuTimer?.isActive == true) return;
    danmakuTimer = Timer(const Duration(milliseconds: 500), () {
      danmakuTimer = null;
      _processDanmakuBuffer();
    });
  }

  // 缓存降低跨线程消息开销 估算弹幕延迟在800ms左右
  void _processDanmakuBuffer() async {
    if (_isProcessingBuffer) return;
    if (danmakuBuffer.isEmpty) return;

    _isProcessingBuffer = true;
    try {
      final batch = List<LiveMessage>.from(danmakuBuffer);
      danmakuBuffer.clear();

      final batchMessages = batch.map((e) => e.message).toList();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final allowedResults = await rustDanmakuMask.allowListBatch(
          texts: batchMessages, nowMs: BigInt.from(nowMs));

      final filteredBatch = <LiveMessage>[];
      for (int i = 0; i < batch.length; i++) {
        if (allowedResults[i] == 1) {
          filteredBatch.add(batch[i]);
        }
      }

      if (filteredBatch.isEmpty) return;

      _appendChatMessages(filteredBatch);
      if (!liveStatus.value || isBackground) {
        return;
      }

      addDanmaku(filteredBatch
          .map((msg) => DanmakuContentItem(
                msg.message,
                color: Color.fromARGB(
                  255,
                  msg.color.r,
                  msg.color.g,
                  msg.color.b,
                ),
              ))
          .toList());
    } finally {
      _isProcessingBuffer = false;
      if (danmakuBuffer.isNotEmpty) {
        _scheduleDanmakuBufferProcessing();
      }
    }
  }

  void scrollListener() {
    if (scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      disableAutoScroll.value = true;
    }
  }

  /// 初始化自动关闭倒计时
  void initAutoExit() {
    if (AppSettingsController.instance.autoExitEnable.value) {
      autoExitEnable.value = true;
      autoExitMinutes.value =
          AppSettingsController.instance.autoExitDuration.value;
      setAutoExit();
    } else {
      autoExitMinutes.value =
          AppSettingsController.instance.roomAutoExitDuration.value;
    }
  }

  void setAutoExit() {
    autoExitTimer?.cancel();
    autoExitTimer = null;
    _autoExitGraceTimer?.cancel();
    _autoExitGraceTimer = null;
    if (!autoExitEnable.value) return;

    countdown.value = autoExitMinutes.value * 60;
    autoExitTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      countdown.value -= 1;
      if (countdown.value > 0) return;

      timer.cancel();
      autoExitTimer = null;
      _autoExitGraceTimer = Timer(const Duration(seconds: 10), () async {
        await WakelockPlus.disable();
        exit(0);
      });
      final delay = await Utils.showAlertDialog(
        "定时关闭已到时,是否延迟关闭?",
        title: "延迟关闭",
        confirm: "延迟",
        cancel: "关闭",
        selectable: true,
      );
      if (isClosed) {
        _autoExitGraceTimer?.cancel();
        _autoExitGraceTimer = null;
        return;
      }
      if (delay) {
        _autoExitGraceTimer?.cancel();
        _autoExitGraceTimer = null;
        delayAutoExit.value = true;
        showAutoExitSheet();
        setAutoExit();
      } else {
        delayAutoExit.value = false;
        await WakelockPlus.disable();
        exit(0);
      }
    });
  }
  // 弹窗逻辑

  void refreshRoom() {
    //messages.clear();
    superChats.clear();
    liveDanmaku.stop();

    loadData();
  }

  /// 聊天栏始终滚动到底部
  void chatScrollToBottom() {
    if (scrollController.hasClients) {
      // 如果手动上拉过，就不自动滚动到底部
      if (disableAutoScroll.value) {
        return;
      }
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }

  /// 初始化弹幕接收事件
  void initDanmau() {
    liveDanmaku.onMessage = onWSMessage;
    liveDanmaku.onClose = onWSClose;
    liveDanmaku.onReady = onWSReady;
  }

  /// 接收到WebSocket信息
  void onWSMessage(LiveMessage msg) async {
    if (msg.type == LiveMessageType.chat) {
      final matchedRule = _shieldMatcher.match(
        msg.message,
        AppSettingsController.instance.shieldList,
        onInvalidRegex: (rule) => Log.d("关键词：$rule 正则格式错误"),
      );
      if (matchedRule != null) {
        _shieldedMessageCount++;
        // 高频命中只做采样日志，避免热门房间反复写入完整弹幕内容。
        if (_shieldedMessageCount == 1 || _shieldedMessageCount % 50 == 0) {
          Log.d("弹幕屏蔽命中：$matchedRule，累计 $_shieldedMessageCount 条");
        }
        return;
      }

      //  messages.length>n 预加载部分弹幕后启用去重功能
      if (AppSettingsController.instance.danmakuMaskEnable.value &&
          messages.length > 50) {
        danmakuBuffer.add(msg);
        _scheduleDanmakuBufferProcessing();
      } else {
        _appendChatMessages([msg]);
        if (!liveStatus.value || isBackground) {
          return;
        }

        addDanmaku([
          DanmakuContentItem(
            msg.message,
            color: Color.fromARGB(
              255,
              msg.color.r,
              msg.color.g,
              msg.color.b,
            ),
          ),
        ]);
      }
    } else if (msg.type == LiveMessageType.online) {
      online.value = msg.data;
    } else if (msg.type == LiveMessageType.superChat) {
      superChats.add(msg.data);
      _ensureSuperChatTimer();
    } else if (msg.type == LiveMessageType.gift) {
      _handleGiftMessage(msg);
    } else if (msg.type == LiveMessageType.vipCount) {
      final count = _parseVipCount(msg.data);
      if (count != null) {
        // 贵宾总数是服务端快照，只能覆盖，不能通过进场事件推算。
        vipCount.value = count;
      }
    } else if (msg.type == LiveMessageType.vipEnter) {
      // 进场事件只进入普通聊天流，不参与贵宾人数推算，也不再占用独立
      // 固定区域；其视觉样式由聊天气泡设置统一控制。
      if (msg.message.isNotEmpty) {
        _addEventMessage(msg);
      }
    }
  }

  int? _parseVipCount(dynamic data) {
    dynamic value = data;
    if (data is Map) {
      value = data["count"];
    }
    if (value is num) {
      final count = value.toInt();
      return count >= 0 ? count : null;
    }
    return null;
  }

  void _addEventMessage(LiveMessage msg) {
    _appendChatMessages([msg]);
  }

  void _appendChatMessages(Iterable<LiveMessage> newMessages) {
    final added = _chatMessageBuffer.append(
      messages,
      newMessages,
      preserveVisible: disableAutoScroll.value,
    );
    if (added == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => chatScrollToBottom());
  }

  void resumeChatAutoScroll() {
    disableAutoScroll.value = false;
    _chatMessageBuffer.resume(messages);
    WidgetsBinding.instance.addPostFrameCallback((_) => chatScrollToBottom());
  }

  void _handleGiftMessage(LiveMessage message) {
    final action = resolveGiftMessageUiAction(
      isHuya: site.id == Constant.kHuya,
      giftDanmakuEnabled:
          AppSettingsController.instance.huyaGiftDanmakuEnable.value,
      isLive: liveStatus.value,
      isBackground: isBackground,
    );

    switch (action) {
      case GiftMessageUiAction.appendText:
        // 非虎牙平台仍保留原有的文字礼物事件。
        _addEventMessage(message);
        return;
      case GiftMessageUiAction.discard:
        return;
      case GiftMessageUiAction.showHuyaEffect:
        final event = HuyaGiftDanmakuEvent.fromMessage(
          message,
          sequence: ++_huyaGiftEffectSequence,
        );
        final shouldPresentImmediately = _huyaGiftQueue.enqueue(event);
        if (shouldPresentImmediately) {
          _presentActiveHuyaGift();
        }
        return;
    }
  }

  void _presentActiveHuyaGift() {
    _huyaGiftEffectTimer?.cancel();
    activeHuyaGiftEffect.value = _huyaGiftQueue.active;
    final event = _huyaGiftQueue.active;
    if (event == null) return;

    _huyaGiftEffectTimer = Timer(resolveHuyaGiftDisplayDuration(event), () {
      _huyaGiftQueue.advance();
      _presentActiveHuyaGift();
    });
  }

  void _clearHuyaGiftEffects() {
    _huyaGiftEffectTimer?.cancel();
    _huyaGiftEffectTimer = null;
    _huyaGiftQueue.clear();
    activeHuyaGiftEffect.value = null;
  }

  /// 添加一条系统消息
  void addSysMsg(String msg) {
    messages.add(
      LiveMessage(
        type: LiveMessageType.chat,
        userName: "LiveSysMessage",
        message: msg,
        color: LiveMessageColor.white,
      ),
    );
  }

  /// 接收到WebSocket关闭信息
  void onWSClose(String msg) {
    addSysMsg(msg);
  }

  /// WebSocket准备就绪
  void onWSReady() {
    addSysMsg("弹幕服务器连接正常");
  }

  /// 加载直播间信息
  void loadData() async {
    final showLoadingDialog = detail.value != null;
    try {
      if (showLoadingDialog) SmartDialog.showLoading(msg: "");
      loadError.value = false;
      // 虎牙贵宾数必须等待 WebSocket 快照，加载/刷新期间保持未知态。
      vipCount.value = site.id == Constant.kHuya ? null : 0;
      addSysMsg("正在读取直播间信息");
      detail.value = await site.liveSite.getRoomDetail(roomId: roomId);

      if (site.id == Constant.kDouyin) {
        // 1.6.0之前收藏的WebRid
        // 1.6.0收藏的RoomID
        // 1.6.0之后改回WebRid
        if (detail.value!.roomId != roomId) {
          var oldId = roomId;
          rxRoomId.value = detail.value!.roomId;
          if (followed.value) {
            // 更新关注列表
            DBService.instance.deleteFollow("${site.id}_$oldId");
            DBService.instance.addFollow(
              FollowUser(
                id: "${site.id}_$roomId",
                roomId: roomId,
                siteId: site.id,
                userName: detail.value!.userName,
                face: detail.value!.userAvatar,
                addTime: DateTime.now(),
              ),
            );
          } else {
            followed.value =
                DBService.instance.getFollowExist("${site.id}_$roomId");
          }
        }
      }

      getSuperChatMessage();

      addHistory();
      // 确认房间关注状态
      followed.value =
          FollowService.instance.getFollowExist("${site.id}_$roomId");
      online.value = detail.value!.online;
      fansCount.value = detail.value!.fansCount ?? 0;
      if (site.id != Constant.kHuya) {
        vipCount.value = detail.value!.vipCount ?? 0;
      }
      liveStatus.value = detail.value!.status || detail.value!.isRecord;
      if (liveStatus.value) {
        getPlayQualites();
        addSysMsg("开始连接弹幕服务器");
        initDanmau();
        liveDanmaku.start(detail.value?.danmakuData);
      }
      if (detail.value!.isRecord) {
        addSysMsg("当前主播未开播，正在轮播录像");
      }
    } catch (e) {
      Log.logPrint(e);
      //SmartDialog.showToast(e.toString());
      loadError.value = true;
      if (e is Error) {
        error = e;
      }
    } finally {
      if (showLoadingDialog) {
        SmartDialog.dismiss(status: SmartStatus.loading);
      }
    }
  }

  /// 初始化播放器
  void getPlayQualites() async {
    currentQuality = -1;

    try {
      var playQualites =
          await site.liveSite.getPlayQualites(detail: detail.value!);

      if (playQualites.isEmpty) {
        SmartDialog.showToast("无法读取播放清晰度");
        return;
      }
      qualites.assignAll(playQualites);
      var qualityLevel = await getQualityLevel();
      if (qualityLevel == 2) {
        //最高
        currentQuality = 0;
      } else if (qualityLevel == 0) {
        //最低
        currentQuality = playQualites.length - 1;
      } else {
        //中间值
        int middle = (playQualites.length / 2).floor();
        currentQuality = middle;
      }
      await getPlayUrl();
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("无法读取播放清晰度");
    }
  }

  Future<int> getQualityLevel() async {
    var qualityLevel = AppSettingsController.instance.qualityLevel.value;
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.first == ConnectivityResult.mobile) {
        qualityLevel =
            AppSettingsController.instance.qualityLevelCellular.value;
      }
    } catch (e) {
      Log.logPrint(e);
    }
    return qualityLevel;
  }

  Future<void> getPlayUrl() async {
    currentQualityInfo.value = qualites[currentQuality].quality;
    currentLineInfo.value = "";
    currentLineIndex = -1;
    var playUrl = await site.liveSite
        .getPlayUrls(detail: detail.value!, quality: qualites[currentQuality]);
    if (playUrl.urls.isEmpty) {
      SmartDialog.showToast("无法读取播放地址");
      return;
    }
    playUrls.assignAll(playUrl.urls); // 深拷贝
    playHeaders = playUrl.headers;
    currentLineIndex = 0;
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    //重置错误次数
    mediaErrorRetryCount = 0;
    initPlaylist();
  }

  void changePlayLine(int index) {
    currentLineIndex = index;
    //重置错误次数
    mediaErrorRetryCount = 0;
    setPlayer();
  }

  void initPlaylist() async {
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    errorMsg.value = "";

    final mediaList = playUrls.map((url) {
      var finalUrl = url;
      if (AppSettingsController.instance.playerForceHttps.value) {
        finalUrl = finalUrl.replaceAll("http://", "https://");
      }
      return Media(finalUrl, httpHeaders: playHeaders);
    }).toList();

    // 路由动画期间不创建原生播放器；网络结果若提前返回则等待运行时就绪。
    await ensurePlayerRuntimeReady();
    if (isClosed) return;
    await initializePlayer();

    await player.open(Playlist(mediaList));
  }

  void setPlayer() async {
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    errorMsg.value = "";

    await player.jump(currentLineIndex);
  }

  @override
  void mediaEnd() async {
    super.mediaEnd();
    if (mediaErrorRetryCount < 2) {
      Log.d("播放结束，尝试第${mediaErrorRetryCount + 1}次刷新");
      if (mediaErrorRetryCount == 1) {
        //延迟一秒再刷新
        await Future.delayed(const Duration(seconds: 1));
      }
      mediaErrorRetryCount += 1;
      //刷新一次
      setPlayer();
      return;
    }

    Log.d("播放结束");
    // 遍历线路，如果全部链接都断开就是直播结束了
    if (playUrls.length - 1 == currentLineIndex) {
      liveStatus.value = false;
    } else {
      changePlayLine(currentLineIndex + 1);

      //setPlayer();
    }
  }

  int mediaErrorRetryCount = 0;
  @override
  void mediaError(String error) async {
    super.mediaEnd();
    if (mediaErrorRetryCount < 2) {
      Log.d("播放失败，尝试第${mediaErrorRetryCount + 1}次刷新");
      if (mediaErrorRetryCount == 1) {
        //延迟一秒再刷新
        await Future.delayed(const Duration(seconds: 1));
      }
      mediaErrorRetryCount += 1;
      //刷新一次
      setPlayer();
      return;
    }

    if (playUrls.length - 1 == currentLineIndex) {
      errorMsg.value = "播放失败";
      SmartDialog.showToast("播放失败:$error");
    } else {
      //currentLineIndex += 1;
      //setPlayer();
      changePlayLine(currentLineIndex + 1);
    }
  }

  /// 读取SC
  void getSuperChatMessage() async {
    try {
      var sc =
          await site.liveSite.getSuperChatMessage(roomId: detail.value!.roomId);
      superChats.addAll(sc);
      _ensureSuperChatTimer();
    } catch (e) {
      Log.logPrint(e);
      addSysMsg("SC读取失败");
    }
  }

  /// 移除掉已到期的SC
  void removeSuperChats() {
    var now = DateTime.now().millisecondsSinceEpoch;
    superChats.removeWhere((x) => x.endTime.millisecondsSinceEpoch <= now);
    if (superChats.isEmpty) {
      _superChatTimer?.cancel();
      _superChatTimer = null;
    }
  }

  void _ensureSuperChatTimer() {
    if (isBackground ||
        superChats.isEmpty ||
        _superChatTimer?.isActive == true) {
      return;
    }
    _superChatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      superChats.refresh();
      removeSuperChats();
    });
  }

  /// 添加历史记录
  void addHistory() {
    if (detail.value == null) {
      return;
    }
    var id = "${site.id}_$roomId";
    History history = History(
      id: id,
      roomId: roomId,
      siteId: site.id,
      userName: detail.value?.userName ?? "",
      face: detail.value?.userAvatar ?? "",
      updateTime: DateTime.now(),
    );
    HistoryService.instance.start(history);
  }

  /// 关注用户
  Future<void> followUser() async {
    if (detail.value == null) {
      return;
    }
    var id = "${site.id}_$roomId";
    var historyDuration =
        HistoryService.instance.getHistoryDuration(followUserId: id);
    await FollowService.instance.addFollow(
      FollowUser(
        id: id,
        roomId: roomId,
        siteId: site.id,
        userName: detail.value?.userName ?? "",
        face: detail.value?.userAvatar ?? "",
        addTime: DateTime.now(),
        watchDuration: historyDuration,
      )
        ..liveStatus.value = liveStatus.value ? 2 : 1
        ..cover.value = detail.value?.cover ?? "",
    );
    followed.value = true;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
  }

  /// 取消关注用户
  void removeFollowUser() async {
    if (detail.value == null) {
      return;
    }
    if (!await Utils.showAlertDialog("确定要取消关注该用户吗？", title: "取消关注")) {
      return;
    }

    var id = "${site.id}_$roomId";
    await FollowService.instance.removeFollowUser(id);
    followed.value = false;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
  }

  void share() {
    if (detail.value == null) {
      return;
    }
    SharePlus.instance.share(ShareParams(text: detail.value!.url));
  }

  void copyUrl() {
    if (detail.value == null) {
      return;
    }
    Utils.copyToClipboard(detail.value!.url);
    SmartDialog.showToast("已复制直播间链接");
  }

  Future<void> visitWebLive() async {
    Uri uri = Uri.parse(detail.value!.url);
    if (await canLaunchUrl(uri) || runningInSandbox()) {
      await launchUrl(uri);
    } else {
      throw '无法打开网页 $uri';
    }
  }

  /// 底部打开播放器设置
  void showDanmuSettingsSheet() {
    Utils.showBottomSheet(
      title: "弹幕设置",
      child: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          DanmuSettingsView(
            danmakuController: danmakuController,
            onTapDanmuShield: () {
              Get.back();
              showDanmuShield();
            },
          ),
        ],
      ),
    );
  }

  void showVolumeSlider(BuildContext targetContext) {
    SmartDialog.showAttach(
      targetContext: targetContext,
      alignment: Alignment.topCenter,
      displayTime: const Duration(seconds: 3),
      maskColor: const Color(0x00000000),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: AppStyle.radius12,
            color: Theme.of(context).cardColor,
          ),
          padding: AppStyle.edgeInsetsA4,
          child: Obx(
            () => SizedBox(
              width: 200,
              child: Slider(
                min: 0,
                max: 100,
                value: AppSettingsController.instance.playerVolume.value,
                onChanged: (newValue) {
                  player.setVolume(newValue);
                  AppSettingsController.instance.setPlayerVolume(newValue);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void showQualitySheet() {
    Utils.showBottomSheet(
      title: "切换清晰度",
      child: RadioGroup(
        groupValue: currentQuality,
        onChanged: (e) async {
          Get.back();
          currentQuality = e ?? 0;
          await getPlayUrl();
        },
        child: ListView.builder(
          itemCount: qualites.length,
          itemBuilder: (_, i) {
            var item = qualites[i];
            return RadioListTile(
              value: i,
              title: Text(item.quality),
            );
          },
        ),
      ),
    );
  }

  void showPlayUrlsSheet() {
    Utils.showBottomSheet(
      title: "切换线路",
      child: RadioGroup(
        groupValue: currentLineIndex,
        onChanged: (e) {
          Get.back();
          //currentLineIndex = i;
          //setPlayer();
          changePlayLine(e ?? 0);
        },
        child: ListView.builder(
          itemCount: playUrls.length,
          itemBuilder: (_, i) {
            return RadioListTile(
              value: i,
              title: Text("线路${i + 1}"),
              secondary: Text(
                playUrls[i].contains(".flv") ? "FLV" : "HLS",
              ),
            );
          },
        ),
      ),
    );
  }

  void showPlayerSettingsSheet() {
    Utils.showBottomSheet(
      title: "画面尺寸",
      child: Obx(
        () => ListView(
          padding: AppStyle.edgeInsetsV12,
          children: [
            RadioGroup(
              groupValue: AppSettingsController.instance.scaleMode.value,
              onChanged: (e) {
                AppSettingsController.instance.setScaleMode(e ?? 0);
                updateScaleMode();
              },
              child: Column(
                children: [
                  RadioListTile(
                    value: 0,
                    title: const Text("适应"),
                    visualDensity: VisualDensity.compact,
                  ),
                  RadioListTile(
                    value: 1,
                    title: const Text("拉伸"),
                    visualDensity: VisualDensity.compact,
                  ),
                  RadioListTile(
                    value: 2,
                    title: const Text("铺满"),
                    visualDensity: VisualDensity.compact,
                  ),
                  RadioListTile(
                    value: 3,
                    title: const Text("16:9"),
                    visualDensity: VisualDensity.compact,
                  ),
                  RadioListTile(
                    value: 4,
                    title: const Text("4:3"),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showDanmuShield() {
    Utils.showBottomSheet(
      title: "关键词屏蔽",
      child: const _DanmuShieldSheet(),
    );
  }

  void showFollowUserSheet() {
    Utils.showBottomSheet(
      title: "关注列表",
      child: Obx(
        () => Stack(
          children: [
            RefreshIndicator(
              onRefresh: FollowService.instance.loadData,
              child: ListView.builder(
                itemCount: FollowService.instance.liveList.length,
                itemBuilder: (_, i) {
                  var item = FollowService.instance.liveList[i];
                  return Obx(
                    () => FollowUserItem(
                      item: item,
                      playing: rxSite.value.id == item.siteId &&
                          rxRoomId.value == item.roomId,
                      onTap: () {
                        Get.back();
                        resetRoom(
                          Sites.allSites[item.siteId]!,
                          item.roomId,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
              Positioned(
                right: 12,
                bottom: 12,
                child: Obx(
                  () => DesktopRefreshButton(
                    refreshing: FollowService.instance.updating.value,
                    onPressed: FollowService.instance.loadData,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void showAutoExitSheet() {
    if (AppSettingsController.instance.autoExitEnable.value &&
        !delayAutoExit.value) {
      SmartDialog.showToast("已设置了全局定时关闭");
      return;
    }
    Utils.showBottomSheet(
      title: "定时关闭",
      child: ListView(
        children: [
          Obx(
            () => SwitchListTile(
              title: Text(
                "启用定时关闭",
                style: Get.textTheme.titleMedium,
              ),
              value: autoExitEnable.value,
              onChanged: (e) {
                autoExitEnable.value = e;

                setAutoExit();
                //controller.setAutoExitEnable(e);
              },
            ),
          ),
          Obx(
            () => ListTile(
              enabled: autoExitEnable.value,
              title: Text(
                "自动关闭时间：${autoExitMinutes.value ~/ 60}小时${autoExitMinutes.value % 60}分钟",
                style: Get.textTheme.titleMedium,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                var value = await showTimePicker(
                  context: Get.context!,
                  initialTime: TimeOfDay(
                    hour: autoExitMinutes.value ~/ 60,
                    minute: autoExitMinutes.value % 60,
                  ),
                  initialEntryMode: TimePickerEntryMode.inputOnly,
                  builder: (_, child) {
                    return MediaQuery(
                      data: Get.mediaQuery.copyWith(
                        alwaysUse24HourFormat: true,
                      ),
                      child: child!,
                    );
                  },
                );
                if (value == null || (value.hour == 0 && value.minute == 0)) {
                  return;
                }
                var duration =
                    Duration(hours: value.hour, minutes: value.minute);
                autoExitMinutes.value = duration.inMinutes;
                AppSettingsController.instance
                    .setRoomAutoExitDuration(autoExitMinutes.value);
                //setAutoExitDuration(duration.inMinutes);
                setAutoExit();
              },
            ),
          ),
        ],
      ),
    );
  }

  void openNaviteAPP() async {
    var naviteUrl = "";
    var webUrl = "";
    if (site.id == Constant.kBiliBili) {
      naviteUrl = "bilibili://live/${detail.value?.roomId}";
      webUrl = "https://live.bilibili.com/${detail.value?.roomId}";
    } else if (site.id == Constant.kDouyin) {
      var args = detail.value?.danmakuData as DouyinDanmakuArgs;
      naviteUrl = "snssdk1128://webcast_room?room_id=${args.roomId}";
      webUrl = "https://live.douyin.com/${args.webRid}";
    } else if (site.id == Constant.kHuya) {
      var args = detail.value?.danmakuData as HuyaDanmakuArgs;
      naviteUrl =
          "yykiwi://homepage/index.html?banneraction=https%3A%2F%2Fdiy-front.cdn.huya.com%2Fzt%2Ffrontpage%2Fcc%2Fupdate.html%3Fhyaction%3Dlive%26channelid%3D${args.subSid}%26subid%3D${args.subSid}%26liveuid%3D${args.subSid}%26screentype%3D1%26sourcetype%3D0%26fromapp%3Dhuya_wap%252Fclick%252Fopen_app_guide%26&fromapp=huya_wap/click/open_app_guide";
      webUrl = "https://www.huya.com/${detail.value?.roomId}";
    } else if (site.id == Constant.kDouyu) {
      naviteUrl =
          "douyulink://?type=90001&schemeUrl=douyuapp%3A%2F%2Froom%3FliveType%3D0%26rid%3D${detail.value?.roomId}";
      webUrl = "https://www.douyu.com/${detail.value?.roomId}";
    }
    try {
      await launchUrlString(naviteUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("无法打开APP，将使用浏览器打开");
      await launchUrlString(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  void resetRoom(Site site, String roomId) async {
    if (this.site == site && this.roomId == roomId) {
      return;
    }

    _clearHuyaGiftEffects();
    rxSite.value = site;
    rxRoomId.value = roomId;
    // 房间身份切换后立即清空旧房间快照，避免播放器停止期间短暂串房。
    vipCount.value = site.id == Constant.kHuya ? null : 0;

    // 清除全部消息
    liveDanmaku.stop();
    messages.clear();
    _chatMessageBuffer.clear();
    superChats.clear();
    _superChatTimer?.cancel();
    _superChatTimer = null;
    danmakuController?.clear();

    // 重新设置LiveDanmaku
    liveDanmaku = site.liveSite.getDanmaku();
    rustDanmakuMask.reset();

    // 停止播放
    await player.stop();

    // 刷新信息
    loadData();
    HistoryService.instance.reset("${site.id}_$roomId");
  }

  void copyErrorDetail() {
    Utils.copyToClipboard('''直播平台：${rxSite.value.name}
房间号：${rxRoomId.value}
错误信息：
${error?.toString()}
----------------
${error?.stackTrace}''');
    SmartDialog.showToast("已复制错误信息");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state != AppLifecycleState.resumed) {
      if (isBackground) return;
      // 离开前台时暂停绘制与短周期任务，避免切应用或锁屏后继续耗电。
      isBackground = true;
      danmakuController?.clear();
      danmakuController?.pause();
      danmakuTimer?.cancel();
      danmakuTimer = null;
      _superChatTimer?.cancel();
      _superChatTimer = null;
      _clearHuyaGiftEffects();
      return;
    }

    if (!isBackground) return;
    isBackground = false;
    danmakuController?.resume();
    if (danmakuBuffer.isNotEmpty) {
      _scheduleDanmakuBufferProcessing();
    }
    _ensureSuperChatTimer();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    scrollController.removeListener(scrollListener);
    _routeStartTimer?.cancel();
    _routeStartTimer = null;
    autoExitTimer?.cancel();
    _autoExitGraceTimer?.cancel();
    danmakuTimer?.cancel();
    _superChatTimer?.cancel();
    _huyaGiftEffectTimer?.cancel();
    _huyaGiftSettingWorker?.dispose();
    _huyaGiftLiveStatusWorker?.dispose();

    // 返回手势/动画的关键帧里只停止会继续触发 UI 的监听与计时器。
    // WebSocket 关闭、历史持久化、Rust 资源释放都延后到页面已经稳定后，
    // 避免直播间返回叠加同步清理造成 16/24/33ms 长帧。
    final closingDanmaku = liveDanmaku;
    final danmakuMask = rustDanmakuMask;
    final expectedHistoryId = '${site.id}_$roomId';
    danmakuController = null;
    super.onClose();

    Future<void>.delayed(SliveMotion.liveRoomCleanup, () {
      SchedulerBinding.instance.scheduleTask<void>(
        () async {
          _huyaGiftQueue.clear();
          _chatMessageBuffer.clear();
          HistoryService.instance.stop(expectedRoomId: expectedHistoryId);
          await closingDanmaku.stop();
          danmakuMask.dispose();
        },
        Priority.idle,
        debugLabel: 'slive-live-room-cleanup',
      );
    });
  }
}

class _DanmuShieldSheet extends StatefulWidget {
  const _DanmuShieldSheet();

  @override
  State<_DanmuShieldSheet> createState() => _DanmuShieldSheetState();
}

class _DanmuShieldSheetState extends State<_DanmuShieldSheet> {
  final TextEditingController _keywordController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _addKeyword() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      SmartDialog.showToast("请输入关键词");
      return;
    }
    if (_isAdding) return;

    setState(() => _isAdding = true);
    try {
      await AppSettingsController.instance.addShieldList(keyword);
      if (mounted) _keywordController.clear();
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: AppStyle.edgeInsetsA12,
      children: [
        TextField(
          controller: _keywordController,
          decoration: InputDecoration(
            contentPadding: AppStyle.edgeInsetsH12,
            border: const OutlineInputBorder(),
            hintText: "请输入关键词",
            suffixIcon: TextButton.icon(
              onPressed: _isAdding ? null : _addKeyword,
              icon: const Icon(Icons.add),
              label: const Text("添加"),
            ),
          ),
          onSubmitted: (_) => _addKeyword(),
        ),
        AppStyle.vGap12,
        Obx(
          () => Text(
            "已添加${AppSettingsController.instance.shieldList.length}个关键词（点击移除）",
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        AppStyle.vGap12,
        Obx(
          () => Wrap(
            runSpacing: 12,
            spacing: 12,
            children: AppSettingsController.instance.shieldList
                .map(
                  (item) => InkWell(
                    borderRadius: AppStyle.radius24,
                    onTap: () =>
                        AppSettingsController.instance.removeShieldList(item),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: AppStyle.radius24,
                      ),
                      padding: AppStyle.edgeInsetsH12.copyWith(
                        top: 4,
                        bottom: 4,
                      ),
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}
