import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';

enum SliveGlassVariant {
  card,
  panel,
  pill,
  dock,
  overlay,
}

class SliveGlassSurface extends StatelessWidget {
  const SliveGlassSurface({
    super.key,
    required this.child,
    this.variant = SliveGlassVariant.card,
    this.enableBackdropBlur,
    this.radius,
    this.padding,
    this.margin,
    this.constraints,
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
    this.shadowColor,
    this.showShadow,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final SliveGlassVariant variant;
  final bool? enableBackdropBlur;
  final double? radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxConstraints? constraints;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;
  final Color? shadowColor;
  final bool? showShadow;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.sliveColors;
    final materials = context.sliveMaterials;
    final isDark = theme.brightness == Brightness.dark;
    final visual = _GlassVisual.resolve(variant, materials);
    final resolvedRadius = radius ?? visual.radius;
    final borderRadius = BorderRadius.circular(resolvedRadius);
    final baseColor = color ??
        (variant == SliveGlassVariant.overlay
            ? colors.glassStrong
            : colors.glassBase);
    final fill = baseColor.withValues(alpha: visual.opacity);
    final tintedFill = Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: materials.tintOpacity),
      fill,
    );
    final resolvedBorder = borderColor ??
        colors.glassBorder.withValues(
          alpha: materials.borderOpacity * (isDark ? 0.74 : 1),
        );
    final resolvedShadow = shadowColor ??
        Color.lerp(colors.backgroundEnd, theme.colorScheme.primary, 0.12)!
            .withValues(alpha: visual.shadowOpacity);
    final requestedBlur = enableBackdropBlur ?? visual.blurByDefault;
    // 柔和材质使用高遮罩渐变模拟磨砂，不启用实时 BackdropFilter。
    // 这能避免滚动列表与视频画面每帧重新采样背景，显著降低 GPU 合成压力。
    final blurEnabled = requestedBlur && materials.mode == SliveGlassMode.clear;
    final shadowEnabled = (showShadow ?? visual.hasShadow) &&
        materials.mode == SliveGlassMode.clear &&
        resolvedShadow.a > 0.001;

    Widget content = padding == null
        ? child
        : Padding(
            padding: padding!,
            child: child,
          );

    if (onTap != null || onLongPress != null) {
      content = InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.035),
        focusColor: Colors.transparent,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return theme.colorScheme.primary.withValues(alpha: 0.055);
          }
          return Colors.transparent;
        }),
        child: content,
      );
    }

    // 始终提供本地透明 Material。设置项、TabBar 等后代 Ink 控件因此不会
    // 向外层 Scaffold 寻找材质并绘制出越界的黑色涟漪/焦点环。
    content = Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.none,
      child: content,
    );

    Widget inner = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tintedFill, fill],
        ),
        border: Border.all(color: resolvedBorder),
      ),
      child: content,
    );

    if (blurEnabled) {
      inner = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: visual.blurSigma,
          sigmaY: visual.blurSigma,
        ),
        child: inner,
      );
    }

    inner = ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      child: inner,
    );

    return Container(
      margin: margin,
      constraints: constraints,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadowEnabled
            ? [
                BoxShadow(
                  color: resolvedShadow,
                  blurRadius: visual.shadowBlur,
                  spreadRadius: visual.shadowSpread,
                  offset: visual.shadowOffset,
                ),
              ]
            : null,
      ),
      child: inner,
    );
  }
}

class _GlassVisual {
  const _GlassVisual({
    required this.radius,
    required this.opacity,
    required this.blurSigma,
    required this.blurByDefault,
    required this.hasShadow,
    required this.shadowOpacity,
    required this.shadowBlur,
    required this.shadowSpread,
    required this.shadowOffset,
  });

  factory _GlassVisual.resolve(
    SliveGlassVariant variant,
    SliveMaterialTokens materials,
  ) {
    return switch (variant) {
      SliveGlassVariant.card => _GlassVisual(
          radius: SliveRadii.card,
          opacity: materials.cardOpacity,
          blurSigma: materials.backdropBlur,
          blurByDefault: false,
          hasShadow: false,
          shadowOpacity: materials.shadowOpacity,
          shadowBlur: 20,
          shadowSpread: -4,
          shadowOffset: const Offset(0, 6),
        ),
      SliveGlassVariant.panel => _GlassVisual(
          radius: SliveRadii.panel,
          opacity: materials.panelOpacity,
          blurSigma: materials.backdropBlur,
          blurByDefault: false,
          hasShadow: false,
          shadowOpacity: materials.shadowOpacity,
          shadowBlur: 28,
          shadowSpread: -6,
          shadowOffset: const Offset(0, 10),
        ),
      SliveGlassVariant.pill => _GlassVisual(
          radius: SliveRadii.pill,
          opacity: materials.pillOpacity,
          blurSigma: materials.backdropBlur,
          blurByDefault: false,
          hasShadow: false,
          shadowOpacity: materials.shadowOpacity * 0.72,
          shadowBlur: 16,
          shadowSpread: -6,
          shadowOffset: const Offset(0, 5),
        ),
      SliveGlassVariant.dock => _GlassVisual(
          radius: SliveRadii.dock,
          opacity: materials.panelOpacity,
          blurSigma: materials.backdropBlur,
          blurByDefault: true,
          hasShadow: true,
          shadowOpacity: materials.shadowOpacity * 1.15,
          shadowBlur: 30,
          shadowSpread: -7,
          shadowOffset: const Offset(0, 12),
        ),
      SliveGlassVariant.overlay => _GlassVisual(
          radius: SliveRadii.panel,
          opacity: materials.overlayOpacity,
          blurSigma: materials.overlayBlur,
          blurByDefault: true,
          hasShadow: true,
          shadowOpacity: materials.shadowOpacity * 1.2,
          shadowBlur: 34,
          shadowSpread: -7,
          shadowOffset: const Offset(0, 14),
        ),
    };
  }

  final double radius;
  final double opacity;
  final double blurSigma;
  final bool blurByDefault;
  final bool hasShadow;
  final double shadowOpacity;
  final double shadowBlur;
  final double shadowSpread;
  final Offset shadowOffset;
}
