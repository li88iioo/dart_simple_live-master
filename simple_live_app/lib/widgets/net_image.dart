import 'dart:math' as math;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

class NetImage extends StatelessWidget {
  const NetImage(
    this.picUrl, {
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.maxDecodeDensity = _maxDecodeDensity,
    super.key,
  });

  static const double _maxDecodeDensity = 3;
  static const int _decodeBucket = 64;
  static const int _maxDecodeExtent = 2048;

  final String picUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final double borderRadius;
  final double maxDecodeDensity;

  @override
  Widget build(BuildContext context) {
    final displayWidth = _finiteExtent(width);
    final displayHeight = _finiteExtent(height);
    final normalizedUrl = picUrl.startsWith('//') ? 'https:$picUrl' : picUrl;

    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalWidth = displayWidth ?? _boundedWidth(constraints);
        final logicalHeight = displayHeight ?? _boundedHeight(constraints);
        final density = MediaQuery.devicePixelRatioOf(context);
        final decodeOnWidth = logicalWidth != null &&
            (logicalHeight == null || logicalWidth >= logicalHeight);
        final cacheWidth = decodeOnWidth
            ? resolveNetImageCacheExtent(
                logicalWidth,
                density,
                maxDensity: maxDecodeDensity,
              )
            : null;
        final cacheHeight = !decodeOnWidth && logicalHeight != null
            ? resolveNetImageCacheExtent(
                logicalHeight,
                density,
                maxDensity: maxDecodeDensity,
              )
            : null;

        Widget image;
        if (normalizedUrl.isEmpty) {
          image = Image.asset(
            'assets/images/logo.png',
            width: displayWidth,
            height: displayHeight,
            fit: fit,
            filterQuality: FilterQuality.low,
          );
        } else {
          image = ExtendedImage.network(
            normalizedUrl,
            width: displayWidth,
            height: displayHeight,
            fit: fit,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            filterQuality: FilterQuality.low,
            clearMemoryCacheIfFailed: true,
            printError: false,
            loadStateChanged: (state) {
              return switch (state.extendedImageLoadState) {
                LoadState.loading => _NetImagePlaceholder(
                    icon: Icons.image_outlined,
                    width: displayWidth,
                    height: displayHeight,
                  ),
                LoadState.failed => _NetImagePlaceholder(
                    icon: Icons.broken_image_outlined,
                    width: displayWidth,
                    height: displayHeight,
                  ),
                LoadState.completed => null,
              };
            },
          );
        }

        if (borderRadius <= 0) return image;
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          clipBehavior: Clip.antiAlias,
          child: image,
        );
      },
    );
  }

  /// 在列表空闲阶段按与实际卡片一致的解码尺寸预热网络缩略图。
  ///
  /// 复用 extended_image 的磁盘缓存与 Flutter ImageCache；失败静默忽略，
  /// 不影响正常卡片自己的错误占位逻辑。
  static Future<void> warmUpNetworkImage(
    BuildContext context,
    String picUrl, {
    required double logicalWidth,
  }) async {
    final normalizedUrl = picUrl.startsWith('//') ? 'https:$picUrl' : picUrl;
    if (normalizedUrl.isEmpty || logicalWidth <= 0 || !context.mounted) return;

    final cacheWidth = resolveNetImageCacheExtent(
      logicalWidth,
      MediaQuery.devicePixelRatioOf(context),
    );
    final provider = ExtendedResizeImage.resizeIfNeeded(
      provider: ExtendedNetworkImageProvider(
        normalizedUrl,
        cache: true,
        printError: false,
      ),
      cacheWidth: cacheWidth,
    );
    try {
      await precacheImage(
        provider,
        context,
        onError: (_, __) {},
      );
    } catch (_) {
      // 网络失败由真实卡片加载状态接管，预热不向用户显示错误。
    }
  }

  static double? _finiteExtent(double? value) {
    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }

  static double? _boundedWidth(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || constraints.maxWidth <= 0) return null;
    return constraints.maxWidth;
  }

  static double? _boundedHeight(BoxConstraints constraints) {
    if (!constraints.hasBoundedHeight || constraints.maxHeight <= 0) {
      return null;
    }
    return constraints.maxHeight;
  }

  @visibleForTesting
  static int? resolveNetImageCacheExtent(
    double? logicalExtent,
    double devicePixelRatio, {
    double maxDensity = _maxDecodeDensity,
  }) {
    if (logicalExtent == null ||
        !logicalExtent.isFinite ||
        logicalExtent <= 0 ||
        !devicePixelRatio.isFinite ||
        devicePixelRatio <= 0 ||
        !maxDensity.isFinite ||
        maxDensity <= 0) {
      return null;
    }
    final densityLimit = maxDensity.clamp(1.0, _maxDecodeDensity);
    final density = devicePixelRatio.clamp(1.0, densityLimit);
    final requestedPixels = logicalExtent * density;
    final bucketed = (requestedPixels / _decodeBucket).ceil() * _decodeBucket;
    return math.min(bucketed, _maxDecodeExtent);
  }
}

class _NetImagePlaceholder extends StatelessWidget {
  const _NetImagePlaceholder({
    required this.icon,
    required this.width,
    required this.height,
  });

  final IconData icon;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.035),
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        ),
        child: Center(
          child: Icon(
            icon,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.46),
            size: 22,
          ),
        ),
      ),
    );
  }
}
