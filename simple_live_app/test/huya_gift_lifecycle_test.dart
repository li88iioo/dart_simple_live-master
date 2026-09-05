import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  late _GiftRoomController controller;

  setUp(() {
    Get.testMode = true;
    Get.put<AppSettingsController>(_GiftSettings());
    // 仅隔离原生播放器/存储的启动；礼物接收、计时和清理均运行真实实现。
    controller = _GiftRoomController()
      ..danmakuController = null
      ..liveStatus.value = true;
  });

  tearDown(() {
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    controller.scrollController.dispose();
    Get.reset();
  });

  testWidgets('refreshRoom 在等待 stop 前清空礼物且旧 timer 不再晋升 pending',
      (tester) async {
    final socket = _HoldingGiftDanmaku();
    controller.liveDanmaku = socket;
    controller.onWSMessage(_gift({'eventId': 'active'}));
    controller.onWSMessage(_gift({'eventId': 'pending'}));
    final refresh = controller.refreshRoom();
    try {
      expect(socket.stopCalled, isTrue);
      expect(controller.activeHuyaGiftEffect.value, isNull);
      await tester.pump(const Duration(milliseconds: 2201));
      expect(controller.activeHuyaGiftEffect.value, isNull);
      controller.onWSMessage(_gift({'replacesEventId': 'pending', 'count': 9}));
      expect(controller.activeHuyaGiftEffect.value, isNull);
    } finally {
      socket.stopped.complete();
      await refresh;
    }
    expect(controller.loadCount, 1);
  });

  testWidgets('active 交易更新立即刷新 observable 但不重置初始特效 timer', (tester) async {
    controller.onWSMessage(_gift({
      'eventId': 'effect-1',
      'kind': 'giftEffectNotice',
      'countKnown': false,
      'giftName': '初始特效',
    }));
    controller.onWSMessage(_gift({'eventId': 'next', 'count': 2}));
    await tester.pump(const Duration(milliseconds: 1000));
    controller.onWSMessage(_gift({
      'replacesEventId': 'effect-1',
      'eventId': 'payment-1',
      'count': 7,
      'giftName': '真实交易礼物',
      'payTotal': 100000,
    }));
    expect(controller.activeHuyaGiftEffect.value?.id, 'effect-1');
    expect(controller.activeHuyaGiftEffect.value?.giftName, '真实交易礼物');
    expect(controller.activeHuyaGiftEffect.value?.count, 7);
    expect(controller.activeHuyaGiftEffect.value?.quantityLabel, '×7');
    await tester.pump(const Duration(milliseconds: 2199));
    expect(controller.activeHuyaGiftEffect.value?.id, 'effect-1');
    await tester.pump(const Duration(milliseconds: 2));
    expect(controller.activeHuyaGiftEffect.value?.id, 'next');
    await tester.pump(const Duration(milliseconds: 2201));
    expect(controller.activeHuyaGiftEffect.value, isNull);
    controller.onWSMessage(_gift({'replacesEventId': 'effect-1', 'count': 8}));
    expect(controller.activeHuyaGiftEffect.value, isNull);
  });

  testWidgets('pending 交易原位更新不影响当前展示时间且只展示一次', (tester) async {
    controller.onWSMessage(_gift({'eventId': 'active'}));
    controller.onWSMessage(_gift({'eventId': 'pending', 'countKnown': false}));
    await tester.pump(const Duration(milliseconds: 1000));
    controller.onWSMessage(_gift({'replacesEventId': 'pending', 'count': 5}));
    expect(controller.activeHuyaGiftEffect.value?.id, 'active');
    await tester.pump(const Duration(milliseconds: 1201));
    expect(controller.activeHuyaGiftEffect.value?.id, 'pending');
    expect(controller.activeHuyaGiftEffect.value?.count, 5);
    await tester.pump(const Duration(milliseconds: 2201));
    expect(controller.activeHuyaGiftEffect.value, isNull);
  });

  testWidgets('未知 update 不占展示位，同支付号不同 group 作为独立事件', (tester) async {
    controller.onWSMessage(_gift({'replacesEventId': 'missing', 'count': 9}));
    expect(controller.activeHuyaGiftEffect.value, isNull);
    controller.onWSMessage(
        _gift({'eventId': 'pay-9-group-a', 'messageId': 9, 'count': 2}));
    controller.onWSMessage(
        _gift({'eventId': 'pay-9-group-b', 'messageId': 9, 'count': 3}));
    expect(controller.activeHuyaGiftEffect.value?.id, 'pay-9-group-a');
    await tester.pump(const Duration(milliseconds: 2201));
    expect(controller.activeHuyaGiftEffect.value?.id, 'pay-9-group-b');
    expect(controller.activeHuyaGiftEffect.value?.count, 3);
    await tester.pump(const Duration(milliseconds: 2201));
    expect(controller.activeHuyaGiftEffect.value, isNull);
  });
}

LiveMessage _gift(Map<String, Object?> data) => LiveMessage(
      type: LiveMessageType.gift,
      userName: '测试用户',
      message: '',
      color: LiveMessageColor.white,
      data: {'giftName': '礼物', 'giftId': 1, 'count': 1, ...data},
    );

class _GiftSettings extends AppSettingsController {
  // 本测试只使用内存默认值，显式隔离持久化/平台初始化。
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _GiftRoomController extends LiveRoomController {
  _GiftRoomController()
      : super(pSite: Sites.allSites['huya']!, pRoomId: 'test-room');
  int loadCount = 0;
  @override
  Future<void> loadData() async {
    loadCount++;
  }
}

class _HoldingGiftDanmaku extends LiveDanmaku {
  final stopped = Completer<void>();
  bool stopCalled = false;
  @override
  Future<void> stop() {
    stopCalled = true;
    return stopped.future;
  }
}
