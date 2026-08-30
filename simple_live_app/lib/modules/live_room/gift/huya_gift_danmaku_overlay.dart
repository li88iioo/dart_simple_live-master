import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_event.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/net_image.dart';

class HuyaGiftDanmakuOverlay extends StatelessWidget {
  const HuyaGiftDanmakuOverlay({
    super.key,
    required this.controller,
  });

  final LiveRoomController controller;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Align(
            alignment: const Alignment(-1, -0.58),
            child: Obx(() {
              final enabled =
                  AppSettingsController.instance.huyaGiftDanmakuEnable.value &&
                      controller.showDanmakuState.value;
              final event =
                  enabled ? controller.activeHuyaGiftEffect.value : null;

              return AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                reverseDuration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                switchInCurve: SliveMotion.standard,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0.14, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  final scale = Tween<double>(begin: 0.96, end: 1).animate(
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
                    : _GiftGlassCapsule(
                        key: ValueKey(event.id),
                        event: event,
                      ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _GiftGlassCapsule extends StatefulWidget {
  const _GiftGlassCapsule({
    super.key,
    required this.event,
  });

  final HuyaGiftDanmakuEvent event;

  @override
  State<_GiftGlassCapsule> createState() => _GiftGlassCapsuleState();
}

class _GiftGlassCapsuleState extends State<_GiftGlassCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shineController.stop();
      _shineController.value = 1;
    }
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.sliveColors;
    final materials = context.sliveMaterials;
    final highlight = widget.event.isHighlight;
    final accent = highlight ? const Color(0xFFFFB35A) : colors.huya;
    final secondary =
        highlight ? const Color(0xFFFF6F91) : const Color(0xFFFFD08A);
    final surfaceColor = Color.lerp(
      colors.glassStrong,
      accent,
      isDark ? 0.10 : 0.045,
    );

    return Semantics(
      liveRegion: true,
      label: widget.event.semanticsLabel,
      child: RepaintBoundary(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SliveGlassSurface(
            variant: SliveGlassVariant.overlay,
            radius: 24,
            // 视频画面持续变化，柔和模式使用静态磨砂，避免礼物密集时持续采样视频。
            enableBackdropBlur: materials.mode == SliveGlassMode.clear,
            color: surfaceColor,
            borderColor: colors.glassBorder.withValues(
              alpha: materials.borderOpacity * (isDark ? 0.72 : 0.92),
            ),
            shadowColor: accent.withValues(alpha: isDark ? 0.16 : 0.12),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: isDark ? 0.20 : 0.14),
                          secondary.withValues(alpha: isDark ? 0.12 : 0.07),
                          colors.glassStrong.withValues(
                            alpha: isDark ? 0.03 : 0.14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: _shineController,
                      builder: (context, child) {
                        final progress = SliveMotion.standard.transform(
                          _shineController.value,
                        );
                        return FractionalTranslation(
                          translation: Offset(-1.2 + progress * 2.5, 0),
                          child: Transform.rotate(
                            angle: -math.pi / 10,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 54,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white.withValues(alpha: 0.34),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [accent, secondary],
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.glassStrong,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: ClipOval(
                            child: NetImage(
                              widget.event.senderIcon,
                              width: 34,
                              height: 34,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.event.sender,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text.rich(
                              TextSpan(
                                text: '送出 ',
                                children: [
                                  TextSpan(
                                    text: widget.event.giftName,
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                                height: 1.18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.20 : 0.14),
                          borderRadius: BorderRadius.circular(SliveRadii.pill),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          '×${widget.event.count}',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFFFD9A8)
                                : const Color(0xFF9A4E0B),
                            fontSize: 14,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
