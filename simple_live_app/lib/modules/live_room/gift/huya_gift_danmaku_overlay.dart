import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_event.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_remote_image.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';

enum HuyaGiftOverlayPlacement { player, chat }

typedef HuyaGiftImageProviderBuilder = ImageProvider<Object> Function(
    String url);

/// 非全屏礼物借鉴虎牙原生的“弹幕顶部礼物轨”：短内容按需收拢，
/// 长昵称、长礼物名和大数量可扩展并自然换行，不以省略号换取固定高度。
const double huyaChatGiftMaxWidth = 336;
const double huyaChatGiftMinWidth = 196;
const double huyaChatGiftMinHeight = 58;
const double huyaPlayerGiftAbsoluteMaxWidth = 300;
const double huyaPlayerGiftViewportFraction = 0.24;
const double huyaPlayerGiftMinHeight = 58;

/// 全屏礼物只占播放器安全边缘的一小块区域，不制作中央舞台。
double resolveHuyaGiftPlayerMaxWidth(double viewportWidth) {
  // 竖屏/窄窗口必须先放得下图标、文字与数量；宽屏仍保持原有低遮挡上限。
  final availableWidth = viewportWidth < 720
      ? viewportWidth - 28
      : viewportWidth * huyaPlayerGiftViewportFraction;
  return math.max(
    1.0,
    math.min(huyaPlayerGiftAbsoluteMaxWidth, availableWidth),
  );
}

/// 非全屏礼物按真实文案宽度收拢；只有长昵称才扩展到最大宽度并自然换行。
double resolveHuyaChatGiftPreferredWidth(
  BuildContext context,
  HuyaGiftDanmakuEvent event,
  double maxWidth,
) {
  final boundedMax = math.max(1.0, maxWidth);
  final boundedMin = math.min(huyaChatGiftMinWidth, boundedMax);
  final direction = Directionality.of(context);
  final textScaler = MediaQuery.textScalerOf(context);

  double measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: direction,
      textScaler: textScaler,
    )..layout();
    return painter.width;
  }

  const senderStyle = TextStyle(
    fontSize: 12.5,
    height: 1.12,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.05,
  );
  const detailStyle = TextStyle(
    fontSize: 10.5,
    height: 1.12,
    fontWeight: FontWeight.w600,
  );
  const countStyle = TextStyle(
    fontSize: 11.5,
    height: 1,
    fontWeight: FontWeight.w800,
  );

  final senderWidth = measure(event.sender, senderStyle);
  final detailWidth = measure(event.description, detailStyle);
  final interactionWidth = event.interactionText.isEmpty
      ? 0.0
      : measure(event.interactionText, detailStyle);
  final countWidth = event.quantityLabel == null
      ? 0.0
      : math.max(38.0, measure(event.quantityLabel!, countStyle) + 16);
  final copyWidth = math.max(
    senderWidth,
    math.max(detailWidth, interactionWidth),
  );
  // 左右内边距 + 礼物图 + 间距 + 独立数量区。数量不再挤占礼物名尾部。
  final fixedWidth = 9.0 + 40.0 + 8.0 + 8.0 + countWidth + 10.0;
  return (fixedWidth + copyWidth).clamp(boundedMin, boundedMax).toDouble();
}

/// 非全屏礼物停在弹幕顶部左侧的稳定轨道，全屏礼物停在播放器左下安全边缘。
Alignment resolveHuyaGiftOverlayAlignment(HuyaGiftOverlayPlacement placement) {
  return placement == HuyaGiftOverlayPlacement.chat
      ? Alignment.topLeft
      : Alignment.bottomLeft;
}

/// 返回首个可展示资源，保留该方法兼容现有调用与测试。实际图片组件会在加载
/// 失败时依次尝试 [HuyaGiftDanmakuEvent.presentationImageUrls] 的后续候选。
String? selectHuyaGiftPresentationImageUrl(HuyaGiftDanmakuEvent event) {
  return event.presentationImageUrls.firstOrNull;
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
                ? math.min(
                    huyaChatGiftMaxWidth,
                    math.max(1.0, viewportWidth - 24),
                  )
                : resolveHuyaGiftPlayerMaxWidth(viewportWidth);
            final padding = _isChat
                ? const EdgeInsets.fromLTRB(12, 50, 12, 12)
                : EdgeInsets.fromLTRB(
                    viewportWidth < 720 ? 14 : 20,
                    12,
                    12,
                    viewportWidth < 720 ? 48 : 62,
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
                        : const Duration(milliseconds: 150),
                    reverseDuration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 120),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      if (reduceMotion) return child;
                      // Switcher 已应用进出曲线；不要在 rebuild 中创建未释放的监听。
                      final slide = Tween<Offset>(
                        begin: _isChat
                            ? const Offset(0.018, -0.008)
                            : const Offset(-0.018, 0.012),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment:
                            _isChat ? Alignment.topLeft : Alignment.bottomLeft,
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
                            key: ValueKey(
                              _isChat
                                  ? 'active-huya-chat-gift'
                                  : 'active-huya-player-gift',
                            ),
                            event: event,
                            placement: placement,
                            maxWidth: cardMaxWidth,
                            reduceMotion: reduceMotion,
                          ),
                  );
                }),
              ),
            );

            if (!_isChat) overlay = SafeArea(child: overlay);
            return overlay;
          },
        ),
      ),
    );
  }
}

/// 柔和、低干扰的虎牙礼物边缘通知。
///
/// 借鉴虎牙原生礼物轨的信息结构，但使用 Slive 的柔润浅色材质：发送者和
/// 礼物名允许自然换行，数量保留独立尾部区域，三者都不使用省略号。
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
        ? resolveHuyaChatGiftPreferredWidth(context, event, maxWidth)
        : highlight
            ? 292.0
            : 268.0;
    final width = math.max(1.0, math.min(maxWidth, preferredWidth));
    final minWidth = _isChat ? width : math.min(width, 220.0);

    return Semantics(
      liveRegion: true,
      label: event.semanticsLabel,
      child: ConstrainedBox(
        key: ValueKey(
          _isChat ? 'huya-chat-gift-card' : 'huya-player-edge-gift-card',
        ),
        constraints: BoxConstraints(
          minWidth: minWidth,
          maxWidth: width,
          minHeight: _isChat ? huyaChatGiftMinHeight : huyaPlayerGiftMinHeight,
        ),
        child: _GiftEdgeCard(
          event: event,
          placement: placement,
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
    required this.reduceMotion,
    required this.imageProviderBuilder,
  });

  final HuyaGiftDanmakuEvent event;
  final HuyaGiftOverlayPlacement placement;
  final bool reduceMotion;
  final HuyaGiftImageProviderBuilder? imageProviderBuilder;

  bool get _isPlayer => placement == HuyaGiftOverlayPlacement.player;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = event.isHighlight;
    final accent = highlight ? const Color(0xFFFFB35D) : colors.huya;
    final artworkSize = _isPlayer ? 42.0 : 40.0;
    final imageUrls = event.presentationImageUrls;
    final surface = _isPlayer
        ? Colors.black.withValues(alpha: highlight ? 0.31 : 0.23)
        : Color.alphaBlend(
            accent.withValues(alpha: 0.016),
            colors.glassBase.withValues(alpha: isDark ? 0.78 : 0.84),
          );
    final borderColor = _isPlayer
        ? Colors.white.withValues(alpha: highlight ? 0.16 : 0.11)
        : colors.glassBorder.withValues(alpha: isDark ? 0.18 : 0.34);
    final foreground =
        _isPlayer ? Colors.white.withValues(alpha: 0.94) : colors.textPrimary;
    final secondary =
        _isPlayer ? Colors.white.withValues(alpha: 0.68) : colors.textSecondary;

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: _isPlayer ? 0.025 : 0.08),
              surface,
            ),
            surface,
          ],
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor, width: 0.65),
      ),
      child: Stack(
        children: [
          if (highlight)
            Positioned(
              left: 0,
              top: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: _isPlayer ? 0.52 : 0.38),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(2),
                  ),
                ),
                child: const SizedBox(width: 2),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 10, 7),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final copy = _GiftCopy(
                  event: event,
                  foreground: foreground,
                  secondary: secondary,
                  playerPlacement: _isPlayer,
                );
                final badge = event.quantityLabel == null
                    ? null
                    : _GiftCountBadge(
                        label: event.quantityLabel!,
                        accent: accent,
                        playerPlacement: _isPlayer,
                      );
                // 数量区不可挤成零宽文字列。窄卡/大字时改为独立下一行，
                // 图片仍保持固定占位，异步加载不会改变此布局决策。
                final quantityWidth = badge == null
                    ? 0.0
                    : event.quantityLabel!.length *
                            MediaQuery.textScalerOf(context).scale(11.5) +
                        16;
                final compact = constraints.maxWidth <
                    artworkSize +
                        8 +
                        (_isPlayer ? 96 : 64) +
                        (badge == null ? 0 : 8 + quantityWidth);
                final row = Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _GiftArtwork(
                      imageUrls: imageUrls,
                      eventId: event.id,
                      isGuardian: event.isGuardian,
                      size: artworkSize,
                      accent: accent,
                      playerPlacement: _isPlayer,
                      imageProviderBuilder: imageProviderBuilder,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: copy),
                    if (!compact && badge != null) ...[
                      const SizedBox(width: 8),
                      badge,
                    ],
                  ],
                );
                if (!compact || badge == null) return row;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    row,
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(fit: BoxFit.scaleDown, child: badge),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );

    if (!_isPlayer) {
      card = BackdropFilter(
        key: const ValueKey('huya-chat-gift-backdrop'),
        filter: ui.ImageFilter.blur(sigmaX: 10.5, sigmaY: 10.5),
        child: card,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.hardEdge,
      child: card,
    );
  }
}

class _GiftCopy extends StatelessWidget {
  const _GiftCopy({
    required this.event,
    required this.foreground,
    required this.secondary,
    required this.playerPlacement,
  });

  final HuyaGiftDanmakuEvent event;
  final Color foreground;
  final Color secondary;
  final bool playerPlacement;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          event.sender,
          key: const ValueKey('huya-gift-sender'),
          softWrap: true,
          style: TextStyle(
            color: foreground,
            fontSize: playerPlacement ? 13.0 : 12.5,
            height: 1.14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.05,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          event.description,
          key: const ValueKey('huya-gift-name'),
          softWrap: true,
          style: TextStyle(
            color: secondary,
            fontSize: playerPlacement ? 10.5 : 10.5,
            height: 1.14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (event.interactionText.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            event.interactionText,
            key: const ValueKey('huya-gift-interaction-text'),
            softWrap: true,
            style: TextStyle(
              color: playerPlacement
                  ? foreground.withValues(alpha: 0.82)
                  : foreground.withValues(alpha: 0.78),
              fontSize: 10.5,
              height: 1.18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _GiftCountBadge extends StatelessWidget {
  const _GiftCountBadge({
    required this.label,
    required this.accent,
    required this.playerPlacement,
  });

  final String label;
  final Color accent;
  final bool playerPlacement;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: playerPlacement ? 0.14 : 0.085),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          key: const ValueKey('huya-gift-count'),
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: playerPlacement
                ? Color.lerp(accent, Colors.white, 0.20)
                : Color.lerp(accent, context.sliveColors.textPrimary, 0.12),
            fontSize: 11.5,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _GiftArtwork extends StatelessWidget {
  const _GiftArtwork({
    required this.imageUrls,
    required this.eventId,
    this.isGuardian = false,
    required this.size,
    required this.accent,
    required this.playerPlacement,
    required this.imageProviderBuilder,
  });

  final List<String> imageUrls;
  final String eventId;
  final bool isGuardian;
  final double size;
  final Color accent;
  final bool playerPlacement;
  final HuyaGiftImageProviderBuilder? imageProviderBuilder;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Icon(
        isGuardian ? Icons.shield_outlined : Icons.card_giftcard_rounded,
        size: size * 0.44,
        color: accent.withValues(alpha: 0.78),
      ),
    );

    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.hardEdge,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: playerPlacement
                ? Colors.white.withValues(alpha: 0.065)
                : accent.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: playerPlacement ? 0.08 : 0.26,
              ),
              width: 0.5,
            ),
          ),
          child: imageUrls.isEmpty
              ? fallback
              : HuyaGiftRemoteImage(
                  key: ValueKey(eventId),
                  imageUrls: imageUrls,
                  size: size,
                  fallback: fallback,
                  imageProviderBuilder: imageProviderBuilder,
                ),
        ),
      ),
    );
  }
}
