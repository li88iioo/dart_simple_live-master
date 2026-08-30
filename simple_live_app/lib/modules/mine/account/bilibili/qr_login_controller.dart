import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils/async_single_flight.dart';
import 'package:simple_live_app/requests/http_client.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';

enum QRStatus {
  loading,
  unscanned,
  scanned,
  expired,
  failed,
}

class BiliBiliQRLoginController extends GetxController
    with WidgetsBindingObserver {
  final AsyncSingleFlight<void> _pollFlight = AsyncSingleFlight<void>();

  Timer? timer;
  var qrcodeUrl = ''.obs;
  var qrcodeKey = '';
  var _generation = 0;
  var _isForeground = true;

  /// 二维码状态
  /// - [0] 加载中
  /// - [1] 未扫描
  /// - [2] 已扫描，待确认
  /// - [3] 二维码已经失效
  /// - [4] 登录失败
  Rx<QRStatus> qrStatus = QRStatus.loading.obs;

  @override
  void onInit() {
    super.onInit();
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _isForeground = binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    unawaited(loadQRCode());
  }

  Future<void> loadQRCode() async {
    _stopPoll();
    final generation = ++_generation;
    qrcodeKey = '';
    try {
      qrStatus.value = QRStatus.loading;
      final result = await HttpClient.instance.getJson(
        'https://passport.bilibili.com/x/passport-login/web/qrcode/generate',
      );
      if (!_isCurrent(generation) || !_isForeground) return;
      if (result['code'] != 0) {
        throw result['message'];
      }
      qrcodeKey = result['data']['qrcode_key'];
      qrcodeUrl.value = result['data']['url'];
      qrStatus.value = QRStatus.unscanned;
      startPoll();
    } catch (error) {
      if (!_isCurrent(generation) || !_isForeground) return;
      Log.logPrint(error);
      SmartDialog.showToast(error.toString());
      qrStatus.value = QRStatus.failed;
    }
  }

  void startPoll() {
    if (!_isForeground || qrcodeKey.isEmpty || timer?.isActive == true) return;
    if (qrStatus.value != QRStatus.unscanned &&
        qrStatus.value != QRStatus.scanned) {
      return;
    }
    timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(pollQRStatus()),
    );
  }

  Future<void> pollQRStatus() {
    final key = qrcodeKey;
    final generation = _generation;
    if (!_isForeground || key.isEmpty) return Future.value();
    return _pollFlight.run(() => _pollQRStatus(key, generation));
  }

  Future<void> _pollQRStatus(String key, int generation) async {
    try {
      final response = await HttpClient.instance.get(
        'https://passport.bilibili.com/x/passport-login/web/qrcode/poll',
        queryParameters: {'qrcode_key': key},
      );
      if (!_canApplyPollResponse(generation, key)) return;
      if (response.data['code'] != 0) {
        throw response.data['message'];
      }
      final data = response.data['data'];
      final code = data['code'];
      if (code == 0) {
        final cookies = extractLoginCookies(
          response.headers['set-cookie'],
        );
        if (cookies.isEmpty) {
          _stopPoll();
          qrcodeKey = '';
          qrStatus.value = QRStatus.failed;
          const message = '登录成功但未获取到登录凭证，请刷新二维码重试';
          Log.logPrint(message);
          SmartDialog.showToast(message);
          return;
        }

        BiliBiliAccountService.instance.setCookie(cookies.join(';'));
        await BiliBiliAccountService.instance.loadUserInfo();
        if (!_canApplyPollResponse(generation, key)) return;
        _stopPoll();
        qrcodeKey = '';
        Get.back();
      } else if (code == 86038) {
        qrStatus.value = QRStatus.expired;
        qrcodeKey = '';
        _stopPoll();
      } else if (code == 86090) {
        qrStatus.value = QRStatus.scanned;
      }
    } catch (error) {
      if (!_canApplyPollResponse(generation, key)) return;
      Log.logPrint(error);
      SmartDialog.showToast(error.toString());
    }
  }

  bool _canApplyPollResponse(int generation, String key) =>
      _isForeground && _isCurrent(generation) && qrcodeKey == key;

  @visibleForTesting
  static List<String> extractLoginCookies(Iterable<String>? setCookieHeaders) {
    if (setCookieHeaders == null) return const [];
    return setCookieHeaders
        .map((header) => header.split(';').first.trim())
        .where((cookie) => cookie.isNotEmpty && cookie.contains('='))
        .toList(growable: false);
  }

  bool _isCurrent(int generation) => !isClosed && generation == _generation;

  void _stopPoll() {
    timer?.cancel();
    timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      if (qrStatus.value == QRStatus.loading && qrcodeKey.isEmpty) {
        unawaited(loadQRCode());
      } else {
        startPoll();
      }
    } else {
      _stopPoll();
    }
  }

  @override
  void onClose() {
    _generation++;
    _stopPoll();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
