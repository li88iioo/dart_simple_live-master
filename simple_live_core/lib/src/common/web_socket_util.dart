import 'dart:async';

import 'package:web_socket_channel/io.dart';

enum SocketStatus {
  connected,
  failed,
  closed,
}

class WebScoketUtils {
  SocketStatus status = SocketStatus.closed;

  /// 主连接地址。
  final String url;

  /// 备用连接地址。
  final String? backupUrl;

  /// 应用层心跳间隔，单位为毫秒。
  final int heartBeatTime;

  /// 接收到信息。
  final Function(dynamic)? onMessage;

  /// 连接关闭或连接失败。
  final Function(String msg)? onClose;

  /// 开始自动重连。
  final Function()? onReconnect;

  /// WebSocket 握手完成。
  final Function()? onReady;

  /// 发送应用层心跳。
  final Function()? onHeartBeat;

  /// 单次连接超时。
  final Duration connectTimeout;

  /// 常规重连间隔。
  final Duration reconnectInterval;

  /// 常规重连次数耗尽后的低频重试间隔。
  final Duration exhaustedReconnectInterval;

  /// 最长无入站消息时间。为 null 时关闭读 watchdog。
  final Duration? readTimeout;

  /// 请求头。
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
    this.exhaustedReconnectInterval = const Duration(seconds: 45),
    this.readTimeout = const Duration(minutes: 5),
    this.maxReconnectTime = 5,
  });

  IOWebSocketChannel? webSocket;
  Timer? heartBeatTimer;

  /// 已执行的连续常规重连次数；收到任意服务端消息后清零。
  int reconnectTime = 0;
  Timer? reconnectTimer;

  /// 最大连续常规重连次数。
  int maxReconnectTime;

  StreamSubscription<dynamic>? streamSubscription;

  /// 当前连接最后一次收到服务端消息的时间。
  DateTime? get lastInboundAt => _lastInboundAt;

  bool _closedByUser = true;
  bool _reconnectNotified = false;
  bool _reconnectExhaustedNotified = false;
  int _connectionGeneration = 0;
  int? _handledDisconnectGeneration;
  DateTime? _lastInboundAt;
  Timer? _readWatchdogTimer;

  /// 建立连接。每一轮会依次尝试主地址与不同的备用地址。
  Future<void> connect({bool retry = false}) async {
    _closedByUser = false;
    reconnectTimer?.cancel();
    reconnectTimer = null;
    if (!retry) {
      reconnectTime = 0;
      _reconnectNotified = false;
      _reconnectExhaustedNotified = false;
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
    _lastInboundAt = null;

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
    _armReadWatchdog(generation);
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
    if (status == SocketStatus.connected && streamSubscription != null) return;
    _activateConnection(channel, _connectionGeneration);
  }

  void initHeartBeat() {
    heartBeatTimer?.cancel();
    heartBeatTimer = Timer.periodic(
      Duration(milliseconds: heartBeatTime),
      (_) {
        if (_closedByUser || status != SocketStatus.connected) return;
        try {
          onHeartBeat?.call();
        } catch (error) {
          _handleDisconnect(_connectionGeneration, error: error);
        }
      },
    );
  }

  void receiveMessage(dynamic data) {
    _lastInboundAt = DateTime.now();
    _armReadWatchdog(_connectionGeneration);

    // 接收到一条服务端信息才算本轮重连成功。
    reconnectTime = 0;
    _reconnectNotified = false;
    _reconnectExhaustedNotified = false;
    onMessage?.call(data);
  }

  void _armReadWatchdog(int generation) {
    _readWatchdogTimer?.cancel();
    _readWatchdogTimer = null;

    final timeout = readTimeout;
    if (timeout == null || timeout <= Duration.zero) return;

    _readWatchdogTimer = Timer(timeout, () {
      _readWatchdogTimer = null;
      if (_closedByUser || generation != _connectionGeneration) return;
      if (status != SocketStatus.connected) return;

      final lastInboundAt = _lastInboundAt;
      if (lastInboundAt != null) {
        final remaining = timeout - DateTime.now().difference(lastInboundAt);
        if (remaining > Duration.zero) {
          _readWatchdogTimer = Timer(
            remaining,
            () => _handleReadTimeout(generation, timeout),
          );
          return;
        }
      }
      _handleReadTimeout(generation, timeout);
    });
  }

  void _handleReadTimeout(int generation, Duration timeout) {
    _readWatchdogTimer = null;
    if (_closedByUser || generation != _connectionGeneration) return;
    if (status != SocketStatus.connected) return;
    _handleDisconnect(
      generation,
      error: TimeoutException(
        'WebSocket 在 ${timeout.inMilliseconds}ms 内未收到服务端消息',
      ),
    );
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
    _reconnectExhaustedNotified = false;
    _handledDisconnectGeneration = null;
    _connectionGeneration++;

    reconnectTimer?.cancel();
    reconnectTimer = null;
    _closeActiveConnection();
  }

  /// 主动放弃当前连接并进入自动重连流程。
  void reconnect() {
    if (_closedByUser) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closedByUser || reconnectTimer != null) return;

    _connectionGeneration++;
    _handledDisconnectGeneration = null;
    _closeActiveConnection();

    if (!_reconnectNotified) {
      _reconnectNotified = true;
      onReconnect?.call();
      if (_closedByUser) return;
    }

    final bool exhausted = reconnectTime >= maxReconnectTime;
    final Duration delay;
    if (exhausted) {
      status = SocketStatus.failed;
      delay = exhaustedReconnectInterval;
      if (!_reconnectExhaustedNotified) {
        _reconnectExhaustedNotified = true;
        onClose?.call('重连超过最大次数，将低频继续尝试');
        if (_closedByUser) return;
      }
    } else {
      status = SocketStatus.closed;
      reconnectTime++;
      delay = reconnectInterval;
    }

    final preferBackup = reconnectTime.isOdd;
    reconnectTimer = Timer(delay, () {
      reconnectTimer = null;
      if (_closedByUser) return;
      _connectAttempt(preferBackup: preferBackup);
    });
  }

  void _closeActiveConnection() {
    heartBeatTimer?.cancel();
    heartBeatTimer = null;
    _readWatchdogTimer?.cancel();
    _readWatchdogTimer = null;

    final subscription = streamSubscription;
    streamSubscription = null;
    subscription?.cancel();

    final channel = webSocket;
    webSocket = null;
    channel?.sink.close();
  }
}
