/// 在播放器真正打开媒体前应用用户选择的 URL 策略。
///
/// 只改写 URL 自身的 scheme，避免字符串替换误伤查询参数里包含的
/// `http://` 文本；无法解析的地址保持原样并交给播放器给出错误。
String applyPlaybackUrlPolicy(
  String url, {
  required bool forceHttps,
}) {
  if (!forceHttps) return url;

  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme.toLowerCase() != 'http') return url;
  return uri.replace(scheme: 'https').toString();
}
