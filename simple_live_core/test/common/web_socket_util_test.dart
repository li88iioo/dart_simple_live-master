import 'dart:async';
import 'dart:io';

import 'package:simple_live_core/src/common/web_socket_util.dart';
import 'package:test/test.dart';

void main() {
  test('连接连续断开时会持续重连，收到消息后重置计数', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final received = Completer<void>();
    var connectionCount = 0;
    var reconnectNoticeCount = 0;

    final serverSubscription = server.listen((request) async {
      final serverSocket = await WebSocketTransformer.upgrade(request);
      sockets.add(serverSocket);
      connectionCount++;
      if (connectionCount < 3) {
        Timer(const Duration(milliseconds: 10), serverSocket.close);
      } else {
        Timer(const Duration(milliseconds: 10), () {
          serverSocket.add(<int>[1, 2, 3]);
        });
      }
    });

    final socket = WebScoketUtils(
      url: 'ws://${server.address.address}:${server.port}',
      heartBeatTime: 60 * 1000,
      connectTimeout: const Duration(seconds: 1),
      reconnectInterval: const Duration(milliseconds: 15),
      readTimeout: const Duration(seconds: 1),
      maxReconnectTime: 5,
      onReconnect: () => reconnectNoticeCount++,
      onMessage: (_) {
        if (!received.isCompleted) received.complete();
      },
    );

    addTearDown(() async {
      socket.close();
      for (final serverSocket in sockets) {
        await serverSocket.close();
      }
      await serverSubscription.cancel();
      await server.close(force: true);
    });

    await socket.connect();
    await received.future.timeout(const Duration(seconds: 3));

    expect(connectionCount, 3);
    expect(reconnectNoticeCount, 1);
    expect(socket.reconnectTime, 0);
    expect(socket.status, SocketStatus.connected);
    expect(socket.lastInboundAt, isNotNull);
  });

  test('常规重连耗尽后低频继续，收到消息后恢复健康状态', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final reconnectExhausted = Completer<void>();
    final received = Completer<void>();
    var connectionCount = 0;

    final serverSubscription = server.listen((request) async {
      final serverSocket = await WebSocketTransformer.upgrade(request);
      sockets.add(serverSocket);
      connectionCount++;
      if (connectionCount <= 3) {
        Timer(const Duration(milliseconds: 8), serverSocket.close);
      } else {
        Timer(const Duration(milliseconds: 8), () {
          serverSocket.add(<int>[7]);
        });
      }
    });

    final socket = WebScoketUtils(
      url: 'ws://${server.address.address}:${server.port}',
      heartBeatTime: 60 * 1000,
      connectTimeout: const Duration(seconds: 1),
      reconnectInterval: const Duration(milliseconds: 12),
      exhaustedReconnectInterval: const Duration(milliseconds: 45),
      readTimeout: const Duration(seconds: 1),
      maxReconnectTime: 2,
      onMessage: (_) {
        if (!received.isCompleted) received.complete();
      },
      onClose: (message) {
        if (message.contains('重连超过最大次数') && !reconnectExhausted.isCompleted) {
          reconnectExhausted.complete();
        }
      },
    );

    addTearDown(() async {
      socket.close();
      for (final serverSocket in sockets) {
        await serverSocket.close();
      }
      await serverSubscription.cancel();
      await server.close(force: true);
    });

    await socket.connect();
    await reconnectExhausted.future.timeout(const Duration(seconds: 3));
    expect(connectionCount, 3);
    expect(socket.status, SocketStatus.failed);

    await received.future.timeout(const Duration(seconds: 3));
    expect(connectionCount, 4);
    expect(socket.status, SocketStatus.connected);
    expect(socket.reconnectTime, 0);
  });

  test('读 watchdog 会断开无入站数据的半开连接并重连', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final received = Completer<void>();
    var connectionCount = 0;

    final serverSubscription = server.listen((request) async {
      final serverSocket = await WebSocketTransformer.upgrade(request);
      sockets.add(serverSocket);
      connectionCount++;
      if (connectionCount == 2) {
        Timer(const Duration(milliseconds: 8), () {
          serverSocket.add(<int>[9]);
        });
      }
    });

    final socket = WebScoketUtils(
      url: 'ws://${server.address.address}:${server.port}',
      heartBeatTime: 60 * 1000,
      connectTimeout: const Duration(seconds: 1),
      reconnectInterval: const Duration(milliseconds: 12),
      readTimeout: const Duration(milliseconds: 45),
      maxReconnectTime: 2,
      onMessage: (_) {
        if (!received.isCompleted) received.complete();
      },
    );

    addTearDown(() async {
      socket.close();
      for (final serverSocket in sockets) {
        await serverSocket.close();
      }
      await serverSubscription.cancel();
      await server.close(force: true);
    });

    await socket.connect();
    await received.future.timeout(const Duration(seconds: 3));

    expect(connectionCount, 2);
    expect(socket.status, SocketStatus.connected);
    expect(socket.lastInboundAt, isNotNull);
  });

  test('主动关闭会取消已经排队的常规重连', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final reconnectScheduled = Completer<void>();
    var connectionCount = 0;

    final serverSubscription = server.listen((request) async {
      final serverSocket = await WebSocketTransformer.upgrade(request);
      sockets.add(serverSocket);
      connectionCount++;
      Timer(const Duration(milliseconds: 10), serverSocket.close);
    });

    final socket = WebScoketUtils(
      url: 'ws://${server.address.address}:${server.port}',
      heartBeatTime: 60 * 1000,
      connectTimeout: const Duration(seconds: 1),
      reconnectInterval: const Duration(milliseconds: 80),
      onReconnect: () {
        if (!reconnectScheduled.isCompleted) reconnectScheduled.complete();
      },
    );

    addTearDown(() async {
      socket.close();
      for (final serverSocket in sockets) {
        await serverSocket.close();
      }
      await serverSubscription.cancel();
      await server.close(force: true);
    });

    await socket.connect();
    await reconnectScheduled.future.timeout(const Duration(seconds: 2));
    socket.close();
    await Future<void>.delayed(const Duration(milliseconds: 160));

    expect(connectionCount, 1);
    expect(socket.status, SocketStatus.closed);
  });

  test('主动关闭会取消已经排队的低频重连', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final reconnectExhausted = Completer<void>();
    var connectionCount = 0;

    final serverSubscription = server.listen((request) async {
      final serverSocket = await WebSocketTransformer.upgrade(request);
      sockets.add(serverSocket);
      connectionCount++;
      Timer(const Duration(milliseconds: 8), serverSocket.close);
    });

    final socket = WebScoketUtils(
      url: 'ws://${server.address.address}:${server.port}',
      heartBeatTime: 60 * 1000,
      connectTimeout: const Duration(seconds: 1),
      exhaustedReconnectInterval: const Duration(milliseconds: 100),
      maxReconnectTime: 0,
      onClose: (message) {
        if (message.contains('重连超过最大次数') && !reconnectExhausted.isCompleted) {
          reconnectExhausted.complete();
        }
      },
    );

    addTearDown(() async {
      socket.close();
      for (final serverSocket in sockets) {
        await serverSocket.close();
      }
      await serverSubscription.cancel();
      await server.close(force: true);
    });

    await socket.connect();
    await reconnectExhausted.future.timeout(const Duration(seconds: 2));
    socket.close();
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(connectionCount, 1);
    expect(socket.status, SocketStatus.closed);
  });
}
