import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

/// 一次礼物图片订阅。失败、超时和取消均返回 null，不留下未处理的异步错误。
class HuyaGiftImageLoad {
  final Completer<Uint8List?> _completer = Completer<Uint8List?>();
  void Function()? _onCancel;

  /// 缓存字节与其它订阅者共享，调用方不得修改（与 MemoryImage 约定一致）。
  Future<Uint8List?> get bytes => _completer.future;

  /// 同步取消订阅；最后一个订阅者离开时，立即关闭 IO 并归还并发名额。
  void cancel() {
    final onCancel = _onCancel;
    _complete(null);
    onCancel?.call();
  }

  void _complete(Uint8List? bytes) {
    _onCancel = null;
    if (!_completer.isCompleted) _completer.complete(bytes);
  }
}

/// 仅供虎牙礼物图片使用的有界内存加载器，不使用磁盘缓存或全局网络 provider。
///
/// 所有实例共用并发、队列、URL 去重与 LRU。重复 URL 共享请求，但各自取消；
/// 后加入的订阅者不会延长原请求的截止时间。队列满时立即失败，由组件尝试候选。
class HuyaGiftImageLoader {
  HuyaGiftImageLoader({this.timeout = maxTimeout}) {
    if (timeout <= Duration.zero || timeout > maxTimeout) {
      throw ArgumentError.value(timeout, 'timeout', '必须大于 0 且不超过 5 秒');
    }
  }

  static final HuyaGiftImageLoader shared = HuyaGiftImageLoader();
  static const maxTimeout = Duration(seconds: 5);
  static const maxConcurrentRequests = 2;
  static const maxQueuedRequests = 8;
  static const maxImageBytes = 2 * 1024 * 1024;
  static const maxCachedBytes = 4 * 1024 * 1024;
  static const maxCacheEntries = 24;
  static const maxCandidates = 4;
  static const maxCandidateScan = 16;
  static const maxUrlLength = 4096;
  static const maxSubscribersPerRequest = 32;
  static const maxRedirects = 2;

  /// 可缩短以测试超时；计时包含排队、连接、重定向和整个响应体。
  final Duration timeout;

  static final _credentialsAuthority =
      RegExp(r'^https?://[^/?#]*@', caseSensitive: false);
  static final _jobs = <String, _GiftImageJob>{};
  static final _queue = Queue<_GiftImageJob>();
  static final _cache = <String, Uint8List>{};
  static int _active = 0;
  static int _cachedBytes = 0;

  // 同时用于本地服务器回归验证；没有可绕过限制的可写配置。
  static int get activeRequestCount => _active;
  static int get queuedRequestCount => _queue.length;
  static int get cacheEntryCount => _cache.length;
  static int get cachedByteCount => _cachedBytes;

  /// 兼容协议相对 URL；不允许其它协议、用户凭据或超长 URL。
  static String? normalizeUrl(String value) {
    if (value.length > maxUrlLength) return null;
    var normalized = value.trim();
    if (normalized.startsWith('//')) normalized = 'https:$normalized';
    // Uri 会消去空 userInfo（http://@host），必须在规范化前拒绝。
    if (_credentialsAuthority.hasMatch(normalized)) return null;
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.authority.contains('@')) {
      return null;
    }
    return uri.removeFragment().toString();
  }

  /// 连扫描量也限制，避免外部候选列表无限增长；保留第一个有效 URL 的顺序。
  static List<String> candidates(List<String> urls) {
    final result = <String>{};
    for (final value in urls.take(maxCandidateScan)) {
      final url = normalizeUrl(value);
      if (url != null) result.add(url);
      if (result.length == maxCandidates) break;
    }
    return result.toList(growable: false);
  }

  HuyaGiftImageLoad load(String imageUrl) {
    final load = HuyaGiftImageLoad();
    final url = normalizeUrl(imageUrl);
    if (url == null) {
      load._complete(null);
      return load;
    }
    final cached = _cache.remove(url);
    if (cached != null) {
      _cache[url] = cached;
      load._complete(cached);
      return load;
    }
    var job = _jobs[url];
    if (job == null) {
      if (_active >= maxConcurrentRequests &&
          _queue.length >= maxQueuedRequests) {
        load._complete(null);
        return load;
      }
      job = _GiftImageJob(url);
      _jobs[url] = job;
      _queue.add(job);
      final timedJob = job;
      job.timer = Timer(timeout, () => _finish(timedJob));
    }
    if (job.subscribers.length >= maxSubscribersPerRequest) {
      load._complete(null);
      return load;
    }
    final subscribedJob = job;
    job.subscribers.add(load);
    load._onCancel = () {
      subscribedJob.subscribers.remove(load);
      if (subscribedJob.subscribers.isEmpty) _finish(subscribedJob);
    };
    _drain();
    return load;
  }

  /// 解码失败时移除坏内容，不能让 HTTP 200 的损坏图片长期占据缓存。
  void evict(String imageUrl) {
    final bytes = _cache.remove(normalizeUrl(imageUrl));
    if (bytes != null) _cachedBytes -= bytes.length;
  }

  static void _drain() {
    while (_active < maxConcurrentRequests && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      job.started = true;
      _active++;
      unawaited(_download(job));
    }
  }

  static Future<void> _download(_GiftImageJob job) async {
    try {
      var uri = Uri.parse(job.url);
      for (var redirects = 0; redirects <= maxRedirects; redirects++) {
        // 每个请求独立 client：force close 不会伤及其它礼物的连接。
        final client = HttpClient()..connectionTimeout = maxTimeout;
        job.client = client;
        final request = await client.getUrl(uri);
        if (job.done) return;
        request.followRedirects = false;
        request.headers.set('Referer', 'https://www.huya.com/');
        request.headers.set(
          'User-Agent',
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Mobile Safari/537.36',
        );
        final response = await request.close();
        if (job.done) return;
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          final target = _redirectUrl(uri, location);
          // 不 drain 不可信的重定向响应体；每一跳同样验证 URL、共用原截止时间。
          client.close(force: true);
          job.client = null;
          if (target == null || redirects == maxRedirects) break;
          uri = Uri.parse(target);
          continue;
        }
        if (response.statusCode != HttpStatus.ok ||
            response.contentLength > maxImageBytes) {
          break;
        }
        await for (final chunk in response) {
          if (job.done) return;
          // HttpClient 解压后的数据也受限，不能只相信 Content-Length。
          if (job.buffer.length + chunk.length > maxImageBytes) {
            _finish(job);
            return;
          }
          job.buffer.add(chunk);
        }
        if (job.done) return;
        if (job.buffer.isNotEmpty) {
          _finish(job, job.buffer.takeBytes());
          return;
        }
        break;
      }
    } catch (_) {
      // 包含强制关闭触发的 SocketException/HttpException；统一结束且不重试。
    }
    _finish(job);
  }

  static String? _redirectUrl(Uri origin, String? location) {
    if (location == null || location.length > maxUrlLength) return null;
    final value = location.trim();
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    // 绝对/协议相对地址先验证原文，防止 resolve 消去空凭据后绕过校验。
    if (uri.hasScheme) return normalizeUrl(value);
    if (value.startsWith('//')) return normalizeUrl('${origin.scheme}:$value');
    return normalizeUrl(origin.resolveUri(uri).toString());
  }

  static void _finish(_GiftImageJob job, [Uint8List? bytes]) {
    if (job.done) return;
    job.done = true;
    job.timer?.cancel();
    // 必须先关闭实际 socket，再释放 slot；不能只丢弃 Future 的结果。
    job.client?.close(force: true);
    job.client = null;
    job.buffer.clear();
    _jobs.remove(job.url);
    _queue.remove(job);
    if (job.started) _active--;
    if (bytes != null) {
      _cache[job.url] = bytes;
      _cachedBytes += bytes.length;
      while (_cache.length > maxCacheEntries || _cachedBytes > maxCachedBytes) {
        _cachedBytes -= _cache.remove(_cache.keys.first)!.length;
      }
    }
    for (final subscriber in job.subscribers) {
      subscriber._complete(bytes);
    }
    job.subscribers.clear();
    _drain();
  }
}

class _GiftImageJob {
  _GiftImageJob(this.url);

  final String url;
  final subscribers = <HuyaGiftImageLoad>{};
  final buffer = BytesBuilder(copy: false);
  HttpClient? client;
  Timer? timer;
  bool started = false;
  bool done = false;
}
