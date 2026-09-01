import 'dart:async';

const _invalidUrlTokens = <String>{'', 'null', 'undefined'};

Uri? parseHttpPlayUri(String? value, {bool requirePath = true}) {
  if (value == null) return null;
  final candidate = value.trim();
  if (candidate.isEmpty || RegExp(r'\s').hasMatch(candidate)) return null;

  final uri = Uri.tryParse(candidate);
  if (uri == null || !uri.hasAuthority) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (_invalidUrlTokens.contains(uri.host.toLowerCase())) return null;
  if (uri.userInfo.isNotEmpty || uri.hasFragment) return null;
  if (requirePath) {
    if (uri.path.isEmpty || uri.path == '/') return null;
    if (uri.pathSegments.any(
      (segment) => _invalidUrlTokens.contains(segment.toLowerCase()),
    )) {
      return null;
    }
  }
  return uri;
}

String? normalizeHttpPlayUrl(String? value) {
  return parseHttpPlayUri(value)?.toString();
}

/// 以有限并发执行播放线路解析。单条线路失败或返回非法 URL 时会被隔离，
/// 成功结果仍按原线路顺序返回。
Future<List<String>> resolvePlayUrls(
  Iterable<Future<String> Function()> resolvers, {
  int maxConcurrent = 3,
  void Function(int index, Object error, StackTrace stackTrace)? onError,
}) async {
  if (maxConcurrent <= 0) {
    throw ArgumentError.value(maxConcurrent, 'maxConcurrent', '必须大于 0');
  }

  final tasks = resolvers.toList(growable: false);
  if (tasks.isEmpty) return const <String>[];

  final results = List<String?>.filled(tasks.length, null);
  var nextIndex = 0;

  Future<void> worker() async {
    while (true) {
      final index = nextIndex;
      if (index >= tasks.length) return;
      nextIndex++;

      try {
        final candidate = await tasks[index]();
        final normalized = normalizeHttpPlayUrl(candidate);
        if (normalized == null) {
          throw FormatException('播放地址非法: $candidate');
        }
        results[index] = normalized;
      } catch (error, stackTrace) {
        onError?.call(index, error, stackTrace);
      }
    }
  }

  final workerCount =
      maxConcurrent < tasks.length ? maxConcurrent : tasks.length;
  await Future.wait(List.generate(workerCount, (_) => worker()));
  return results.whereType<String>().toList(growable: false);
}
