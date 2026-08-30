import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:udp/udp.dart';

class SyncService extends GetxService {
  static SyncService get instance => Get.find<SyncService>();

  static const int udpPort = 23235;
  static const int httpPort = 23234;
  static const String pairingCodeHeader = 'x-simple-live-pairing-code';

  static const int _maxRequestBodyBytes = 2 * 1024 * 1024;
  static const int _maxFollowItems = 10000;
  static const int _maxTagItems = 1000;
  static const int _maxHistoryItems = 20000;
  static const int _maxBlockedWords = 5000;

  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  final NetworkInfo networkInfo = NetworkInfo();
  final RxList<SyncClinet> scanClients = <SyncClinet>[].obs;
  final ipAddress = ''.obs;
  final httpRunning = false.obs;
  final httpErrorMsg = ''.obs;
  final starting = false.obs;
  final pairingCode = ''.obs;

  UDP? udp;
  HttpServer? server;
  StreamSubscription<Datagram?>? _udpSubscription;
  Future<void>? _startFuture;
  int _lifecycleGeneration = 0;

  late final String deviceId;

  String get connectionQrData => Uri(
        scheme: 'simplelive',
        host: 'sync',
        queryParameters: {
          'addresses': ipAddress.value,
          'port': httpPort.toString(),
          'code': pairingCode.value,
        },
      ).toString();

  @override
  void onInit() {
    deviceId = _randomHex(8);
    Log.d('SyncService initialized without opening network ports');
    super.onInit();
  }

  /// 仅在用户主动进入局域网同步页面后启动服务。
  Future<void> start() async {
    final requestedGeneration = _lifecycleGeneration;

    while (requestedGeneration == _lifecycleGeneration) {
      if (httpRunning.value && udp != null) return;

      final pendingStart = _startFuture;
      if (pendingStart != null) {
        await pendingStart;
        continue;
      }

      late final Future<void> startFuture;
      startFuture = _start(requestedGeneration).whenComplete(() {
        if (identical(_startFuture, startFuture)) {
          _startFuture = null;
        }
      });
      _startFuture = startFuture;
      await startFuture;
    }
  }

  Future<void> _start(int generation) async {
    starting.value = true;
    httpErrorMsg.value = '';
    await _closeTransport();
    if (generation != _lifecycleGeneration) return;

    pairingCode.value = _generatePairingCode();

    try {
      await _listenUDP();
      if (generation != _lifecycleGeneration) {
        await _closeTransport();
        return;
      }

      await _initServer();
      if (generation != _lifecycleGeneration) {
        await _closeTransport();
      }
    } catch (error, stackTrace) {
      await _closeTransport();
      if (generation != _lifecycleGeneration) return;

      httpErrorMsg.value = error.toString();
      pairingCode.value = '';
      Log.e('启动局域网同步服务失败：$error', stackTrace);
      rethrow;
    } finally {
      if (generation == _lifecycleGeneration) {
        starting.value = false;
      }
    }
  }

  Future<void> stop() async {
    _lifecycleGeneration++;
    pairingCode.value = '';
    httpErrorMsg.value = '';
    starting.value = false;
    await _closeTransport();
  }

  Future<void> _closeTransport() async {
    await _udpSubscription?.cancel();
    _udpSubscription = null;

    udp?.close();
    udp = null;

    final activeServer = server;
    server = null;
    await activeServer?.close(force: true);

    httpRunning.value = false;
    ipAddress.value = '';
    scanClients.clear();
  }

  Future<void> _listenUDP() async {
    final socket = await UDP.bind(Endpoint.any(port: const Port(udpPort)));
    udp = socket;
    _udpSubscription = socket.asStream().listen(
      _listenUdp,
      onError: (Object error, StackTrace stackTrace) {
        Log.e('局域网同步 UDP 监听失败：$error', stackTrace);
      },
    );
  }

  void _listenUdp(Datagram? datagram) {
    if (datagram == null) return;

    try {
      final data = json.decode(utf8.decode(datagram.data));
      if (data is! Map) return;
      if (data['id']?.toString() == deviceId) return;

      if (data['type']?.toString() == 'hello') {
        if (httpRunning.value) {
          unawaited(sendInfo());
        }
        return;
      }

      final address = datagram.address.address;
      final index = scanClients.indexWhere(
        (element) => element.address == address,
      );
      if (index != -1) return;

      scanClients.add(
        SyncClinet(
          id: data['id']?.toString() ?? '',
          name: data['name']?.toString() ?? 'SimpleLive',
          address: address,
          port: httpPort,
          type: data['type']?.toString() ?? 'unknown',
        ),
      );
    } catch (error, stackTrace) {
      Log.e('忽略无效的局域网同步广播：$error', stackTrace, false);
    }
  }

  Future<void> sendHello() async {
    final socket = udp;
    if (socket == null) return;

    await socket.send(
      json.encode({
        'id': deviceId,
        'type': 'hello',
      }).codeUnits,
      Endpoint.broadcast(port: const Port(udpPort)),
    );
  }

  Future<void> sendInfo() async {
    final socket = udp;
    if (socket == null) return;

    final data = {
      'id': deviceId,
      'type': Platform.operatingSystem,
      'name': await getDeviceName(),
    };

    await socket.send(
      json.encode(data).codeUnits,
      Endpoint.broadcast(port: const Port(udpPort)),
    );
  }

  Future<String> getDeviceName() async {
    var name = 'SimpleLive-${Platform.operatingSystem}';
    if (Platform.isAndroid) {
      name = (await deviceInfo.androidInfo).model;
    } else if (Platform.isIOS) {
      name = (await deviceInfo.iosInfo).name;
    } else if (Platform.isMacOS) {
      name = (await deviceInfo.macOsInfo).computerName;
    } else if (Platform.isLinux) {
      name = (await deviceInfo.linuxInfo).name;
    } else if (Platform.isWindows) {
      name = (await deviceInfo.windowsInfo).userName;
    }
    return name;
  }

  Future<void> refreshClients() async {
    await start();
    scanClients.clear();
    await sendHello();
  }

  /// 读取本地 IP。Wi-Fi 地址不可用时回退到全部非回环 IPv4 地址。
  Future<String> getLocalIP() async {
    String? ip = '';
    try {
      ip = await networkInfo.getWifiIP();
    } catch (error) {
      Log.logPrint(error, false);
    }

    try {
      if (ip == null || ip.isEmpty) {
        final interfaces = await NetworkInterface.list();
        final ipList = <String>[];
        for (final interface in interfaces) {
          for (final address in interface.addresses) {
            if (address.type == InternetAddressType.IPv4 &&
                !address.isMulticast &&
                !address.isLoopback) {
              ipList.add(address.address);
            }
          }
        }
        ip = ipList.toSet().join(';');
      }
    } catch (error) {
      Log.logPrint(error, false);
    }
    return ip ?? '';
  }

  Future<void> _initServer() async {
    final router = Router()
      ..get('/', _helloRequest)
      ..get('/info', _infoRequest)
      ..post('/sync/follow', _syncFollowUserRequest)
      ..post('/sync/tag', _syncFollowUserTagRequest)
      ..post('/sync/history', _syncHistoryRequest)
      ..post('/sync/blocked_word', _syncBlockedWordRequest);

    final handler = const shelf.Pipeline()
        .addMiddleware(_pairingMiddleware())
        .addHandler(router.call);

    server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      httpPort,
    );
    server!.autoCompress = true;

    ipAddress.value = await getLocalIP();
    httpRunning.value = true;
    Log.d('局域网同步服务已按需启动：${ipAddress.value}:${server!.port}');
  }

  shelf.Middleware _pairingMiddleware() {
    return (innerHandler) {
      return (request) {
        final submittedCode = request.headers[pairingCodeHeader] ?? '';
        if (!_secureEquals(submittedCode, pairingCode.value)) {
          return Future.value(
            toJsonResponse(
              const {
                'status': false,
                'message': '配对码错误或已失效',
              },
              statusCode: HttpStatus.unauthorized,
            ),
          );
        }
        return innerHandler(request);
      };
    };
  }

  shelf.Response _helloRequest(shelf.Request request) {
    return toJsonResponse({
      'status': true,
      'message': 'SimpleLive local sync is running',
      'version': Utils.packageInfo.version,
    });
  }

  Future<shelf.Response> _infoRequest(shelf.Request request) async {
    return toJsonResponse({
      'id': deviceId,
      'type': Platform.operatingSystem,
      'name': await getDeviceName(),
      'version': Utils.packageInfo.version,
      'address': ipAddress.value,
      'port': httpPort,
    });
  }

  Future<shelf.Response> _syncFollowUserRequest(
    shelf.Request request,
  ) async {
    try {
      final items = await _readJsonList(request, maxItems: _maxFollowItems);
      final users = items
          .map((item) => FollowUser.fromJson(_asJsonMap(item)))
          .toList(growable: false);

      if (_shouldOverlay(request)) {
        await DBService.instance.followBox.clear();
      }
      for (final user in users) {
        await DBService.instance.followBox.put(user.id, user);
      }

      SmartDialog.showToast('已同步关注用户列表');
      EventBus.instance.emit(Constant.kUpdateFollow, 0);
      return _successResponse();
    } catch (error) {
      return _invalidRequestResponse(error);
    }
  }

  Future<shelf.Response> _syncFollowUserTagRequest(
    shelf.Request request,
  ) async {
    try {
      final items = await _readJsonList(request, maxItems: _maxTagItems);
      final tags = items
          .map((item) => FollowUserTag.fromJson(_asJsonMap(item)))
          .toList(growable: false);

      if (_shouldOverlay(request)) {
        await DBService.instance.tagBox.clear();
      }
      for (final tag in tags) {
        await DBService.instance.tagBox.put(tag.id, tag);
      }

      SmartDialog.showToast('已同步标签列表');
      EventBus.instance.emit(Constant.kUpdateFollow, 0);
      return _successResponse();
    } catch (error) {
      return _invalidRequestResponse(error);
    }
  }

  Future<shelf.Response> _syncHistoryRequest(shelf.Request request) async {
    try {
      final items = await _readJsonList(request, maxItems: _maxHistoryItems);
      final histories = items
          .map((item) => History.fromJson(_asJsonMap(item)))
          .toList(growable: false);

      if (_shouldOverlay(request)) {
        await DBService.instance.historyBox.clear();
      }
      for (final history in histories) {
        final old = DBService.instance.historyBox.get(history.id);
        if (old != null && old.updateTime.isAfter(history.updateTime)) {
          continue;
        }
        await DBService.instance.addOrUpdateHistory(history);
      }

      SmartDialog.showToast('已同步观看记录');
      EventBus.instance.emit(Constant.kUpdateHistory, 0);
      return _successResponse();
    } catch (error) {
      return _invalidRequestResponse(error);
    }
  }

  Future<shelf.Response> _syncBlockedWordRequest(
    shelf.Request request,
  ) async {
    try {
      final items = await _readJsonList(request, maxItems: _maxBlockedWords);
      final keywords = items.map((item) {
        if (item is! String) {
          throw const FormatException('屏蔽词必须是字符串');
        }
        final keyword = item.trim();
        if (keyword.isEmpty || keyword.length > 100) {
          throw const FormatException('屏蔽词长度无效');
        }
        return keyword;
      }).toList(growable: false);

      if (_shouldOverlay(request)) {
        await AppSettingsController.instance.clearShieldList();
      }
      for (final keyword in keywords) {
        AppSettingsController.instance.addShieldList(keyword);
      }

      SmartDialog.showToast('已同步弹幕屏蔽词');
      return _successResponse();
    } catch (error) {
      return _invalidRequestResponse(error);
    }
  }

  Future<List<dynamic>> _readJsonList(
    shelf.Request request, {
    required int maxItems,
  }) async {
    final declaredLength = int.tryParse(
      request.headers[HttpHeaders.contentLengthHeader] ?? '',
    );
    if (declaredLength != null && declaredLength > _maxRequestBodyBytes) {
      throw const FormatException('请求体过大');
    }

    final builder = BytesBuilder(copy: false);
    var totalBytes = 0;
    await for (final chunk in request.read()) {
      totalBytes += chunk.length;
      if (totalBytes > _maxRequestBodyBytes) {
        throw const FormatException('请求体过大');
      }
      builder.add(chunk);
    }

    final decoded = json.decode(utf8.decode(builder.takeBytes()));
    if (decoded is! List) {
      throw const FormatException('请求体必须是 JSON 数组');
    }
    if (decoded.length > maxItems) {
      throw const FormatException('同步数据条数超出限制');
    }
    return decoded;
  }

  Map<String, dynamic> _asJsonMap(dynamic value) {
    if (value is! Map) {
      throw const FormatException('同步条目必须是 JSON 对象');
    }
    return Map<String, dynamic>.from(value);
  }

  bool _shouldOverlay(shelf.Request request) {
    return request.requestedUri.queryParameters['overlay'] == '1';
  }

  shelf.Response _successResponse() {
    return toJsonResponse(const {
      'status': true,
      'message': 'success',
    });
  }

  shelf.Response _invalidRequestResponse(Object error) {
    Log.w('拒绝无效的局域网同步请求：$error', false);
    return toJsonResponse(
      const {
        'status': false,
        'message': '同步数据格式无效',
      },
      statusCode: HttpStatus.badRequest,
    );
  }

  shelf.Response toJsonResponse(
    Map<String, dynamic> data, {
    int statusCode = HttpStatus.ok,
  }) {
    return shelf.Response(
      statusCode,
      body: json.encode(data),
      headers: const {
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        HttpHeaders.cacheControlHeader: 'no-store',
      },
      encoding: utf8,
    );
  }

  String _randomHex(int byteCount) {
    final random = Random.secure();
    return List.generate(
      byteCount,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  String _generatePairingCode() {
    final value = Random.secure().nextInt(90000000) + 10000000;
    return value.toString();
  }

  bool _secureEquals(String left, String right) {
    if (left.length != right.length || right.isEmpty) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }

  @override
  void onClose() {
    Log.d('SyncService close');
    unawaited(stop());
    super.onClose();
  }
}

class SyncClinet {
  final String id;
  final String name;
  final String address;
  final int port;
  final String type;
  final String pairingCode;

  const SyncClinet({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.type,
    this.pairingCode = '',
  });

  SyncClinet copyWith({
    String? id,
    String? name,
    String? address,
    int? port,
    String? type,
    String? pairingCode,
  }) {
    return SyncClinet(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      type: type ?? this.type,
      pairingCode: pairingCode ?? this.pairingCode,
    );
  }
}
