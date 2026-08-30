import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive_ce.dart';
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
import 'package:simple_live_app/services/local_sync_data_merger.dart';
import 'package:simple_live_app/services/local_sync_endpoint.dart';
import 'package:simple_live_app/services/local_sync_pairing_guard.dart';
import 'package:simple_live_app/services/local_sync_protocol.dart';
import 'package:synchronized/synchronized.dart';
import 'package:udp/udp.dart';

class SyncService extends GetxService {
  static SyncService get instance => Get.find<SyncService>();

  static const int udpPort = 23235;
  static const int httpPort = LocalSyncEndpoint.defaultPort;
  static const String pairingCodeHeader = 'x-simple-live-pairing-code';
  static const int protocolVersion = LocalSyncProtocol.currentVersion;
  static const int minimumProtocolVersion =
      LocalSyncProtocol.minimumSupportedVersion;

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
  final Lock _writeLock = Lock();
  final LocalSyncPairingGuard _pairingGuard = LocalSyncPairingGuard();

  UDP? udp;
  HttpServer? server;
  StreamSubscription<Datagram?>? _udpSubscription;
  Future<void>? _startFuture;
  int _lifecycleGeneration = 0;
  bool _acceptingWrites = false;

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
    _pairingGuard.clear();

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
    _acceptingWrites = false;
    pairingCode.value = '';
    _pairingGuard.clear();
    httpErrorMsg.value = '';
    starting.value = false;
    await _closeTransport();
    await _writeLock.synchronized(() async {});
  }

  Future<void> _closeTransport() async {
    _acceptingWrites = false;
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
      if (!LocalSyncEndpoint.isAllowedAddress(address)) return;
      final advertisedPort = data['port'];
      final port = advertisedPort is int &&
              advertisedPort >= 1 &&
              advertisedPort <= 65535
          ? advertisedPort
          : httpPort;

      final index = scanClients.indexWhere(
        (element) => element.address == address,
      );
      if (index != -1) return;

      scanClients.add(
        SyncClinet(
          id: data['id']?.toString() ?? '',
          name: data['name']?.toString() ?? 'SimpleLive',
          address: address,
          port: port,
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
      utf8.encode(
        json.encode({
          'id': deviceId,
          'type': 'hello',
          'protocolVersion': protocolVersion,
        }),
      ),
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
      'port': httpPort,
      'protocolVersion': protocolVersion,
      'minimumProtocolVersion': minimumProtocolVersion,
      'authRequired': true,
    };

    await socket.send(
      utf8.encode(json.encode(data)),
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

  Future<void> refreshClients({bool ensureStarted = true}) async {
    if (ensureStarted) {
      await start();
    }
    if (!httpRunning.value || udp == null) return;

    scanClients.clear();
    await sendHello();
  }

  /// 读取本地 IP。Wi-Fi 地址不可用时回退到全部可连接的局域网 IPv4 地址。
  Future<String> getLocalIP() async {
    String? ip;
    try {
      final wifiIp = await networkInfo.getWifiIP();
      if (_isAdvertisableAddress(wifiIp)) {
        ip = wifiIp;
      }
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
                !address.isLoopback &&
                LocalSyncEndpoint.isAllowedAddress(address.address)) {
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

  bool _isAdvertisableAddress(String? address) {
    return address != null &&
        !address.startsWith('127.') &&
        LocalSyncEndpoint.isAllowedAddress(address);
  }

  Future<void> _initServer() async {
    server = await shelf_io.serve(
      buildHandler(activateWrites: true),
      InternetAddress.anyIPv4,
      httpPort,
    );
    server!.autoCompress = true;

    final localAddresses = await getLocalIP();
    if (localAddresses.isEmpty) {
      throw StateError('未检测到可用的局域网 IPv4 地址');
    }
    ipAddress.value = localAddresses;
    httpRunning.value = true;
    Log.d('局域网同步服务已按需启动：${ipAddress.value}:${server!.port}');
  }

  shelf.Handler buildHandler({
    bool allowMissingClientAddress = false,
    bool activateWrites = false,
  }) {
    if (activateWrites) {
      _acceptingWrites = true;
    }
    final router = Router()
      ..get('/', _helloRequest)
      ..get('/info', _infoRequest)
      ..post('/sync/follow', _syncFollowUserRequest)
      ..post('/sync/follow_bundle', _syncFollowBundleRequest)
      ..post('/sync/tag', _syncFollowUserTagRequest)
      ..post('/sync/history', _syncHistoryRequest)
      ..post('/sync/blocked_word', _syncBlockedWordRequest);

    return const shelf.Pipeline()
        .addMiddleware(
          _localNetworkMiddleware(
            allowMissingClientAddress: allowMissingClientAddress,
          ),
        )
        .addMiddleware(_pairingMiddleware())
        .addHandler(router.call);
  }

  shelf.Middleware _localNetworkMiddleware({
    required bool allowMissingClientAddress,
  }) {
    return (innerHandler) {
      return (request) {
        final clientAddress = _requestClientAddress(request);
        if ((clientAddress == null && !allowMissingClientAddress) ||
            (clientAddress != null &&
                !LocalSyncEndpoint.isAllowedAddress(clientAddress))) {
          return Future.value(
            toJsonResponse(
              const {
                'status': false,
                'message': '仅允许局域网设备访问同步服务',
              },
              statusCode: HttpStatus.forbidden,
            ),
          );
        }
        return innerHandler(request);
      };
    };
  }

  shelf.Middleware _pairingMiddleware() {
    return (innerHandler) {
      return (request) {
        final clientKey = _requestClientAddress(request) ?? 'unknown';
        final blockedFor = _pairingGuard.blockedFor(clientKey);
        if (blockedFor != null) {
          return Future.value(_tooManyPairingAttemptsResponse(blockedFor));
        }

        final submittedCode = request.headers[pairingCodeHeader] ?? '';
        if (!_secureEquals(submittedCode, pairingCode.value)) {
          _pairingGuard.registerFailure(clientKey);
          final newlyBlockedFor = _pairingGuard.blockedFor(clientKey);
          if (newlyBlockedFor != null) {
            return Future.value(
              _tooManyPairingAttemptsResponse(newlyBlockedFor),
            );
          }
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

        _pairingGuard.registerSuccess(clientKey);
        return innerHandler(request);
      };
    };
  }

  String? _requestClientAddress(shelf.Request request) {
    final connectionInfo = request.context['shelf.io.connection_info'];
    return connectionInfo is HttpConnectionInfo
        ? connectionInfo.remoteAddress.address
        : null;
  }

  shelf.Response _tooManyPairingAttemptsResponse(Duration blockedFor) {
    final retryAfterSeconds = max(1, (blockedFor.inMilliseconds / 1000).ceil());
    return toJsonResponse(
      const {
        'status': false,
        'message': '配对尝试过于频繁，请稍后再试',
      },
      statusCode: HttpStatus.tooManyRequests,
      extraHeaders: {
        HttpHeaders.retryAfterHeader: retryAfterSeconds.toString(),
      },
    );
  }

  shelf.Response _helloRequest(shelf.Request request) {
    return toJsonResponse({
      'status': true,
      'message': 'SimpleLive local sync is running',
      'version': Utils.packageInfo.version,
      'protocolVersion': protocolVersion,
      'minimumProtocolVersion': minimumProtocolVersion,
      'authRequired': true,
      'capabilities': LocalSyncProtocol.capabilities,
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
      'protocolVersion': protocolVersion,
      'minimumProtocolVersion': minimumProtocolVersion,
      'authRequired': true,
      'capabilities': LocalSyncProtocol.capabilities,
    });
  }

  Future<shelf.Response> _syncFollowUserRequest(
    shelf.Request request,
  ) async {
    try {
      final items = await _readJsonList(request, maxItems: _maxFollowItems);
      final users = _parseFollowUsers(items);
      final overlay = _shouldOverlay(request);

      await _synchronizedWrite(
        () => DBService.instance.synchronizedWrite(() async {
          final target = LocalSyncDataMerger.follows(
            existing: DBService.instance.followBox.values,
            incoming: users,
            overlay: overlay,
          );
          await _commitBoxTarget(
            DBService.instance.followBox,
            target,
            overlay: overlay,
          );
        }),
      );

      SmartDialog.showToast('已同步关注用户列表');
      EventBus.instance.emit(Constant.kUpdateFollow, 0);
      return _successResponse();
    } catch (error, stackTrace) {
      return _syncFailureResponse(error, stackTrace);
    }
  }

  Future<shelf.Response> _syncFollowBundleRequest(
    shelf.Request request,
  ) async {
    try {
      final body = await _readJsonMap(request);
      final users = _parseFollowUsers(
        _requireJsonList(body['follows'], maxItems: _maxFollowItems),
      );
      final tags = _parseFollowTags(
        _requireJsonList(body['tags'], maxItems: _maxTagItems),
      );
      final overlay = _shouldOverlay(request);

      await _synchronizedWrite(
        () => DBService.instance.synchronizedWrite(
          () => _commitFollowBundle(
            users: users,
            tags: tags,
            overlay: overlay,
          ),
        ),
      );

      SmartDialog.showToast('已同步关注用户列表和标签');
      EventBus.instance.emit(Constant.kUpdateFollow, 0);
      return _successResponse();
    } catch (error, stackTrace) {
      return _syncFailureResponse(error, stackTrace);
    }
  }

  Future<shelf.Response> _syncFollowUserTagRequest(
    shelf.Request request,
  ) async {
    try {
      final items = await _readJsonList(request, maxItems: _maxTagItems);
      final tags = _parseFollowTags(items);
      final overlay = _shouldOverlay(request);

      await _synchronizedWrite(
        () => DBService.instance.synchronizedWrite(() async {
          final target = LocalSyncDataMerger.tags(
            existing: DBService.instance.tagBox.values,
            incoming: tags,
            overlay: overlay,
          );
          await _commitBoxTarget(
            DBService.instance.tagBox,
            target,
            overlay: overlay,
          );
        }),
      );

      SmartDialog.showToast('已同步标签列表');
      EventBus.instance.emit(Constant.kUpdateFollow, 0);
      return _successResponse();
    } catch (error, stackTrace) {
      return _syncFailureResponse(error, stackTrace);
    }
  }

  Future<shelf.Response> _syncHistoryRequest(shelf.Request request) async {
    try {
      final items = await _readJsonList(request, maxItems: _maxHistoryItems);
      final histories = items
          .map((item) => History.fromJson(_asJsonMap(item)))
          .toList(growable: false);
      final overlay = _shouldOverlay(request);

      await _synchronizedWrite(
        () => DBService.instance.synchronizedWrite(() async {
          final target = LocalSyncDataMerger.histories(
            existing: DBService.instance.historyBox.values,
            incoming: histories,
            overlay: overlay,
          );
          await _commitBoxTarget(
            DBService.instance.historyBox,
            target,
            overlay: overlay,
          );
        }),
      );

      SmartDialog.showToast('已同步观看记录');
      EventBus.instance.emit(Constant.kUpdateHistory, 0);
      return _successResponse();
    } catch (error, stackTrace) {
      return _syncFailureResponse(error, stackTrace);
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
      final overlay = _shouldOverlay(request);
      await _synchronizedWrite(
        () => AppSettingsController.instance.mergeShieldList(
          keywords,
          overlay: overlay,
        ),
      );

      SmartDialog.showToast('已同步弹幕屏蔽词');
      return _successResponse();
    } catch (error, stackTrace) {
      return _syncFailureResponse(error, stackTrace);
    }
  }

  List<FollowUser> _parseFollowUsers(List<dynamic> items) {
    return items
        .map((item) => FollowUser.fromJson(_asJsonMap(item)))
        .toList(growable: false);
  }

  List<FollowUserTag> _parseFollowTags(List<dynamic> items) {
    return items
        .map((item) => FollowUserTag.fromJson(_asJsonMap(item)))
        .toList(growable: false);
  }

  Future<void> _commitFollowBundle({
    required List<FollowUser> users,
    required List<FollowUserTag> tags,
    required bool overlay,
  }) async {
    final followBox = DBService.instance.followBox;
    final tagBox = DBService.instance.tagBox;
    final currentFollows = followBox.toMap();
    final currentTags = tagBox.toMap();
    final targetFollows = LocalSyncDataMerger.follows(
      existing: currentFollows.values,
      incoming: users,
      overlay: overlay,
    );
    final targetTags = LocalSyncDataMerger.tags(
      existing: currentTags.values,
      incoming: tags,
      overlay: overlay,
    );

    // 先写入全部目标记录，再删除差集。进程意外终止时最多残留旧记录，
    // 不会出现 clear 后尚未恢复导致整箱数据丢失。
    await _applyBoxTarget(followBox, targetFollows, overlay: false);
    await _applyBoxTarget(tagBox, targetTags, overlay: false);
    if (overlay) {
      await _deleteStaleKeys(tagBox, targetTags.keys);
      await _deleteStaleKeys(followBox, targetFollows.keys);
    }
  }

  Future<void> _commitBoxTarget<E>(
    Box<E> box,
    Map<String, E> target, {
    required bool overlay,
  }) async {
    await _applyBoxTarget(box, target, overlay: overlay);
  }

  Future<void> _applyBoxTarget<E>(
    Box<E> box,
    Map<String, E> target, {
    required bool overlay,
  }) async {
    if (target.isNotEmpty) {
      await box.putAll(target);
    }
    if (overlay) {
      await _deleteStaleKeys(box, target.keys);
    }
  }

  Future<void> _deleteStaleKeys<E>(
    Box<E> box,
    Iterable<String> retainedKeys,
  ) async {
    final retained = retainedKeys.toSet();
    final staleKeys = box.keys.where((key) => !retained.contains(key)).toList();
    if (staleKeys.isNotEmpty) {
      await box.deleteAll(staleKeys);
    }
  }

  Future<T> _synchronizedWrite<T>(FutureOr<T> Function() action) {
    final generation = _lifecycleGeneration;
    return _writeLock.synchronized(() {
      if (!_acceptingWrites || generation != _lifecycleGeneration) {
        throw const _SyncServiceUnavailableException();
      }
      return action();
    });
  }

  Future<List<dynamic>> _readJsonList(
    shelf.Request request, {
    required int maxItems,
  }) async {
    return _requireJsonList(
      await _readJsonValue(request),
      maxItems: maxItems,
    );
  }

  Future<Map<String, dynamic>> _readJsonMap(shelf.Request request) async {
    final decoded = await _readJsonValue(request);
    if (decoded is! Map) {
      throw const FormatException('请求体必须是 JSON 对象');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<dynamic> _readJsonValue(shelf.Request request) async {
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

    return json.decode(utf8.decode(builder.takeBytes()));
  }

  List<dynamic> _requireJsonList(
    dynamic value, {
    required int maxItems,
  }) {
    if (value is! List) {
      throw const FormatException('同步数据必须是 JSON 数组');
    }
    if (value.length > maxItems) {
      throw const FormatException('同步数据条数超出限制');
    }
    return value;
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

  shelf.Response _syncFailureResponse(
    Object error,
    StackTrace stackTrace,
  ) {
    if (error is _SyncServiceUnavailableException) {
      return toJsonResponse(
        const {
          'status': false,
          'message': '局域网同步服务已停止',
        },
        statusCode: HttpStatus.serviceUnavailable,
      );
    }
    if (error is FormatException ||
        error is TypeError ||
        error is ArgumentError) {
      Log.w('拒绝无效的局域网同步请求：$error', false);
      return toJsonResponse(
        const {
          'status': false,
          'message': '同步数据格式无效',
        },
        statusCode: HttpStatus.badRequest,
      );
    }

    Log.e('写入局域网同步数据失败：$error', stackTrace);
    return toJsonResponse(
      const {
        'status': false,
        'message': '同步数据写入失败',
      },
      statusCode: HttpStatus.internalServerError,
    );
  }

  shelf.Response toJsonResponse(
    Map<String, dynamic> data, {
    int statusCode = HttpStatus.ok,
    Map<String, String> extraHeaders = const {},
  }) {
    return shelf.Response(
      statusCode,
      body: json.encode(data),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        HttpHeaders.cacheControlHeader: 'no-store',
        ...extraHeaders,
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

class _SyncServiceUnavailableException implements Exception {
  const _SyncServiceUnavailableException();
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
