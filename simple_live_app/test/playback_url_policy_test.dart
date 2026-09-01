import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/utils/playback_url_policy.dart';

void main() {
  test('HTTPS 关闭时保持原播放地址', () {
    const url = 'http://cdn.example.com/live.flv?token=1';
    expect(applyPlaybackUrlPolicy(url, forceHttps: false), url);
  });

  test('HTTPS 开启时只改写播放地址 scheme', () {
    const url =
        'http://cdn.example.com/live.flv?callback=http://local.example/path';
    expect(
      applyPlaybackUrlPolicy(url, forceHttps: true),
      'https://cdn.example.com/live.flv?callback=http://local.example/path',
    );
  });

  test('HTTPS 与非 HTTP 地址不会被重复或错误改写', () {
    expect(
      applyPlaybackUrlPolicy(
        'https://cdn.example.com/live.flv',
        forceHttps: true,
      ),
      'https://cdn.example.com/live.flv',
    );
    expect(
      applyPlaybackUrlPolicy('not a url', forceHttps: true),
      'not a url',
    );
  });
}
