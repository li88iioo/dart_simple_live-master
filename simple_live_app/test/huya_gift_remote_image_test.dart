import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_image_loader.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_remote_image.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
const _imageKey = ValueKey('huya-gift-remote-image');
const _fallback = SizedBox(key: ValueKey('fallback'), width: 8, height: 8);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? previousOverrides;
  setUp(() {
    previousOverrides = HttpOverrides.current;
    // 仅本测试使用真实 loopback IO，不依赖公网、磁盘缓存或 provider 的全局 client。
    HttpOverrides.global = _RealHttpOverrides();
  });
  tearDown(() {
    HttpOverrides.global = previousOverrides;
    expect(HuyaGiftImageLoader.activeRequestCount, 0);
    expect(HuyaGiftImageLoader.queuedRequestCount, 0);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  test('URL 校验、去重、候选数量和扫描量均有界', () async {
    expect(
      HuyaGiftImageLoader.normalizeUrl(' //EXAMPLE.com/a.png#ignored '),
      'https://example.com/a.png',
    );
    final loader = HuyaGiftImageLoader();
    for (final url in [
      '',
      'file:///tmp/image.png',
      'data:image/png;base64,abc',
      'ftp://example.com/a',
      'https://user:password@example.com/a',
      'http://@example.com/a',
      'http:///image.png',
      'http://example.com:invalid/a',
      'https://example.com/${'x' * HuyaGiftImageLoader.maxUrlLength}',
    ]) {
      expect(HuyaGiftImageLoader.normalizeUrl(url), isNull, reason: url);
      expect(await loader.load(url).bytes, isNull);
    }
    expect(
        HuyaGiftImageLoader.candidates([
          '//example.com/a',
          'https://example.com/a#fragment',
          ...List.generate(20, (i) => 'https://example.com/$i'),
        ]),
        hasLength(HuyaGiftImageLoader.maxCandidates));
    expect(
        HuyaGiftImageLoader.candidates([
          ...List.filled(HuyaGiftImageLoader.maxCandidateScan, 'invalid'),
          'https://example.com/not-scanned',
        ]),
        isEmpty);
    expect(
        () => HuyaGiftImageLoader(timeout: Duration.zero), throwsArgumentError);
    expect(
      () => HuyaGiftImageLoader(timeout: const Duration(seconds: 6)),
      throwsArgumentError,
    );
  });

  test('cancel 真正停止响应体，排队取消不发请求，立即释放 slot', () async {
    final server = await _serve((request) => request.stream());
    final loader = HuyaGiftImageLoader();
    final first = _load(loader, server.url('/one'));
    final second = _load(loader, server.url('/two'));
    final queued = _load(loader, server.url('/never'));
    await _waitFor(() =>
        server.requests.length == 2 &&
        server.requests.every((request) => request.bytesSent > 0));
    expect(HuyaGiftImageLoader.queuedRequestCount, 1);
    queued.cancel();
    expect(HuyaGiftImageLoader.queuedRequestCount, 0);
    expect(await queued.bytes, isNull);
    first.cancel();
    expect(HuyaGiftImageLoader.activeRequestCount, 1);
    second.cancel();
    second.cancel();
    expect(HuyaGiftImageLoader.activeRequestCount, 0);
    expect(await first.bytes, isNull);
    expect(await second.bytes, isNull);
    await _waitFor(() => server.requests.every((request) => request.isClosed));
    final sent = server.totalBytesSent;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(server.totalBytesSent, sent);
    expect(server.requests, hasLength(2));
  });

  test('整体 timeout 包含持续响应体，截止后真实断流且可继续请求', () async {
    final server = await _serve((request) =>
        request.path == '/ok' ? request.respond(_png) : request.stream());
    final loader =
        HuyaGiftImageLoader(timeout: const Duration(milliseconds: 300));
    final clock = Stopwatch()..start();
    final load = _load(loader, server.url('/slow'));
    await _waitFor(() => server.totalBytesSent > 0);
    expect(await load.bytes, isNull);
    expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    expect(HuyaGiftImageLoader.activeRequestCount, 0);
    await _waitFor(() => server.requests.first.isClosed);
    final sent = server.totalBytesSent;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(server.totalBytesSent, sent);
    expect(await _load(loader, server.url('/ok')).bytes, orderedEquals(_png));
  });

  test('没有响应头也会超时，短队列等待同样计入截止时间', () async {
    final server = await _serve((request) async {
      if (request.path == '/headers') {
        await request.closed;
      } else {
        await request.stream();
      }
    });
    final short =
        HuyaGiftImageLoader(timeout: const Duration(milliseconds: 200));
    final headers = _load(short, server.url('/headers'));
    await _waitFor(() => server.requests.isNotEmpty);
    expect(await headers.bytes, isNull);
    expect(HuyaGiftImageLoader.activeRequestCount, 0);
    final first = _load(HuyaGiftImageLoader(), server.url('/one'));
    final second = _load(HuyaGiftImageLoader(), server.url('/two'));
    final queued = _load(short, server.url('/never'));
    expect(HuyaGiftImageLoader.queuedRequestCount, 1);
    expect(await queued.bytes, isNull);
    expect(HuyaGiftImageLoader.queuedRequestCount, 0);
    expect(
        server.requests.where((request) => request.path == '/never'), isEmpty);
    first.cancel();
    second.cancel();
  });

  test('Content-Length 过大立即关闭，不等完整响应体', () async {
    final server = await _serve((request) => request.stream(
          contentLength: HuyaGiftImageLoader.maxImageBytes + 1,
        ));
    expect(
        await _load(HuyaGiftImageLoader(), server.url('/large')).bytes, isNull);
    await _waitFor(() => server.requests.single.isClosed);
    expect(server.totalBytesSent, lessThan(HuyaGiftImageLoader.maxImageBytes));
  });

  test('chunked 响应体越过 2 MiB 立即断流并释放 slot', () async {
    final server = await _serve((request) => request.stream(
          chunk: Uint8List(64 * 1024),
          interval: const Duration(milliseconds: 1),
        ));
    expect(await _load(HuyaGiftImageLoader(), server.url('/chunked')).bytes,
        isNull);
    expect(HuyaGiftImageLoader.activeRequestCount, 0);
    await _waitFor(() => server.requests.single.isClosed);
    final sent = server.totalBytesSent;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(server.totalBytesSent, sent);
  });

  test('gzip 解压后的字节上限不能被压缩 Content-Length 绕过', () async {
    final compressed =
        gzip.encode(Uint8List(HuyaGiftImageLoader.maxImageBytes + 1));
    expect(compressed.length, lessThan(HuyaGiftImageLoader.maxImageBytes));
    final server = await _serve((request) {
      request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      return request.respond(compressed);
    });
    expect(
        await _load(HuyaGiftImageLoader(), server.url('/gzip')).bytes, isNull);
  });

  test('重定向逐跳校验 URL、限制跳数、不下载重定向响应体', () async {
    late _LocalImageServer server;
    server = await _serve((request) async {
      if (request.path == '/ok') {
        await request.respond(_png);
        return;
      }
      final target = switch (request.path) {
        '/redirect' => '/ok',
        '/credentials' => 'http://user:pass@127.0.0.1:${server.port}/forbidden',
        '/empty-credentials' => 'http://@127.0.0.1:${server.port}/forbidden',
        '/relative-credentials' => '//@127.0.0.1:${server.port}/forbidden',
        '/file' => 'file:///tmp/forbidden.png',
        _ => '/loop',
      };
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(HttpHeaders.locationHeader, target);
      await request.stream();
    });
    final loader = HuyaGiftImageLoader();
    expect(await _load(loader, server.url('/redirect')).bytes,
        orderedEquals(_png));
    for (final path in [
      '/credentials',
      '/empty-credentials',
      '/relative-credentials',
      '/file',
      '/loop'
    ]) {
      expect(await _load(loader, server.url(path)).bytes, isNull);
    }
    expect(server.requests.where((request) => request.path == '/forbidden'),
        isEmpty);
    expect(server.requests.where((request) => request.path == '/loop'),
        hasLength(HuyaGiftImageLoader.maxRedirects + 1));
    await _waitFor(() => server.requests.every((request) => request.isClosed));
  });

  test('相同 URL 共享 IO，取消单个订阅不误伤其它订阅，并命中 LRU', () async {
    final gate = Completer<void>();
    final server = await _serve((request) async {
      await Future.any([gate.future, request.closed]);
      if (!request.isClosed) await request.respond(_png);
    });
    final loader = HuyaGiftImageLoader();
    final url = server.url('/shared');
    final first = _load(loader, url);
    final second = _load(HuyaGiftImageLoader(), '$url#same');
    await _waitFor(() => server.requests.length == 1);
    first.cancel();
    expect(await first.bytes, isNull);
    expect(HuyaGiftImageLoader.activeRequestCount, 1);
    gate.complete();
    final bytes = await second.bytes;
    expect(bytes, orderedEquals(_png));
    expect(await _load(loader, url).bytes, same(bytes));
    expect(server.requests, hasLength(1));
    loader.evict(url);
    expect(await _load(loader, url).bytes, orderedEquals(_png));
    expect(server.requests, hasLength(2));
    expect(server.requests.first.request.headers.value('Referer'),
        'https://www.huya.com/');
    expect(server.requests.first.request.headers.value('User-Agent'),
        contains('Android 13'));
  });

  test('并发上限跨 loader 实例生效，队列只有 8 项，满载立即拒绝', () async {
    final gate = Completer<void>();
    final server = await _serve((request) async {
      await Future.any([gate.future, request.closed]);
      if (!request.isClosed) await request.respond(_png);
    });
    final loads = List.generate(
        10, (i) => _load(HuyaGiftImageLoader(), server.url('/$i')));
    final overflow = _load(HuyaGiftImageLoader(), server.url('/overflow'));
    expect(HuyaGiftImageLoader.activeRequestCount, 2);
    expect(HuyaGiftImageLoader.queuedRequestCount, 8);
    expect(await overflow.bytes, isNull);
    await _waitFor(() => server.requests.length == 2);
    expect(server.peakActive, 2);
    gate.complete();
    for (final bytes in await Future.wait(loads.map((load) => load.bytes))) {
      expect(bytes, orderedEquals(_png));
    }
    expect(server.requests, hasLength(10));
    expect(server.peakActive, lessThanOrEqualTo(2));
  });

  test('共享请求的订阅数量也有界，最后一个取消才关闭', () async {
    final server = await _serve((request) => request.stream());
    final loader = HuyaGiftImageLoader();
    final loads = List.generate(HuyaGiftImageLoader.maxSubscribersPerRequest,
        (_) => _load(loader, server.url('/same')));
    expect(await _load(loader, server.url('/same')).bytes, isNull);
    await _waitFor(() => server.totalBytesSent > 0);
    for (final load in loads.take(loads.length - 1)) {
      load.cancel();
    }
    expect(HuyaGiftImageLoader.activeRequestCount, 1);
    loads.last.cancel();
    expect(HuyaGiftImageLoader.activeRequestCount, 0);
    await _waitFor(() => server.requests.single.isClosed);
  });

  test('LRU 同时限制条数和总字节，命中提升顺序，淘汰后才重新下载', () async {
    final large = Uint8List(1536 * 1024);
    final server = await _serve((request) =>
        request.respond(request.path.startsWith('/large') ? large : _png));
    final loader = HuyaGiftImageLoader();
    for (var i = 0; i < HuyaGiftImageLoader.maxCacheEntries; i++) {
      expect(await _load(loader, server.url('/small/$i')).bytes, isNotNull);
    }
    expect(HuyaGiftImageLoader.cacheEntryCount,
        HuyaGiftImageLoader.maxCacheEntries);
    await _load(loader, server.url('/small/0')).bytes; // 提升最老项。
    await _load(loader, server.url('/small/new')).bytes;
    await _load(loader, server.url('/small/0')).bytes;
    expect(server.requests.where((request) => request.path == '/small/0'),
        hasLength(1));
    await _load(loader, server.url('/small/1')).bytes;
    expect(server.requests.where((request) => request.path == '/small/1'),
        hasLength(2));
    for (var i = 0; i < 3; i++) {
      expect(await _load(loader, server.url('/large/$i')).bytes,
          hasLength(large.length));
      expect(HuyaGiftImageLoader.cachedByteCount,
          lessThanOrEqualTo(HuyaGiftImageLoader.maxCachedBytes));
      expect(HuyaGiftImageLoader.cacheEntryCount,
          lessThanOrEqualTo(HuyaGiftImageLoader.maxCacheEntries));
    }
    await _load(loader, server.url('/large/0')).bytes;
    expect(server.requests.where((request) => request.path == '/large/0'),
        hasLength(2));
  });

  testWidgets('空值和非法候选也固定占位；注入 provider 原样沿用，不访问公网', (tester) async {
    await tester.pumpWidget(_host(const HuyaGiftRemoteImage(
      imageUrls: [],
      size: 48,
      fallback: _fallback,
    )));
    expect(
        tester.getSize(find.byType(HuyaGiftRemoteImage)), const Size(48, 48));
    expect(find.byKey(_imageKey), findsNothing);
    final provider = MemoryImage(_png);
    final urls = <String>[];
    await tester.pumpWidget(_host(HuyaGiftRemoteImage(
      imageUrls: const ['file:///tmp/a', ' //example.invalid/a.png '],
      size: 48,
      fallback: _fallback,
      imageProviderBuilder: (url) {
        urls.add(url);
        return provider;
      },
    )));
    await _pumpUntil(tester, () => _hasDecodedImage(tester));
    expect(urls, ['https://example.invalid/a.png']);
    expect(tester.widget<Image>(find.byKey(_imageKey)).image, same(provider));
    expect(
        tester.getSize(find.byType(HuyaGiftRemoteImage)), const Size(48, 48));
    expect(tester.takeException(), isNull);
    expect(HuyaGiftImageLoader.activeRequestCount, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('provider 抛错及解码失败自动回退，重复 URL 只尝试一次', (tester) async {
    final urls = <String>[];
    await tester.pumpWidget(_host(HuyaGiftRemoteImage(
      imageUrls: const [
        'https://example.invalid/throws',
        'https://example.invalid/broken',
        'https://example.invalid/broken#same',
        'https://example.invalid/ok',
      ],
      size: 48,
      fallback: _fallback,
      imageProviderBuilder: (url) {
        urls.add(url);
        if (url.endsWith('/throws')) throw StateError('test provider');
        return MemoryImage(url.endsWith('/ok') ? _png : Uint8List(0));
      },
    )));
    await _pumpUntil(tester, () => _hasDecodedImage(tester));
    expect(
        urls.map((url) => Uri.parse(url).path), ['/throws', '/broken', '/ok']);
    expect(
        tester.getSize(find.byType(HuyaGiftRemoteImage)), const Size(48, 48));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('候选最多 4 个，失败到底不循环、不越界', (tester) async {
    final urls = <String>[];
    await tester.pumpWidget(_host(HuyaGiftRemoteImage(
      imageUrls: List.generate(30, (i) => 'https://example.invalid/$i'),
      size: 48,
      fallback: _fallback,
      imageProviderBuilder: (url) {
        urls.add(url);
        return MemoryImage(Uint8List(0));
      },
    )));
    await _pumpUntil(
        tester,
        () =>
            urls.length == HuyaGiftImageLoader.maxCandidates &&
            find.byKey(_imageKey).evaluate().isEmpty);
    await tester.pump(const Duration(seconds: 6));
    expect(urls, hasLength(HuyaGiftImageLoader.maxCandidates));
    expect(
        tester.getSize(find.byType(HuyaGiftRemoteImage)), const Size(48, 48));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('更新时旧 errorBuilder/异步回调不能推进新一代候选，builder 变更可重载', (tester) async {
    final oldUrls = <String>[];
    final oldProvider = MemoryImage(_png);
    await tester.pumpWidget(_host(HuyaGiftRemoteImage(
      imageUrls: const [
        'https://example.invalid/old',
        'https://example.invalid/never'
      ],
      size: 48,
      fallback: _fallback,
      imageProviderBuilder: (url) {
        oldUrls.add(url);
        return oldProvider;
      },
    )));
    final oldImage = tester.widget<Image>(find.byKey(_imageKey));
    final currentUrls = <String>[];
    final currentProvider = MemoryImage(Uint8List.fromList(_png));
    await tester.pumpWidget(_host(HuyaGiftRemoteImage(
      imageUrls: const [
        'https://example.invalid/new',
        'https://example.invalid/not-next'
      ],
      size: 48,
      fallback: _fallback,
      imageProviderBuilder: (url) {
        currentUrls.add(url);
        return currentProvider;
      },
    )));
    oldImage.errorBuilder!(tester.element(find.byKey(_imageKey)),
        StateError('late'), StackTrace.current);
    await _pumpUntil(tester, () => _hasDecodedImage(tester));
    await tester.pump();
    expect(oldUrls, ['https://example.invalid/old']);
    expect(currentUrls, ['https://example.invalid/new']);
    expect(tester.widget<Image>(find.byKey(_imageKey)).image,
        same(currentProvider));
    final replacement = MemoryImage(Uint8List.fromList(_png));
    await tester.pumpWidget(_host(HuyaGiftRemoteImage(
      imageUrls: const [
        'https://example.invalid/new',
        'https://example.invalid/not-next'
      ],
      size: 48,
      fallback: _fallback,
      imageProviderBuilder: (_) => replacement,
    )));
    expect(
        tester.widget<Image>(find.byKey(_imageKey)).image, same(replacement));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('慢服务上更新/销毁立即断流；5.5s 后无残留下载或 imageCache pending', (tester) async {
    final server = await _widgetServer(tester, (request) => request.stream());
    final pendingBefore = PaintingBinding.instance.imageCache.pendingImageCount;
    for (var i = 0; i < 3; i++) {
      await tester.pumpWidget(_host(HuyaGiftRemoteImage(
        imageUrls: [server.url('/slow/$i')],
        size: 48,
        fallback: _fallback,
      )));
      await _pumpUntil(
          tester,
          () =>
              server.requests.length == i + 1 &&
              server.requests.last.bytesSent > 0);
      expect(HuyaGiftImageLoader.activeRequestCount, 1);
      expect(
          tester.getSize(find.byType(HuyaGiftRemoteImage)), const Size(48, 48));
      if (i > 0) {
        await tester
            .runAsync(() => _waitFor(() => server.requests[i - 1].isClosed));
      }
    }
    await tester.pumpWidget(const SizedBox());
    expect(HuyaGiftImageLoader.activeRequestCount, 0);
    await tester.runAsync(
        () => _waitFor(() => server.requests.every((r) => r.isClosed)));
    final sent = server.totalBytesSent;
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5500)));
    await tester.pump(const Duration(milliseconds: 5500));
    expect(server.totalBytesSent, sent);
    expect(server.requests, hasLength(3));
    expect(
        PaintingBinding.instance.imageCache.pendingImageCount, pendingBefore);
    expect(tester.takeException(), isNull);
  });

  testWidgets('网络候选回退、更新代际隔离和实际解码最长边 160px', (tester) async {
    final png = (await tester.runAsync(_largePng))!;
    final server = await _widgetServer(tester, (request) async {
      switch (request.path) {
        case '/slow':
          await request.stream();
        case '/missing':
          await request.respond([], status: HttpStatus.notFound);
        case '/broken':
          await request.respond([0, 1, 2]);
        default:
          await request.respond(png);
      }
    });
    await tester.pumpWidget(_host(HuyaGiftRemoteImage(
      imageUrls: [server.url('/slow'), server.url('/old-never')],
      size: 100,
      fallback: _fallback,
    )));
    await _pumpUntil(tester, () => server.totalBytesSent > 0);
    await tester.pumpWidget(_host(HuyaGiftRemoteImage(
      imageUrls: [
        server.url('/missing'),
        server.url('/broken'),
        server.url('/ok')
      ],
      size: 100,
      fallback: _fallback,
    )));
    await _pumpUntil(tester, () => _hasDecodedImage(tester));
    await tester.runAsync(() => _waitFor(() => server.requests.first.isClosed));
    expect(server.requests.map((r) => r.path),
        ['/slow', '/missing', '/broken', '/ok']);
    final image = tester.widget<RawImage>(find.byType(RawImage)).image!;
    expect(image.width, 160);
    expect(image.height, 80); // fit 解码保留宽高比。
    expect(
        tester.getSize(find.byType(HuyaGiftRemoteImage)), const Size(100, 100));
    final provider =
        tester.widget<Image>(find.byKey(_imageKey)).image as ResizeImage;
    expect((provider.imageProvider as MemoryImage).bytes, orderedEquals(png));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('GIF 继续由 Image SDK 解码并响应 disableAnimations 和 TickerMode',
      (tester) async {
    final gif = _twoFrameGif();
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(gif);
      expect(codec.frameCount, 2);
      codec.dispose();
    });
    final server =
        await _widgetServer(tester, (request) => request.respond(gif));
    for (final disableAnimations in [true, false]) {
      final gift = HuyaGiftRemoteImage(
        key: ValueKey(disableAnimations),
        imageUrls: [server.url('/gif/$disableAnimations')],
        size: 48,
        fallback: _fallback,
      );
      Widget host({required bool paused}) => _host(
            TickerMode(enabled: disableAnimations || !paused, child: gift),
            disableAnimations: disableAnimations && paused,
          );
      await tester.pumpWidget(host(paused: true));
      await _pumpUntil(tester, () => _hasDecodedImage(tester));
      final firstFrame = tester.widget<RawImage>(find.byType(RawImage)).image;
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<RawImage>(find.byType(RawImage)).image,
          same(firstFrame));
      // 恢复动画后仍是同一个 SDK Image，而不是自行取首帧破坏 GIF。
      await tester.pumpWidget(host(paused: false));
      var advanced = false;
      for (var i = 0; i < 20 && !advanced; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 60));
        advanced = !identical(
            tester.widget<RawImage>(find.byType(RawImage)).image, firstFrame);
      }
      expect(advanced, isTrue);
      expect(
          tester.getSize(find.byType(HuyaGiftRemoteImage)), const Size(48, 48));
      await tester.pumpWidget(const SizedBox());
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Widget 超时后自动使用下一候选，更新 loader 会取消前一请求', (tester) async {
    final server = await _widgetServer(
        tester,
        (request) =>
            request.path == '/ok' ? request.respond(_png) : request.stream());
    final urls = [server.url('/slow'), server.url('/ok')];
    await tester.pumpWidget(_host(HuyaGiftRemoteImage(
      imageUrls: urls,
      size: 48,
      fallback: _fallback,
    )));
    await _pumpUntil(tester, () => server.totalBytesSent > 0);
    await tester.pumpWidget(_host(HuyaGiftRemoteImage(
      imageUrls: urls,
      size: 48,
      fallback: _fallback,
      loader: HuyaGiftImageLoader(timeout: const Duration(milliseconds: 200)),
    )));
    await _pumpUntil(
        tester,
        () =>
            server.requests.length == 2 && server.requests.last.bytesSent > 0);
    await tester.pump(const Duration(milliseconds: 201));
    await _pumpUntil(tester, () => _hasDecodedImage(tester));
    await tester.runAsync(
        () => _waitFor(() => server.requests.take(2).every((r) => r.isClosed)));
    expect(server.requests.map((r) => r.path), ['/slow', '/slow', '/ok']);
    expect(
        tester.getSize(find.byType(HuyaGiftRemoteImage)), const Size(48, 48));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

HuyaGiftImageLoad _load(HuyaGiftImageLoader loader, String url) {
  final load = loader.load(url);
  addTearDown(load.cancel);
  return load;
}

Widget _host(Widget child, {bool disableAnimations = true}) => MediaQuery(
      data: MediaQueryData(
          devicePixelRatio: 4, disableAnimations: disableAnimations),
      child: Directionality(
          textDirection: TextDirection.ltr, child: Center(child: child)),
    );

bool _hasDecodedImage(WidgetTester tester) =>
    find.byType(RawImage).evaluate().isNotEmpty &&
    tester.widget<RawImage>(find.byType(RawImage)).image != null;

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (condition()) return;
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  fail('Widget 在 2 秒内未达到预期状态');
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('本地 HTTP 服务在 2 秒内未达到预期状态');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

// 两个 1×1 黑/白帧，每帧 100ms，无限循环；自包含 GIF fixture。
Uint8List _twoFrameGif() => Uint8List.fromList([
      ...ascii.encode('GIF89a'),
      1,
      0,
      1,
      0,
      0x80,
      0,
      0,
      0,
      0,
      0,
      255,
      255,
      255,
      0x21,
      0xff,
      11,
      ...ascii.encode('NETSCAPE2.0'),
      3,
      1,
      0,
      0,
      0,
      for (final pixel in [0x44, 0x4c]) ...[
        0x21,
        0xf9,
        4,
        0,
        10,
        0,
        0,
        0,
        0x2c,
        0,
        0,
        0,
        0,
        1,
        0,
        1,
        0,
        0,
        2,
        2,
        pixel,
        1,
        0,
      ],
      0x3b,
    ]);

Future<Uint8List> _largePng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const Color(0xffff0000), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(800, 400);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<_LocalImageServer> _serve(
    Future<void> Function(_ServerRequest) handler) async {
  final server = await _LocalImageServer.start(handler);
  addTearDown(server.close);
  return server;
}

Future<_LocalImageServer> _widgetServer(
  WidgetTester tester,
  Future<void> Function(_ServerRequest) handler,
) async {
  final server =
      (await tester.runAsync(() => _LocalImageServer.start(handler)))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(server.close);
  });
  return server;
}

class _RealHttpOverrides extends HttpOverrides {}

class _LocalImageServer {
  _LocalImageServer(this.server);

  final HttpServer server;
  final requests = <_ServerRequest>[];
  final _handlers = <Future<void>>[];
  int active = 0;
  int peakActive = 0;

  int get port => server.port;
  int get totalBytesSent =>
      requests.fold(0, (total, request) => total + request.bytesSent);
  String url(String path) => 'http://127.0.0.1:$port$path';

  static Future<_LocalImageServer> start(
      Future<void> Function(_ServerRequest) handler) async {
    final result = _LocalImageServer(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    result.server.listen((request) {
      result.active++;
      if (result.active > result.peakActive) result.peakActive = result.active;
      final tracked = _ServerRequest(request, () => result.active--);
      result.requests.add(tracked);
      result._handlers.add(() async {
        try {
          await handler(tracked);
        } on HttpException {
          tracked.markClosed();
        } on SocketException {
          tracked.markClosed();
        }
      }());
    });
    return result;
  }

  Future<void> close() async {
    // 仅测试清理才人工标记；断流断言在调用 close 之前检查服务端真实关闭事件。
    for (final request in requests) {
      request.markClosed();
      request.socket?.destroy();
    }
    await server.close(force: true);
    await Future.wait(_handlers);
  }
}

class _ServerRequest {
  _ServerRequest(this.request, this.onClosed) {
    unawaited(response.done.then<void>(
      (_) {
        if (!_detached) markClosed();
      },
      onError: (Object error, StackTrace stack) {
        if (!_detached) markClosed();
      },
    ));
  }

  final HttpRequest request;
  final void Function() onClosed;
  final _closed = Completer<void>();
  int bytesSent = 0;
  bool _detached = false;
  Socket? socket;
  HttpResponse get response => request.response;
  String get path => request.uri.path;
  Future<void> get closed => _closed.future;
  bool get isClosed => _closed.isCompleted;

  void markClosed() {
    if (isClosed) return;
    _closed.complete();
    onClosed();
  }

  Future<void> respond(List<int> bytes, {int status = HttpStatus.ok}) async {
    response.statusCode = status;
    response.headers.contentType = ContentType('image', 'png');
    response.contentLength = bytes.length;
    response.add(bytes);
    await response.close();
    bytesSent += bytes.length;
  }

  Future<void> stream({
    List<int>? chunk,
    int? contentLength,
    Duration interval = const Duration(milliseconds: 10),
  }) async {
    final bytes = chunk ?? Uint8List(1024);
    // HttpResponse.done 对尚未 close 的响应体不保证及时报告断连。
    // 仍由本地 HttpServer 接收请求，但慢响应直接观察 TCP EOF/error，
    // 避免将“Future 已完成/计数器归零”误当作真实 IO 已关闭。
    _detached = true;
    final connection = await response.detachSocket(writeHeaders: false);
    socket = connection;
    connection.listen(
      (_) {},
      onDone: () {
        markClosed();
        connection.destroy();
      },
      onError: (Object error) {
        markClosed();
        connection.destroy();
      },
    );
    final headers = StringBuffer('HTTP/1.1 ${response.statusCode} Test\r\n');
    response.headers.forEach((name, values) {
      if (name != HttpHeaders.contentLengthHeader &&
          name != HttpHeaders.transferEncodingHeader &&
          name != HttpHeaders.connectionHeader) {
        headers.write('$name: ${values.join(', ')}\r\n');
      }
    });
    headers.write(contentLength == null
        ? 'Transfer-Encoding: chunked\r\n'
        : 'Content-Length: $contentLength\r\n');
    headers.write('Connection: close\r\n\r\n');
    connection.add(ascii.encode(headers.toString()));
    while (!isClosed) {
      if (contentLength == null) {
        connection.add(ascii.encode('${bytes.length.toRadixString(16)}\r\n'));
      }
      connection.add(bytes);
      if (contentLength == null) connection.add(const [13, 10]);
      await Future.any([connection.flush(), closed]);
      if (isClosed) return;
      bytesSent += bytes.length;
      await Future<void>.delayed(interval);
    }
  }
}
