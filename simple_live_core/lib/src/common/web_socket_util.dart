import 'dart:async';

import 'package:web_socket_channel/io.dart';

enum SocketStatus {
  connected,
  failed,
  closed,
}

class WebScoketUtils {
  SocketStatus status = SocketStatus.closed;

  /// 链接
  final String url;

  /// 备用链接
  final String? backupUrl;

  /// 心跳时间
  final int heartBeatTime;

  /// 接收到信息
  final Function(dynamic)? onMessage;

  /// 连接关闭
  final Function(String msg)? onClose;

  /// 尝试重连
  final Function()? onReconnect;

  /// 准备就绪
  final Function()? onReady;

  /// 心跳
  final Function()? onHeartBeat;

  /// 单次连接超时
  final Duration connectTimeout;

  /// 两次重连之间的等待时间
  final Duration reconnectInterval;

  /// 请求头
  Map<String, dynamic>? headers;

  WebScoketUtils({
    required this.url,
    required this.heartBeatTime,
    this.onMessage,
    this.onClose,
    this.onReconnect,
    this.onReady,
    this.onHeartBeat,
    this.headers,
    this.backupUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.reconnectInterval = const Duration(seconds: 5),
    this.maxReconnectTime = 5,
  });

  IOWebSocketChannel? webSocket;
  Timer? heartBeatTimer;

  /// 已执行的连续重连次数；收到任意服务端消息后清零。
  int reconnectTime = 0;
  Timer? reconnectTimer;

  /// 最大连续重连次数
  int maxReconnectTime;

  StreamSubscription<dynamic>? streamSubscription;

  bool _closedByUser = true;
  bool _reconnectNotified = false;
  int _connectionGeneration = 0;
  int? _handledDisconnectGeneration;

  /// 建立连接。每一轮会依次尝试主地址与不同的备用地址。
  Future<void> connect({bool retry = false}) async {
    _closedByUser = false;
    reconnectTimer?.cancel();
    reconnectTimer = null;
    if (!retry) {
      reconnectTime = 0;
      _reconnectNotified = false;
    }
    await _connectAttempt(preferBackup: retry);
  }

  Future<void> _connectAttempt({bool preferBackup = false}) async {
    if (_closedByUser) return;

    final generation = ++_connectionGeneration;
    _handledDisconnectGeneration = null;
    _closeActiveConnection();
    status = SocketStatus.closed;

    Object? lastError;
    for (final wsUrl in _connectionCandidates(preferBackup: preferBackup)) {
      if (_closedByUser || generation != _connectionGeneration) return;

      IOWebSocketChannel? channel;
      try {
        channel = IOWebSocketChannel.connect(
          wsUrl,
          connectTimeout: connectTimeout,
          headers: headers,
        );
        webSocket = channel;
        await channel.ready;
      } catch (error) {
        lastError = error;
        if (identical(webSocket, channel)) {
          webSocket = null;
        }
        channel?.sink.close();
        continue;
      }

      if (_closedByUser || generation != _connectionGeneration) {
        channel.sink.close();
        return;
      }

      _activateConnection(channel, generation);
      return;
    }

    if (_closedByUser || generation != _connectionGeneration) return;
    status = SocketStatus.failed;
    if (lastError != null && !_reconnectNotified) {
      onClose?.call(lastError.toString());
    }
    if (_closedByUser || generation != _connectionGeneration) return;
    _scheduleReconnect();
  }

  List<String> _connectionCandidates({required bool preferBackup}) {
    final result = <String>[];

    void addIfNew(String? value) {
      if (value != null && value.isNotEmpty && !result.contains(value)) {
        result.add(value);
      }
    }

    if (preferBackup) {
      addIfNew(backupUrl);
      addIfNew(url);
    } else {
      addIfNew(url);
      addIfNew(backupUrl);
    }
    return result;
  }

  void _activateConnection(IOWebSocketChannel channel, int generation) {
    webSocket = channel;
    status = SocketStatus.connected;
    _handledDisconnectGeneration = null;

    streamSubscription = channel.stream.listen(
      (data) {
        if (generation != _connectionGeneration || _closedByUser) return;
        receiveMessage(data);
      },
      onError: (Object error, StackTrace _) {
        _handleDisconnect(generation, error: error);
      },
      onDone: () => _handleDisconnect(generation),
    );

    initHeartBeat();
    try {
      onReady?.call();
    } catch (error) {
      _handleDisconnect(generation, error: error);
    }
  }

  /// 连接完成。保留该方法以兼容既有调用。
  void ready() {
    final channel = webSocket;
    if (channel == null || _closedByUser) return;
    _activateConnection(channel, _connectionGeneration);
  }

  void initHeartBeat() {
    heartBeatTimer?.cancel();
    heartBeatTimer = Timer.periodic(
      Duration(milliseconds: heartBeatTime),
      (timer) {
        onHeartBeat?.call();
      },
    );
  }

  void receiveMessage(dynamic data) {
    // 接收到一条服务端信息才算本轮重连成功。
    reconnectTime = 0;
    _reconnectNotified = false;
    onMessage?.call(data);
  }

  void onError(Object error, StackTrace _) {
    _handleDisconnect(_connectionGeneration, error: error);
  }

  void onDone() {
    _handleDisconnect(_connectionGeneration);
  }

  void _handleDisconnect(
    int generation, {
    Object? error,
  }) {
    if (_closedByUser || generation != _connectionGeneration) return;
    if (_handledDisconnectGeneration == generation) return;
    _handledDisconnectGeneration = generation;

    if (error != null) {
      status = SocketStatus.failed;
      if (!_reconnectNotified) {
        onClose?.call(error.toString());
      }
      if (_closedByUser || generation != _connectionGeneration) return;
    }
    _scheduleReconnect();
  }

  void sendMessage(dynamic message) {
    if (status != SocketStatus.connected) return;
    try {
      webSocket?.sink.add(message);
    } catch (error) {
      _handleDisconnect(_connectionGeneration, error: error);
    }
  }

  /// 主动关闭；后续不会自动重连。
  void close() {
    _closedByUser = true;
    status = SocketStatus.closed;
    reconnectTime = 0;
    _reconnectNotified = false;
    _handledDisconnectGeneration = null;
    _connectionGeneration++;

    reconnectTimer?.cancel();
    reconnectTimer = null;
    _closeActiveConnection();
  }

  /// 主动放弃当前连接并进入有限次数的重连流程。
  void reconnect() {
    if (_closedByUser) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closedByUser || reconnectTimer != null) return;

    _connectionGeneration++;
    _handledDisconnectGeneration = null;
    _closeActiveConnection();
    status = SocketStatus.closed;

    if (reconnectTime >= maxReconnectTime) {
      close();
      onClose?.call("重连超过最大次数，与服务器断开连接");
      return;
    }

    reconnectTime++;
    if (!_reconnectNotified) {
      _reconnectNotified = true;
      onReconnect?.call();
      if (_closedByUser) return;
    }

    reconnectTimer = Timer(reconnectInterval, () {
      reconnectTimer = null;
      if (_closedByUser) return;
      _connectAttempt();
    });
  }

  void _closeActiveConnection() {
    heartBeatTimer?.cancel();
    heartBeatTimer = null;

    final subscription = streamSubscription;
    streamSubscription = null;
    subscription?.cancel();

    final channel = webSocket;
    webSocket = null;
    channel?.sink.close();
  }
}
