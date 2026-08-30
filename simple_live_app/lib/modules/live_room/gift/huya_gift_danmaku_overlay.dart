import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_event.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';

enum HuyaGiftOverlayPlacement {
  player,
  chat,
}

class HuyaGiftDanmakuOverlay extends StatelessWidget {
  const HuyaGiftDanmakuOverlay({
    super.key,
    required this.controller,
    this.placement = HuyaGiftOverlayPlacement.player,
  });

  final LiveRoomController controller;
  final HuyaGiftOverlayPlacement placement;

  bool get _isCompact => placement == HuyaGiftOverlayPlacement.chat;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final alignment = _isCompact ? Alignment.topRight : Alignment.center;
    final padding = _isCompact
        ? const EdgeInsets.fromLTRB(12, 54, 8, 12)
        : const EdgeInsets.symmetric(horizontal: 18, vertical: 12);

    Widget content = Padding(
      padding: padding,
      child: Align(
        alignment: alignment,
        child: Obx(() {
          final enabled =
              AppSettingsController.instance.huyaGiftDanmakuEnable.value &&
                  controller.liveStatus.value &&
                  !controller.isBackground;
          final event = enabled ? controller.activeHuyaGiftEffect.value : null;

          return AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 260),
            reverseDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 170),
            switchInCurve: SliveMotion.standard,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: _isCompact
                    ? const Offset(0.07, -0.04)
                    : const Offset(0, 0.055),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: SliveMotion.standard,
                ),
              );
              final scale = Tween<double>(
                begin: _isCompact ? 0.975 : 0.92,
                end: 1,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: SliveMotion.standard,
                ),
              );
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: slide,
                  child: ScaleTransition(scale: scale, child: child),
                ),
              );
            },
            child: event == null
                ? const SizedBox.shrink(key: ValueKey('empty-gift-effect'))
                : _GiftVisualCard(
                    key: ValueKey(event.id),
                    event: event,
                    compact: _isCompact,
                    reduceMotion: reduceMotion,
                  ),
          );
        }),
      ),
    );

    if (!_isCompact) {
      content = SafeArea(child: content);
    }

    return Positioned.fill(
      child: IgnorePointer(child: content),
    );
  }
}

class _GiftVisualCard extends StatefulWidget {
  const _GiftVisualCard({
    super.key,
    required this.event,
    required this.compact,
    required this.reduceMotion,
  });

  final HuyaGiftDanmakuEvent event;
  final bool compact;
  final bool reduceMotion;

  @override
  State<_GiftVisualCard> createState() => _GiftVisualCardState();
}

class _GiftVisualCardState extends State<_GiftVisualCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.compact
            ? 1500
            : widget.event.isHighlight
                ? 2100
                : 1800,
      ),
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _motionController.stop();
    } else if (!_motionController.isAnimating &&
        !_motionController.isCompleted) {
      _motionController.forward();
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final highlight = widget.event.isHighlight;
    final accent = highlight ? const Color(0xFFFFA94D) : colors.huya;
    final secondary =
        highlight ? const Color(0xFFFF6F91) : const Color(0xFFFFD08A);

    return Semantics(
      liveRegion: true,
      label: widget.event.semanticsLabel,
      child: RepaintBoundary(
        child: widget.compact
            ? _ChatGiftCard(
                event: widget.event,
                animation: _motionController,
                reduceMotion: widget.reduceMotion,
                accent: accent,
                secondary: secondary,
              )
            : highlight
                ? _PlayerGiftStage(
                    event: widget.event,
                    animation: _motionController,
                    reduceMotion: widget.reduceMotion,
                    accent: accent,
                    secondary: secondary,
                  )
                : _PlayerGiftToast(
                    event: widget.event,
                    animation: _motionController,
                    reduceMotion: widget.reduceMotion,
                    accent: accent,
                    secondary: secondary,
                  ),
      ),
    );
  }
}

class _ChatGiftCard extends StatelessWidget {
  const _ChatGiftCard({
    required this.event,
    required this.animation,
    required this.reduceMotion,
    required this.accent,
    required this.secondary,
  });

  final HuyaGiftDanmakuEvent event;
  final Animation<double> animation;
  final bool reduceMotion;
  final Color accent;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.sliveColors;
    final surfaceColor = Color.lerp(
      colors.glassStrong,
      accent,
      isDark ? 0.12 : 0.055,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 292),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -17,
            top: -23,
            child: _ChatGiftAura(
              animation: animation,
              reduceMotion: reduceMotion,
              size: 112,
              accent: accent,
              secondary: secondary,
            ),
          ),
          SliveGlassSurface(
            variant: SliveGlassVariant.overlay,
            radius: 20,
            enableBackdropBlur: false,
            showShadow: false,
            shadowColor: Colors.transparent,
            color: surfaceColor,
            borderColor: accent.withValues(alpha: isDark ? 0.28 : 0.22),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: isDark ? 0.22 : 0.14),
                          secondary.withValues(
                            alpha: isDark ? 0.10 : 0.055,
                          ),
                          colors.glassStrong.withValues(
                            alpha: isDark ? 0.04 : 0.16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!reduceMotion)
                  Positioned.fill(
                    child: ClipRect(
                      child: AnimatedBuilder(
                        animation: animation,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.rotate(
                            angle: -math.pi / 11,
                            child: Container(
                              width: 38,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.28),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        builder: (context, child) {
                          final progress = SliveMotion.standard.transform(
                            animation.value,
                          );
                          return FractionalTranslation(
                            translation: Offset(-1.25 + progress * 2.6, 0),
                            child: child,
                          );
                        },
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 6, 12, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GiftArtwork(
                        event: event,
                        size: 58,
                        accent: accent,
                        secondary: secondary,
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.giftName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              event.sender,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 10.5,
                                height: 1.15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatGiftAura extends StatelessWidget {
  const _ChatGiftAura({
    required this.animation,
    required this.reduceMotion,
    required this.size,
    required this.accent,
    required this.secondary,
  });

  final Animation<double> animation;
  final bool reduceMotion;
  final double size;
  final Color accent;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final rawProgress = reduceMotion ? 0.58 : animation.value;
          final progress = Curves.easeOutCubic.transform(rawProgress);
          final fade = reduceMotion
              ? 0.34
              : rawProgress < 0.66
                  ? 1.0
                  : (1 - (rawProgress - 0.66) / 0.34)
                      .clamp(0.0, 1.0)
                      .toDouble();
          return Opacity(
            opacity: fade,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: 0.55 + progress * 0.58,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.48),
                        width: 1.25,
                      ),
                    ),
                    child: SizedBox.square(dimension: size * 0.68),
                  ),
                ),
                Transform.scale(
                  scale: 0.42 + progress * 0.44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: secondary.withValues(alpha: 0.30),
                        width: 1,
                      ),
                    ),
                    child: SizedBox.square(dimension: size * 0.54),
                  ),
                ),
                Transform.rotate(
                  angle: progress * math.pi / 9,
                  child: _GiftSparkles(
                    progress: progress,
                    size: size,
                    accent: accent,
                    secondary: secondary,
                    dense: false,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlayerGiftToast extends StatelessWidget {
  const _PlayerGiftToast({
    required this.event,
    required this.animation,
    required this.reduceMotion,
    required this.accent,
    required this.secondary,
  });

  final HuyaGiftDanmakuEvent event;
  final Animation<double> animation;
  final bool reduceMotion;
  final Color accent;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.sliveColors;
    final giftImageUrl = _safeGiftImageUrl(event.giftImageUrl);
    final effectImageUrl = _safeGiftImageUrl(event.giftEffectImageUrl);
    final primaryImageUrl = giftImageUrl ?? effectImageUrl;
    final fill = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.12 : 0.07),
      colors.glassStrong.withValues(alpha: isDark ? 0.90 : 0.86),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaSize.width;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mediaSize.height;
        final viewportWidth = math.max(1.0, availableWidth);
        final viewportHeight = math.max(1.0, availableHeight);
        final width = math.max(1.0, math.min(420.0, viewportWidth));
        final capsuleHeight = math.max(
          1.0,
          math.min(76.0, math.max(1.0, viewportHeight - 8)),
        );
        final dense = width < 330 || capsuleHeight < 68;
        final artworkSize = math.max(
          1.0,
          math.min(
            dense ? 50.0 : 58.0,
            math.max(1.0, capsuleHeight - 10),
          ),
        );
        final minimumCenterY = capsuleHeight / 2;
        final maximumCenterY = math.max(
          minimumCenterY,
          viewportHeight - capsuleHeight / 2 - 8,
        );
        final centerY = (viewportHeight * 0.72)
            .clamp(minimumCenterY, maximumCenterY)
            .toDouble();
        final alignmentY =
            ((centerY / viewportHeight) * 2 - 1).clamp(-1.0, 1.0).toDouble();

        return SizedBox(
          width: viewportWidth,
          height: viewportHeight,
          child: Align(
            alignment: Alignment(0, alignmentY),
            child: AnimatedBuilder(
              animation: animation,
              child: SizedBox(
                width: width,
                height: capsuleHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: dense ? -8 : -10,
                      top: (capsuleHeight - (dense ? 72 : 82)) / 2,
                      child: _ChatGiftAura(
                        animation: animation,
                        reduceMotion: reduceMotion,
                        size: dense ? 72 : 82,
                        accent: accent,
                        secondary: secondary,
                      ),
                    ),
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(SliveRadii.pill),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.alphaBlend(
                                  accent.withValues(
                                    alpha: isDark ? 0.12 : 0.07,
                                  ),
                                  fill,
                                ),
                                fill,
                                Color.alphaBlend(
                                  secondary.withValues(
                                    alpha: isDark ? 0.055 : 0.028,
                                  ),
                                  fill,
                                ),
                              ],
                            ),
                            borderRadius:
                                BorderRadius.circular(SliveRadii.pill),
                            border: Border.all(
                              color: accent.withValues(
                                alpha: isDark ? 0.30 : 0.22,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              dense ? 8 : 9,
                              5,
                              dense ? 8 : 10,
                              5,
                            ),
                            child: Row(
                              children: [
                                _PlayerGiftArtwork(
                                  imageUrl: primaryImageUrl,
                                  size: artworkSize,
                                  accent: accent,
                                  secondary: secondary,
                                  highlight: false,
                                  maxDecodeDimension: 256,
                                ),
                                SizedBox(width: dense ? 9 : 11),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.giftName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: dense ? 12.5 : 14,
                                          height: 1.05,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${event.sender} 送出',
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
                                  ),
                                ),
                                SizedBox(width: dense ? 7 : 10),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: accent.withValues(
                                      alpha: isDark ? 0.20 : 0.12,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(SliveRadii.pill),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.34),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: dense ? 9 : 11,
                                      vertical: dense ? 6 : 7,
                                    ),
                                    child: Text(
                                      '×${event.count}',
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: dense ? 13 : 15,
                                        height: 1,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              builder: (context, child) {
                final progress = _stageProgress(
                  animation: animation,
                  reduceMotion: reduceMotion,
                );
                final reveal = SliveMotion.standard.transform(
                  (progress / 0.42).clamp(0.0, 1.0).toDouble(),
                );
                return Opacity(
                  opacity: reveal,
                  child: Transform.translate(
                    offset: Offset(14 * (1 - reveal), 8 * (1 - reveal)),
                    child: Transform.scale(
                      scale: 0.97 + 0.03 * reveal,
                      child: child,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _PlayerGiftStage extends StatelessWidget {
  const _PlayerGiftStage({
    required this.event,
    required this.animation,
    required this.reduceMotion,
    required this.accent,
    required this.secondary,
  });

  final HuyaGiftDanmakuEvent event;
  final Animation<double> animation;
  final bool reduceMotion;
  final Color accent;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = event.isHighlight;
    final iconUrl = _safeGiftImageUrl(event.giftImageUrl);
    final effectUrl = _safeGiftImageUrl(event.giftEffectImageUrl);
    final primaryImageUrl = effectUrl ?? iconUrl;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaSize.width;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mediaSize.height;
        final width = math.max(
          1.0,
          math.min(highlight ? 520.0 : 460.0, availableWidth),
        );
        final height = math.max(
          1.0,
          math.min(highlight ? 252.0 : 216.0, availableHeight),
        );
        final dense = width < 340 || height < 190;
        final preferredArtworkSize = highlight ? 132.0 : 108.0;
        final artworkSize = math.min(
          preferredArtworkSize,
          math.min(width * 0.34, height * (dense ? 0.48 : 0.53)),
        );
        final captionWidth = math.max(
          1.0,
          math.min(width - 20, highlight ? 390.0 : 340.0),
        );

        return SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(highlight ? 34 : 30),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.18),
                        radius: 0.92,
                        colors: [
                          accent.withValues(
                            alpha: isDark
                                ? highlight
                                    ? 0.24
                                    : 0.18
                                : highlight
                                    ? 0.20
                                    : 0.14,
                          ),
                          secondary.withValues(
                            alpha: highlight ? 0.085 : 0.045,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.54, 1],
                      ),
                      borderRadius: BorderRadius.circular(highlight ? 34 : 30),
                      border: Border.all(
                        color: accent.withValues(
                          alpha: highlight ? 0.24 : 0.14,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: animation,
                    child: CustomPaint(
                      painter: _GiftStageAtmospherePainter(
                        accent: accent,
                        secondary: secondary,
                        highlight: highlight,
                      ),
                    ),
                    builder: (context, child) {
                      final progress = _stageProgress(
                        animation: animation,
                        reduceMotion: reduceMotion,
                      );
                      final reveal = Curves.easeOutCubic.transform(
                        (progress / 0.56).clamp(0.0, 1.0).toDouble(),
                      );
                      return Opacity(
                        opacity: 0.35 + 0.65 * reveal,
                        child: Transform.rotate(
                          angle: reduceMotion ? 0 : (1 - reveal) * -0.05,
                          child: Transform.scale(
                            scale: 0.90 + 0.10 * reveal,
                            child: child,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final progress = _stageProgress(
                        animation: animation,
                        reduceMotion: reduceMotion,
                      );
                      return _GiftStageParticles(
                        progress: progress,
                        highlight: highlight,
                        accent: accent,
                        secondary: secondary,
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment(0, dense ? -0.24 : -0.30),
                  child: AnimatedBuilder(
                    animation: animation,
                    child: _PlayerGiftArtwork(
                      imageUrl: primaryImageUrl,
                      size: artworkSize,
                      accent: accent,
                      secondary: secondary,
                      highlight: highlight,
                      maxDecodeDimension: 448,
                    ),
                    builder: (context, child) {
                      final progress = _stageProgress(
                        animation: animation,
                        reduceMotion: reduceMotion,
                      );
                      final reveal = SliveMotion.standard.transform(
                        (progress / 0.46).clamp(0.0, 1.0).toDouble(),
                      );
                      return Opacity(
                        opacity: reveal,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - reveal)),
                          child: Transform.rotate(
                            angle: reduceMotion ? 0 : (1 - reveal) * -0.055,
                            child: Transform.scale(
                              scale: 0.72 + 0.28 * reveal,
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: dense ? 7 : 11,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: animation,
                      child: _PlayerGiftCaption(
                        event: event,
                        width: captionWidth,
                        dense: dense,
                        accent: accent,
                        secondary: secondary,
                      ),
                      builder: (context, child) {
                        final progress = _stageProgress(
                          animation: animation,
                          reduceMotion: reduceMotion,
                        );
                        final reveal = SliveMotion.standard.transform(
                          ((progress - 0.14) / 0.50).clamp(0.0, 1.0).toDouble(),
                        );
                        return Opacity(
                          opacity: reveal,
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - reveal)),
                            child: child,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

double _stageProgress({
  required Animation<double> animation,
  required bool reduceMotion,
}) {
  return reduceMotion ? 0.68 : animation.value;
}

class _PlayerGiftArtwork extends StatelessWidget {
  const _PlayerGiftArtwork({
    required this.imageUrl,
    required this.size,
    required this.accent,
    required this.secondary,
    required this.highlight,
    required this.maxDecodeDimension,
  });

  final String? imageUrl;
  final double size;
  final Color accent;
  final Color secondary;
  final bool highlight;
  final int maxDecodeDimension;

  @override
  Widget build(BuildContext context) {
    final fallbackArtwork = CustomPaint(
      painter: _GiftGlyphPainter(
        accent: accent,
        secondary: secondary,
      ),
    );

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: highlight ? 0.30 : 0.22),
                    accent.withValues(alpha: highlight ? 0.18 : 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.58, 1],
                ),
                border: Border.all(
                  color: accent.withValues(alpha: highlight ? 0.36 : 0.24),
                  width: highlight ? 1.5 : 1,
                ),
              ),
            ),
          ),
          SizedBox.square(
            dimension: size * 0.82,
            child: imageUrl == null
                ? fallbackArtwork
                : _GiftRemoteImage(
                    imageUrl: imageUrl!,
                    width: size * 0.82,
                    height: size * 0.82,
                    maxDecodeDimension: maxDecodeDimension,
                    fallback: fallbackArtwork,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlayerGiftCaption extends StatelessWidget {
  const _PlayerGiftCaption({
    required this.event,
    required this.width,
    required this.dense,
    required this.accent,
    required this.secondary,
  });

  final HuyaGiftDanmakuEvent event;
  final double width;
  final bool dense;
  final Color accent;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.sliveColors;
    final highlight = event.isHighlight;
    final fill = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.12 : 0.075),
      colors.glassStrong.withValues(alpha: isDark ? 0.92 : 0.88),
    );

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SliveRadii.pill),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              fill,
              Color.alphaBlend(
                secondary.withValues(alpha: highlight ? 0.08 : 0.035),
                fill,
              ),
            ],
          ),
          border: Border.all(
            color: accent.withValues(alpha: highlight ? 0.34 : 0.20),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            dense ? 11 : 14,
            dense ? 8 : 10,
            dense ? 8 : 10,
            dense ? 8 : 10,
          ),
          child: Row(
            children: [
              if (highlight) ...[
                Icon(
                  Icons.auto_awesome_rounded,
                  size: dense ? 15 : 17,
                  color: accent,
                ),
                SizedBox(width: dense ? 7 : 9),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (highlight && !dense) ...[
                      Text(
                        '高光礼物',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.92),
                          fontSize: 9.5,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      event.giftName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: dense
                            ? 13
                            : highlight
                                ? 16
                                : 15,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${event.sender} 送出',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: dense ? 9.5 : 11,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: dense ? 8 : 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(SliveRadii.pill),
                  border: Border.all(
                    color: accent.withValues(alpha: highlight ? 0.44 : 0.28),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: dense ? 9 : 12,
                    vertical: dense ? 6 : 8,
                  ),
                  child: Text(
                    '×${event.count}',
                    maxLines: 1,
                    style: TextStyle(
                      color: accent,
                      fontSize: dense
                          ? 14
                          : highlight
                              ? 19
                              : 17,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftStageParticles extends StatelessWidget {
  const _GiftStageParticles({
    required this.progress,
    required this.highlight,
    required this.accent,
    required this.secondary,
  });

  final double progress;
  final bool highlight;
  final Color accent;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final particles = <({
      Alignment alignment,
      Offset travel,
      double phase,
      double size,
      Color color,
    })>[
      (
        alignment: const Alignment(-0.72, -0.50),
        travel: const Offset(-8, -14),
        phase: 0.04,
        size: 15,
        color: accent,
      ),
      (
        alignment: const Alignment(0.67, -0.62),
        travel: const Offset(9, -12),
        phase: 0.11,
        size: 12,
        color: secondary,
      ),
      (
        alignment: const Alignment(-0.82, 0.08),
        travel: const Offset(-12, -4),
        phase: 0.18,
        size: 10,
        color: secondary,
      ),
      (
        alignment: const Alignment(0.80, 0.02),
        travel: const Offset(12, -6),
        phase: 0.25,
        size: 14,
        color: accent,
      ),
      (
        alignment: const Alignment(-0.50, 0.54),
        travel: const Offset(-7, 10),
        phase: 0.31,
        size: 9,
        color: accent,
      ),
      (
        alignment: const Alignment(0.54, 0.48),
        travel: const Offset(8, 8),
        phase: 0.38,
        size: 11,
        color: secondary,
      ),
      if (highlight)
        (
          alignment: const Alignment(-0.18, -0.78),
          travel: const Offset(-3, -14),
          phase: 0.20,
          size: 13,
          color: secondary,
        ),
      if (highlight)
        (
          alignment: const Alignment(0.22, -0.82),
          travel: const Offset(4, -16),
          phase: 0.29,
          size: 10,
          color: accent,
        ),
    ];

    return Stack(
      children: [
        for (final particle in particles)
          Align(
            alignment: particle.alignment,
            child: _GiftStageParticle(
              progress: progress,
              phase: particle.phase,
              travel: particle.travel,
              size: particle.size * (highlight ? 1.08 : 1),
              color: particle.color,
            ),
          ),
      ],
    );
  }
}

class _GiftStageParticle extends StatelessWidget {
  const _GiftStageParticle({
    required this.progress,
    required this.phase,
    required this.travel,
    required this.size,
    required this.color,
  });

  final double progress;
  final double phase;
  final Offset travel;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final localProgress =
        ((progress - phase) / 0.48).clamp(0.0, 1.0).toDouble();
    final fadeOut = progress <= 0.78
        ? 1.0
        : (1 - (progress - 0.78) / 0.22).clamp(0.0, 1.0).toDouble();
    final opacity = Curves.easeOut.transform(localProgress) * fadeOut;

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(
          travel.dx * localProgress,
          travel.dy * localProgress,
        ),
        child: Transform.scale(
          scale: 0.55 + 0.45 * Curves.easeOutBack.transform(localProgress),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: size,
            color: color.withValues(alpha: 0.88),
          ),
        ),
      ),
    );
  }
}

class _GiftStageAtmospherePainter extends CustomPainter {
  const _GiftStageAtmospherePainter({
    required this.accent,
    required this.secondary,
    required this.highlight,
  });

  final Color accent;
  final Color secondary;
  final bool highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.40);
    final shortest = size.shortestSide;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlight ? 1.35 : 1.0;

    for (var index = 0; index < (highlight ? 3 : 2); index++) {
      final inset = shortest * (0.08 + index * 0.075);
      final rect = Rect.fromCenter(
        center: center,
        width: math.max(1, size.width - inset * 2.2),
        height: math.max(1, size.height - inset * 1.55),
      );
      ringPaint.color = Color.lerp(accent, secondary, index / 3)!
          .withValues(alpha: 0.18 - index * 0.035);
      canvas.drawOval(rect, ringPaint);
    }

    final horizonPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          secondary.withValues(alpha: highlight ? 0.22 : 0.14),
          accent.withValues(alpha: highlight ? 0.28 : 0.17),
          Colors.transparent,
        ],
        stops: const [0, 0.34, 0.66, 1],
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.54, size.width, 1),
      )
      ..strokeWidth = highlight ? 1.4 : 1;
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.54),
      Offset(size.width * 0.88, size.height * 0.54),
      horizonPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GiftStageAtmospherePainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.secondary != secondary ||
        oldDelegate.highlight != highlight;
  }
}

class _GiftSparkles extends StatelessWidget {
  const _GiftSparkles({
    required this.progress,
    required this.size,
    required this.accent,
    required this.secondary,
    required this.dense,
  });

  final double progress;
  final double size;
  final Color accent;
  final Color secondary;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final particles = <({Alignment alignment, double phase, Color color})>[
      (alignment: const Alignment(-0.86, -0.44), phase: 0.10, color: accent),
      (alignment: const Alignment(0.84, -0.62), phase: 0.22, color: secondary),
      (alignment: const Alignment(0.92, 0.34), phase: 0.34, color: accent),
      (alignment: const Alignment(-0.68, 0.76), phase: 0.46, color: secondary),
      if (!dense)
        (alignment: const Alignment(0.10, -0.94), phase: 0.58, color: accent),
    ];

    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          for (final particle in particles)
            Align(
              alignment: particle.alignment,
              child: Transform.translate(
                offset: Offset(0, -5 * progress),
                child: Transform.scale(
                  scale: (progress - particle.phase).clamp(0.0, 1.0).toDouble(),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: size * 0.105,
                    color: particle.color.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GiftRemoteImage extends StatelessWidget {
  const _GiftRemoteImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    this.maxDecodeDimension = 512,
    this.fallback,
  });

  final String imageUrl;
  final double width;
  final double height;
  final int maxDecodeDimension;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = _normalizeGiftImageUrl(imageUrl);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final requestedWidth = math.max(1.0, width * pixelRatio);
    final requestedHeight = math.max(1.0, height * pixelRatio);
    final requestedLargest = math.max(requestedWidth, requestedHeight);
    final decodeScale = math.min(
      1.0,
      maxDecodeDimension / requestedLargest,
    );
    final cacheWidth = math.max(1, (requestedWidth * decodeScale).round());
    final cacheHeight = math.max(1, (requestedHeight * decodeScale).round());
    final fallbackWidget = fallback ?? const SizedBox.shrink();

    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Image.network(
          normalizedUrl,
          width: width,
          height: height,
          fit: BoxFit.contain,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          excludeFromSemantics: true,
          errorBuilder: (_, error, stackTrace) => SizedBox.expand(
            child: fallbackWidget,
          ),
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return SizedBox.expand(child: fallbackWidget);
          },
        ),
      ),
    );
  }
}

class _GiftArtwork extends StatelessWidget {
  const _GiftArtwork({
    required this.event,
    required this.size,
    required this.accent,
    required this.secondary,
  });

  final HuyaGiftDanmakuEvent event;
  final double size;
  final Color accent;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final giftImageUrl = _safeGiftImageUrl(event.giftImageUrl);
    final effectImageUrl = _safeGiftImageUrl(event.giftEffectImageUrl);
    final primaryImageUrl = giftImageUrl ?? effectImageUrl;
    final fallbackArtwork = CustomPaint(
      painter: _GiftGlyphPainter(
        accent: accent,
        secondary: secondary,
      ),
    );
    final networkFallback = giftImageUrl != null &&
            effectImageUrl != null &&
            !_sameGiftImageUrl(giftImageUrl, effectImageUrl)
        ? _GiftRemoteImage(
            imageUrl: effectImageUrl,
            width: size * 0.84,
            height: size * 0.84,
            maxDecodeDimension: 320,
            fallback: fallbackArtwork,
          )
        : fallbackArtwork;

    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.24),
                    secondary.withValues(alpha: 0.15),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.46),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.28),
                child: primaryImageUrl == null
                    ? fallbackArtwork
                    : Padding(
                        padding: EdgeInsets.all(size * 0.08),
                        child: _GiftRemoteImage(
                          imageUrl: primaryImageUrl,
                          width: size * 0.84,
                          height: size * 0.84,
                          maxDecodeDimension: 320,
                          fallback: networkFallback,
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            right: -5,
            bottom: -4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(SliveRadii.pill),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: Text(
                  '×${event.count}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _safeGiftImageUrl(String? imageUrl) {
  return isSafeHuyaGiftImageUrl(imageUrl) ? imageUrl : null;
}

String _normalizeGiftImageUrl(String imageUrl) {
  return imageUrl.startsWith('//') ? 'https:$imageUrl' : imageUrl;
}

bool _sameGiftImageUrl(String first, String second) {
  return _normalizeGiftImageUrl(first) == _normalizeGiftImageUrl(second);
}

class _GiftGlyphPainter extends CustomPainter {
  const _GiftGlyphPainter({
    required this.accent,
    required this.secondary,
  });

  final Color accent;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.72),
          secondary.withValues(alpha: 0.08),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(
        size.center(Offset.zero), size.shortestSide * 0.45, glowPaint);

    final boxRect = Rect.fromLTWH(
      size.width * 0.22,
      size.height * 0.43,
      size.width * 0.56,
      size.height * 0.37,
    );
    final boxPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, secondary],
      ).createShader(boxRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boxRect, Radius.circular(size.width * 0.09)),
      boxPaint,
    );

    final lidRect = Rect.fromLTWH(
      size.width * 0.17,
      size.height * 0.36,
      size.width * 0.66,
      size.height * 0.14,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lidRect, Radius.circular(size.width * 0.07)),
      Paint()..color = accent,
    );

    final ribbonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.45,
          size.height * 0.35,
          size.width * 0.10,
          size.height * 0.46,
        ),
        Radius.circular(size.width * 0.025),
      ),
      ribbonPaint,
    );

    final bowPaint = Paint()
      ..color = secondary
      ..style = PaintingStyle.fill;
    final leftBow = Path()
      ..moveTo(size.width * 0.49, size.height * 0.38)
      ..cubicTo(
        size.width * 0.20,
        size.height * 0.31,
        size.width * 0.25,
        size.height * 0.13,
        size.width * 0.50,
        size.height * 0.34,
      )
      ..close();
    final rightBow = Path()
      ..moveTo(size.width * 0.51, size.height * 0.38)
      ..cubicTo(
        size.width * 0.80,
        size.height * 0.31,
        size.width * 0.75,
        size.height * 0.13,
        size.width * 0.50,
        size.height * 0.34,
      )
      ..close();
    canvas
      ..drawPath(leftBow, bowPaint)
      ..drawPath(rightBow, bowPaint)
      ..drawCircle(
        Offset(size.width * 0.5, size.height * 0.35),
        size.width * 0.075,
        Paint()..color = accent,
      );

    final sparklePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..strokeWidth = math.max(1.2, size.width * 0.026)
      ..strokeCap = StrokeCap.round;
    _drawSparkle(
      canvas,
      Offset(size.width * 0.80, size.height * 0.20),
      size.width * 0.075,
      sparklePaint,
    );
    _drawSparkle(
      canvas,
      Offset(size.width * 0.17, size.height * 0.25),
      size.width * 0.045,
      sparklePaint,
    );
  }

  void _drawSparkle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    canvas
      ..drawLine(
        Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy),
        paint,
      )
      ..drawLine(
        Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant _GiftGlyphPainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.secondary != secondary;
  }
}
