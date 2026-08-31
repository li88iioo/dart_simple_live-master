import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/widgets/net_image.dart';

void main() {
  test('图片解码尺寸按像素密度放大并量化到固定桶', () {
    expect(NetImage.resolveNetImageCacheExtent(50, 3), 192);
    expect(NetImage.resolveNetImageCacheExtent(180, 2), 384);
  });

  test('图片解码尺寸限制最高密度和最大边长', () {
    expect(NetImage.resolveNetImageCacheExtent(100, 6), 320);
    expect(NetImage.resolveNetImageCacheExtent(2000, 4), 2048);
  });

  test('直播封面可以单独降低解码密度而不影响全局上限', () {
    expect(
      NetImage.resolveNetImageCacheExtent(100, 3.2, maxDensity: 2.5),
      256,
    );
  });

  test('图片解码尺寸拒绝无效或无界输入', () {
    expect(NetImage.resolveNetImageCacheExtent(null, 2), isNull);
    expect(NetImage.resolveNetImageCacheExtent(double.infinity, 2), isNull);
    expect(NetImage.resolveNetImageCacheExtent(100, 0), isNull);
  });
}
