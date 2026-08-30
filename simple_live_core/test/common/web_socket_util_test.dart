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
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      connectionCount++;
      if (connectionCount < 3) {
        Timer(const Duration(milliseconds: 10), socket.close);
      } else {
        Timer(const Duration(milliseconds: 10), () {
          socket.add(<int>[1, 2, 3]);
        });
      }
    });

    final socket = WebScoketUtils(
      url: 'ws://${server.address.address}:${server.port}',
      heartBeatTime: 60 * 1000,
      connectTimeout: const Duration(seconds: 1),
      reconnectInterval: const Duration(milliseconds: 15),
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
  });

  test('连续失败只执行配置的最大重连次数', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final reconnectExhausted = Completer<void>();
    var connectionCount = 0;

    final serverSubscription = server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      connectionCount++;
      Timer(const Duration(milliseconds: 10), socket.close);
    });

    final socket = WebScoketUtils(
      url: 'ws://${server.address.address}:${server.port}',
      heartBeatTime: 60 * 1000,
      connectTimeout: const Duration(seconds: 1),
      reconnectInterval: const Duration(milliseconds: 15),
      maxReconnectTime: 2,
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
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(connectionCount, 3);
    expect(socket.status, SocketStatus.closed);
  });

  test('主动关闭会取消已经排队的重连', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final reconnectScheduled = Completer<void>();
    var connectionCount = 0;

    final serverSubscription = server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      connectionCount++;
      Timer(const Duration(milliseconds: 10), socket.close);
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
}
