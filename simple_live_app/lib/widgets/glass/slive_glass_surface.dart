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
        const Color(0xFF8E7E6E).withValues(
          alpha: visual.shadowOpacity,
        );
    final blurEnabled = enableBackdropBlur ?? visual.blurByDefault;

    Widget content = padding == null
        ? child
        : Padding(
            padding: padding!,
            child: child,
          );

    if (onTap != null || onLongPress != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }

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
        boxShadow: visual.hasShadow
            ? [
                BoxShadow(
                  color: resolvedShadow,
                  blurRadius: visual.shadowBlur,
                  spreadRadius: visual.shadowSpread,
                  offset: visual.shadowOffset,
                ),
                if (!isDark && variant != SliveGlassVariant.pill)
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.025),
                    blurRadius: visual.shadowBlur + 10,
                    spreadRadius: -8,
                    offset: const Offset(0, 12),
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
          hasShadow: true,
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
          hasShadow: true,
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
          hasShadow: true,
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
