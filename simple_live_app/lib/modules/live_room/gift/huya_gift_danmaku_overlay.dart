import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_event.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';

enum HuyaGiftOverlayPlacement {
  player,
  chat,
}

typedef HuyaGiftImageProviderBuilder = ImageProvider<Object> Function(
  String url,
);

const double huyaChatGiftMaxWidth = 252;
const double huyaChatGiftHeight = 64;
const double huyaPlayerGiftAbsoluteMaxWidth = 340;
const double huyaPlayerGiftViewportFraction = 0.28;

/// 播放器礼物卡始终限制在安全边缘的一小块区域内，避免覆盖画面主体。
double resolveHuyaGiftPlayerMaxWidth(double viewportWidth) {
  return math.max(
    1.0,
    math.min(
      huyaPlayerGiftAbsoluteMaxWidth,
      viewportWidth * huyaPlayerGiftViewportFraction,
    ),
  );
}

/// 聊天礼物固定在右上角，播放器礼物固定在左下安全边缘。
Alignment resolveHuyaGiftOverlayAlignment(HuyaGiftOverlayPlacement placement) {
  return placement == HuyaGiftOverlayPlacement.chat
      ? Alignment.topRight
      : Alignment.bottomLeft;
}

/// 礼物 UI 只选择一个远程资源。目录图标优先，效果图仅作无图标时的回退。
String? selectHuyaGiftPresentationImageUrl(HuyaGiftDanmakuEvent event) {
  return _safeGiftImageUrl(event.giftImageUrl) ??
      _safeGiftImageUrl(event.giftEffectImageUrl);
}

class HuyaGiftDanmakuOverlay extends StatelessWidget {
  const HuyaGiftDanmakuOverlay({
    super.key,
    required this.controller,
    this.placement = HuyaGiftOverlayPlacement.player,
  });

  final LiveRoomController controller;
  final HuyaGiftOverlayPlacement placement;

  bool get _isChat => placement == HuyaGiftOverlayPlacement.chat;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final cardMaxWidth = _isChat
                ? math.min(huyaChatGiftMaxWidth, viewportWidth)
                : resolveHuyaGiftPlayerMaxWidth(viewportWidth);
            final padding = _isChat
                ? const EdgeInsets.fromLTRB(10, 52, 10, 10)
                : EdgeInsets.fromLTRB(
                    viewportWidth < 720 ? 12 : 18,
                    12,
                    12,
                    viewportWidth < 720 ? 56 : 72,
                  );

            Widget overlay = Padding(
              padding: padding,
              child: Align(
                alignment: resolveHuyaGiftOverlayAlignment(placement),
                child: Obx(() {
                  final enabled = AppSettingsController
                          .instance.huyaGiftDanmakuEnable.value &&
                      controller.liveStatus.value &&
                      !controller.isBackground;
                  final event =
                      enabled ? controller.activeHuyaGiftEffect.value : null;

                  return AnimatedSwitcher(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    reverseDuration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 140),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      if (reduceMotion) return child;
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      );
                      final slide = Tween<Offset>(
                        begin: _isChat
                            ? const Offset(0.028, -0.012)
                            : const Offset(-0.024, 0.018),
                        end: Offset.zero,
                      ).animate(curved);
                      return FadeTransition(
                        opacity: curved,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment:
                            _isChat ? Alignment.topRight : Alignment.bottomLeft,
                        clipBehavior: Clip.none,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: event == null
                        ? const SizedBox.shrink(
                            key: ValueKey('empty-huya-gift'),
                          )
                        : HuyaGiftPresentation(
                            key: ValueKey(event.id),
                            event: event,
                            placement: placement,
                            maxWidth: cardMaxWidth,
                            reduceMotion: reduceMotion,
                          ),
                  );
                }),
              ),
            );

            if (!_isChat) {
              overlay = SafeArea(child: overlay);
            }
            return overlay;
          },
        ),
      ),
    );
  }
}

/// 低干扰虎牙礼物通知。该组件只负责一张边缘卡，不创建中央舞台。
class HuyaGiftPresentation extends StatelessWidget {
  const HuyaGiftPresentation({
    super.key,
    required this.event,
    required this.placement,
    required this.maxWidth,
    required this.reduceMotion,
    this.imageProviderBuilder,
  });

  final HuyaGiftDanmakuEvent event;
  final HuyaGiftOverlayPlacement placement;
  final double maxWidth;
  final bool reduceMotion;
  final HuyaGiftImageProviderBuilder? imageProviderBuilder;

  bool get _isChat => placement == HuyaGiftOverlayPlacement.chat;

  @override
  Widget build(BuildContext context) {
    final highlight = event.isHighlight;
    final preferredWidth = _isChat
        ? huyaChatGiftMaxWidth
        : highlight
            ? 320.0
            : 286.0;
    final width = math.max(1.0, math.min(maxWidth, preferredWidth));
    final height = _isChat
        ? huyaChatGiftHeight
        : highlight
            ? 68.0
            : 62.0;

    return Semantics(
      liveRegion: true,
      label: event.semanticsLabel,
      child: SizedBox(
        key: ValueKey(
          _isChat ? 'huya-chat-gift-card' : 'huya-player-edge-gift-card',
        ),
        width: width,
        height: height,
        child: _GiftEdgeCard(
          event: event,
          placement: placement,
          width: width,
          height: height,
          reduceMotion: reduceMotion,
          imageProviderBuilder: imageProviderBuilder,
        ),
      ),
    );
  }
}

class _GiftEdgeCard extends StatelessWidget {
  const _GiftEdgeCard({
    required this.event,
    required this.placement,
    required this.width,
    required this.height,
    required this.reduceMotion,
    required this.imageProviderBuilder,
  });

  final HuyaGiftDanmakuEvent event;
  final HuyaGiftOverlayPlacement placement;
  final double width;
  final double height;
  final bool reduceMotion;
  final HuyaGiftImageProviderBuilder? imageProviderBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = event.isHighlight;
    final accent = highlight ? const Color(0xFFFFA54B) : colors.huya;
    final showArtwork = width >= 150;
    final showSender = width >= 184;
    final artworkSize =
        placement == HuyaGiftOverlayPlacement.chat ? 48.0 : 46.0;
    final horizontalPadding = width < 190 ? 7.0 : 9.0;
    final imageUrl = selectHuyaGiftPresentationImageUrl(event);
    final fill = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.075 : 0.035),
      colors.glassStrong.withValues(alpha: isDark ? 0.92 : 0.91),
    );
    final borderColor = colors.glassBorder.withValues(
      alpha: isDark ? 0.18 : 0.58,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: isDark ? 0.025 : 0.15),
                      fill,
                    ),
                    fill,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Stack(
                children: [
                  if (highlight)
                    Positioned(
                      left: 0,
                      top: 13,
                      bottom: 13,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.78),
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(3),
                          ),
                        ),
                        child: const SizedBox(width: 3),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 7,
                    ),
                    child: Row(
                      children: [
                        if (showArtwork) ...[
                          _GiftArtwork(
                            imageUrl: imageUrl,
                            size: artworkSize,
                            accent: accent,
                            imageProviderBuilder: imageProviderBuilder,
                          ),
                          SizedBox(width: width < 210 ? 7 : 9),
                        ],
                        Expanded(
                          child: _GiftCopy(
                            event: event,
                            showSender: showSender,
                            dense: width < 220,
                          ),
                        ),
                        SizedBox(width: width < 190 ? 5 : 8),
                        _GiftCountBadge(
                          count: event.count,
                          accent: accent,
                          highlight: highlight,
                          dense: width < 210,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (highlight && placement == HuyaGiftOverlayPlacement.player)
          Positioned(
            key: const ValueKey('huya-highlight-micro-particles'),
            right: 48,
            top: -4,
            child: _GiftMicroParticles(
              accent: accent,
              reduceMotion: reduceMotion,
            ),
          ),
      ],
    );
  }
}

class _GiftCopy extends StatelessWidget {
  const _GiftCopy({
    required this.event,
    required this.showSender,
    required this.dense,
  });

  final HuyaGiftDanmakuEvent event;
  final bool showSender;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          event.giftName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: dense ? 12 : 13.5,
            height: 1.05,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (showSender) ...[
          const SizedBox(height: 4),
          Text(
            event.sender,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: dense ? 9.5 : 10.5,
              height: 1.05,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _GiftCountBadge extends StatelessWidget {
  const _GiftCountBadge({
    required this.count,
    required this.accent,
    required this.highlight,
    required this.dense,
  });

  final int count;
  final Color accent;
  final bool highlight;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: dense ? 34 : 40,
        maxWidth: dense ? 44 : 56,
      ),
      height: dense ? 27 : 30,
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: highlight ? 0.18 : 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '×$count',
          maxLines: 1,
          style: TextStyle(
            color: Color.lerp(accent, context.sliveColors.textPrimary, 0.14),
            fontSize: dense ? 12 : 13.5,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _GiftArtwork extends StatelessWidget {
  const _GiftArtwork({
    required this.imageUrl,
    required this.size,
    required this.accent,
    required this.imageProviderBuilder,
  });

  final String? imageUrl;
  final double size;
  final Color accent;
  final HuyaGiftImageProviderBuilder? imageProviderBuilder;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Icon(
        Icons.card_giftcard_rounded,
        size: size * 0.48,
        color: accent.withValues(alpha: 0.86),
      ),
    );

    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: imageUrl == null
              ? fallback
              : _GiftRemoteImage(
                  imageUrl: imageUrl!,
                  size: size,
                  fallback: fallback,
                  imageProviderBuilder: imageProviderBuilder,
                ),
        ),
      ),
    );
  }
}

class _GiftRemoteImage extends StatelessWidget {
  const _GiftRemoteImage({
    required this.imageUrl,
    required this.size,
    required this.fallback,
    required this.imageProviderBuilder,
  });

  final String imageUrl;
  final double size;
  final Widget fallback;
  final HuyaGiftImageProviderBuilder? imageProviderBuilder;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = _normalizeGiftImageUrl(imageUrl);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheDimension = math.max(
      1,
      math.min(192, (size * pixelRatio).round()),
    );
    final imageProvider = imageProviderBuilder?.call(normalizedUrl) ??
        ResizeImage.resizeIfNeeded(
          cacheDimension,
          cacheDimension,
          NetworkImage(normalizedUrl),
        );

    return Image(
      key: const ValueKey('huya-gift-remote-image'),
      image: imageProvider,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, error, stackTrace) => fallback,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return fallback;
      },
    );
  }
}

class _GiftMicroParticles extends StatelessWidget {
  const _GiftMicroParticles({
    required this.accent,
    required this.reduceMotion,
  });

  final Color accent;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        return Opacity(
          opacity: reduceMotion ? 0.72 : progress,
          child: Transform.translate(
            offset: reduceMotion ? Offset.zero : Offset(0, 4 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: 34,
        height: 24,
        child: Stack(
          children: [
            Positioned(
              left: 1,
              bottom: 2,
              child: _ParticleDot(color: accent, size: 5),
            ),
            Positioned(
              left: 12,
              top: 1,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 10,
                color: accent.withValues(alpha: 0.78),
              ),
            ),
            Positioned(
              right: 1,
              bottom: 5,
              child: _ParticleDot(
                color: const Color(0xFFFFCF87),
                size: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticleDot extends StatelessWidget {
  const _ParticleDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(2),
      ),
      child: SizedBox.square(dimension: size),
    );
  }
}

String? _safeGiftImageUrl(String? imageUrl) {
  return isSafeHuyaGiftImageUrl(imageUrl) ? imageUrl?.trim() : null;
}

String _normalizeGiftImageUrl(String imageUrl) {
  final trimmed = imageUrl.trim();
  return trimmed.startsWith('//') ? 'https:$trimmed' : trimmed;
}
