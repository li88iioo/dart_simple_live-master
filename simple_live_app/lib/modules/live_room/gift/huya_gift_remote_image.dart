import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'huya_gift_image_loader.dart';

/// 固定占位、有限候选且可取消 IO 的虎牙礼物图片。
///
/// 注入 [imageProviderBuilder] 时直接沿用 provider，不启动本组件的网络加载。
/// 该测试/自定义路径的 IO 生命周期由 provider 自身负责。
class HuyaGiftRemoteImage extends StatefulWidget {
  const HuyaGiftRemoteImage({
    super.key,
    required this.imageUrls,
    required this.size,
    required this.fallback,
    this.imageProviderBuilder,
    this.loader,
  }) : assert(size > 0 && size < double.infinity);

  final List<String> imageUrls;
  final double size;
  final Widget fallback;
  final ImageProvider<Object> Function(String)? imageProviderBuilder;
  final HuyaGiftImageLoader? loader;

  @override
  State<HuyaGiftRemoteImage> createState() => _HuyaGiftRemoteImageState();
}

class _HuyaGiftRemoteImageState extends State<HuyaGiftRemoteImage> {
  List<String> _urls = const [];
  int _candidateIndex = 0;
  int _generation = 0;
  bool _advanceScheduled = false;
  HuyaGiftImageLoad? _load;
  Uint8List? _bytes;
  ImageProvider<Object>? _injectedProvider;
  ResizeImage? _remoteProvider;

  HuyaGiftImageLoader get _loader =>
      widget.loader ?? HuyaGiftImageLoader.shared;

  @override
  void initState() {
    super.initState();
    _reset(HuyaGiftImageLoader.candidates(widget.imageUrls));
  }

  @override
  void didUpdateWidget(covariant HuyaGiftRemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final urls = HuyaGiftImageLoader.candidates(widget.imageUrls);
    if (!listEquals(_urls, urls) ||
        oldWidget.imageProviderBuilder != widget.imageProviderBuilder ||
        oldWidget.loader != widget.loader) {
      _reset(urls);
    }
  }

  void _reset(List<String> urls) {
    _generation++;
    _advanceScheduled = false;
    _load?.cancel();
    _load = null;
    _urls = urls;
    _candidateIndex = 0;
    _startCandidate();
  }

  void _releaseImage() {
    final provider = _remoteProvider;
    _remoteProvider = null;
    _bytes = null;
    _injectedProvider = null;
    // 不让短命礼物的编码字节通过 Flutter 全局解码缓存额外长期驻留。
    // 注入的 provider 不属于本组件，不能擅自 evict。
    if (provider != null) unawaited(provider.evict());
  }

  void _startCandidate() {
    _releaseImage();
    final builder = widget.imageProviderBuilder;
    if (builder != null) {
      while (_candidateIndex < _urls.length) {
        try {
          _injectedProvider = builder(_urls[_candidateIndex]);
          return;
        } catch (_) {
          _candidateIndex++;
        }
      }
      return;
    }
    if (_candidateIndex >= _urls.length) return;
    final generation = _generation;
    final index = _candidateIndex;
    final load = _loader.load(_urls[index]);
    _load = load;
    unawaited(load.bytes.then((bytes) {
      if (!mounted || generation != _generation || index != _candidateIndex) {
        return;
      }
      _load = null;
      setState(() {
        if (bytes == null) {
          _candidateIndex++;
          _startCandidate();
        } else {
          _bytes = bytes;
        }
      });
    }));
  }

  void _tryNextCandidate(int generation, int index) {
    if (_advanceScheduled ||
        generation != _generation ||
        index != _candidateIndex) {
      return;
    }
    _advanceScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation || index != _candidateIndex) {
        return;
      }
      _advanceScheduled = false;
      if (widget.imageProviderBuilder == null) _loader.evict(_urls[index]);
      setState(() {
        _candidateIndex++;
        _startCandidate();
      });
    });
  }

  @override
  void dispose() {
    _generation++;
    _load?.cancel();
    _load = null;
    _releaseImage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider<Object>? provider = _injectedProvider;
    final bytes = _bytes;
    if (bytes != null) {
      final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
      final dimension =
          math.max(1, math.min(160, (widget.size * pixelRatio).round()));
      if (_remoteProvider?.width != dimension) {
        final oldProvider = _remoteProvider;
        _remoteProvider = ResizeImage(
          MemoryImage(bytes),
          width: dimension,
          height: dimension,
          policy: ResizeImagePolicy.fit,
        );
        if (oldProvider != null) unawaited(oldProvider.evict());
      }
      provider = _remoteProvider;
    }
    final generation = _generation;
    final index = _candidateIndex;
    return SizedBox.square(
      dimension: widget.size,
      child: provider == null
          ? widget.fallback
          : KeyedSubtree(
              // Image 会保留上个 stream 的错误直到新帧到来；不同候选必须
              // 隔离其 State，避免旧错误跳过正在解码的新候选。外层占位不变。
              key: ValueKey((generation, index)),
              child: Image(
                key: const ValueKey('huya-gift-remote-image'),
                image: provider,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                // GIF 等仍交给 Image SDK，遵守 TickerMode / disableAnimations。
                errorBuilder: (_, error, stackTrace) {
                  _tryNextCandidate(generation, index);
                  return widget.fallback;
                },
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return widget.fallback;
                },
              ),
            ),
    );
  }
}
