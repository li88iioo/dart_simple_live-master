import 'dart:async';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/play_url_resolver.dart';
import 'package:test/test.dart';

class _FakeHuyaSite extends HuyaSite {
  @override
  Future<String> getPlayUrl(HuyaLineModel line, int bitRate) async {
    switch (line.streamName) {
      case 'throws':
        throw StateError('线路失败');
      case 'invalid':
        return 'https://null/null';
      default:
        return 'https://cdn.example.com/live/${line.streamName}.flv?rate=$bitRate';
    }
  }
}

class _HuyaUrlBuilderSite extends HuyaSite {
  @override
  Future<String> getCndTokenInfoEx(String stream) async => 'source-token';

  @override
  String buildAntiCode(String stream, int presenterUid, String antiCode) =>
      'wsSecret=abc123&wsTime=654321';
}

class _FakeDouyuSite extends DouyuSite {
  @override
  Future<String> getPlayUrl(String roomId, int rate, String cdn) async {
    switch (cdn) {
      case 'throws':
        throw StateError('线路失败');
      case 'invalid':
        return 'javascript:alert(1)';
      default:
        return 'https://$cdn.example.com/live/$roomId.flv?rate=$rate';
    }
  }
}

LiveRoomDetail _detail({dynamic data}) {
  return LiveRoomDetail(
    roomId: '100',
    title: '测试房间',
    cover: 'https://example.com/cover.jpg',
    userName: '主播',
    userAvatar: 'https://example.com/avatar.jpg',
    online: 1,
    status: true,
    data: data,
    url: 'https://example.com/100',
  );
}

HuyaLineModel _huyaLine(String name) {
  return HuyaLineModel(
    line: 'https://cdn.example.com/live',
    lineType: HuyaLineType.flv,
    flvAntiCode: '',
    hlsAntiCode: '',
    streamName: name,
    cdnType: name,
    presenterUid: 1,
  );
}

void main() {
  final originalLogState = CoreLog.enableLog;

  setUpAll(() {
    CoreLog.enableLog = false;
  });

  tearDownAll(() {
    CoreLog.enableLog = originalLogState;
  });

  test('严格拒绝非 HTTP、占位值、凭据、fragment 与空路径 URL', () {
    expect(normalizeHttpPlayUrl('ftp://cdn.example.com/live.flv'), isNull);
    expect(normalizeHttpPlayUrl('https://null/null'), isNull);
    expect(
        normalizeHttpPlayUrl('https://u:p@cdn.example.com/live.flv'), isNull);
    expect(normalizeHttpPlayUrl('https://cdn.example.com/'), isNull);
    expect(
        normalizeHttpPlayUrl('https://cdn.example.com/live.flv#part'), isNull);
    expect(
        normalizeHttpPlayUrl('https://cdn.example.com/live file.flv'), isNull);
    expect(
      normalizeHttpPlayUrl('https://cdn.example.com/live.flv?token=1'),
      'https://cdn.example.com/live.flv?token=1',
    );
  });

  test('虎牙播放地址构造不会附加空 fragment 导致整条线路被拒绝', () async {
    final site = _HuyaUrlBuilderSite();
    final url = await site.getPlayUrl(
      HuyaLineModel(
        line: 'http://al.flv.huya.com/src',
        lineType: HuyaLineType.flv,
        flvAntiCode: '',
        hlsAntiCode: '',
        streamName: 'room-stream',
        cdnType: 'AL',
        presenterUid: 100,
      ),
      2000,
    );

    expect(url, isNotEmpty);
    expect(url, isNot(endsWith('#')));
    expect(Uri.parse(url).hasFragment, isFalse);
    expect(url, contains('/src/room-stream.flv?'));
    expect(url, contains('wsSecret=abc123'));
    expect(url, contains('&codec=264&ratio=2000'));
  });

  test('线路解析限制并发、隔离失败并保持成功结果原顺序', () async {
    var active = 0;
    var maxActive = 0;

    Future<String> run(
      String result,
      Duration delay, {
      bool throws = false,
    }) async {
      active++;
      if (active > maxActive) maxActive = active;
      try {
        await Future<void>.delayed(delay);
        if (throws) throw StateError('失败');
        return result;
      } finally {
        active--;
      }
    }

    final errors = <int>[];
    final urls = await resolvePlayUrls(
      [
        () => run(
              'https://a.example.com/live.flv',
              const Duration(milliseconds: 25),
            ),
        () => run(
              '',
              const Duration(milliseconds: 5),
              throws: true,
            ),
        () => run(
              'https://null/null',
              const Duration(milliseconds: 5),
            ),
        () => run(
              'https://d.example.com/live.flv',
              const Duration(milliseconds: 5),
            ),
      ],
      maxConcurrent: 2,
      onError: (index, _, __) => errors.add(index),
    );

    expect(maxActive, lessThanOrEqualTo(2));
    expect(errors, containsAll([1, 2]));
    expect(urls, [
      'https://a.example.com/live.flv',
      'https://d.example.com/live.flv',
    ]);
  });

  test('虎牙单线路失败或 URL 非法不会拖垮其他线路', () async {
    final lines = [
      _huyaLine('line-a'),
      _huyaLine('throws'),
      _huyaLine('invalid'),
      _huyaLine('line-d'),
    ];
    final quality = LivePlayQuality(
      quality: '原画',
      data: {'urls': lines, 'bitRate': 2000},
    );

    final result = await _FakeHuyaSite().getPlayUrls(
      detail: _detail(),
      quality: quality,
    );

    expect(result.urls, [
      'https://cdn.example.com/live/line-a.flv?rate=2000',
      'https://cdn.example.com/live/line-d.flv?rate=2000',
    ]);
  });

  test('斗鱼单线路失败或 URL 非法不会拖垮其他线路', () async {
    final quality = LivePlayQuality(
      quality: '原画',
      data: DouyuPlayData(0, ['cdn-a', 'throws', 'invalid', 'cdn-d']),
    );

    final result = await _FakeDouyuSite().getPlayUrls(
      detail: _detail(),
      quality: quality,
    );

    expect(result.urls, [
      'https://cdn-a.example.com/live/100.flv?rate=0',
      'https://cdn-d.example.com/live/100.flv?rate=0',
    ]);
  });
}
