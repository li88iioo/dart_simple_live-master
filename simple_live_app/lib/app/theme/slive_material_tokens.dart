import 'package:flutter/material.dart';

enum SliveGlassMode {
  clear,
  soft,
}

extension SliveGlassModeLabel on SliveGlassMode {
  String get label => switch (this) {
        SliveGlassMode.clear => '通透',
        SliveGlassMode.soft => '柔和',
      };

  String get description => switch (this) {
        SliveGlassMode.clear => '更清透的背景折射与高斯模糊',
        SliveGlassMode.soft => '更高遮罩、更低模糊，兼顾续航',
      };
}

@immutable
class SliveMaterialTokens extends ThemeExtension<SliveMaterialTokens> {
  const SliveMaterialTokens({
    required this.mode,
    required this.cardOpacity,
    required this.panelOpacity,
    required this.pillOpacity,
    required this.overlayOpacity,
    required this.borderOpacity,
    required this.backdropBlur,
    required this.overlayBlur,
    required this.shadowOpacity,
    required this.tintOpacity,
  });

  factory SliveMaterialTokens.resolve(
    SliveGlassMode mode,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    return switch (mode) {
      SliveGlassMode.clear => SliveMaterialTokens(
          mode: mode,
          cardOpacity: isDark ? 0.66 : 0.76,
          panelOpacity: isDark ? 0.70 : 0.78,
          pillOpacity: isDark ? 0.62 : 0.74,
          overlayOpacity: isDark ? 0.74 : 0.80,
          borderOpacity: isDark ? 0.20 : 0.72,
          backdropBlur: 34,
          overlayBlur: 36,
          shadowOpacity: isDark ? 0.14 : 0.08,
          tintOpacity: isDark ? 0.12 : 0.08,
        ),
      SliveGlassMode.soft => SliveMaterialTokens(
          mode: mode,
          cardOpacity: isDark ? 0.78 : 0.86,
          panelOpacity: isDark ? 0.82 : 0.88,
          pillOpacity: isDark ? 0.74 : 0.84,
          overlayOpacity: isDark ? 0.84 : 0.90,
          borderOpacity: isDark ? 0.16 : 0.56,
          backdropBlur: 24,
          overlayBlur: 28,
          shadowOpacity: isDark ? 0.10 : 0.06,
          tintOpacity: isDark ? 0.08 : 0.05,
        ),
    };
  }

  final SliveGlassMode mode;
  final double cardOpacity;
  final double panelOpacity;
  final double pillOpacity;
  final double overlayOpacity;
  final double borderOpacity;
  final double backdropBlur;
  final double overlayBlur;
  final double shadowOpacity;
  final double tintOpacity;

  @override
  SliveMaterialTokens copyWith({
    SliveGlassMode? mode,
    double? cardOpacity,
    double? panelOpacity,
    double? pillOpacity,
    double? overlayOpacity,
    double? borderOpacity,
    double? backdropBlur,
    double? overlayBlur,
    double? shadowOpacity,
    double? tintOpacity,
  }) {
    return SliveMaterialTokens(
      mode: mode ?? this.mode,
      cardOpacity: cardOpacity ?? this.cardOpacity,
      panelOpacity: panelOpacity ?? this.panelOpacity,
      pillOpacity: pillOpacity ?? this.pillOpacity,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      borderOpacity: borderOpacity ?? this.borderOpacity,
      backdropBlur: backdropBlur ?? this.backdropBlur,
      overlayBlur: overlayBlur ?? this.overlayBlur,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      tintOpacity: tintOpacity ?? this.tintOpacity,
    );
  }

  @override
  SliveMaterialTokens lerp(
    covariant ThemeExtension<SliveMaterialTokens>? other,
    double t,
  ) {
    if (other is! SliveMaterialTokens) return this;
    return SliveMaterialTokens(
      mode: t < 0.5 ? mode : other.mode,
      cardOpacity: _lerpDouble(cardOpacity, other.cardOpacity, t),
      panelOpacity: _lerpDouble(panelOpacity, other.panelOpacity, t),
      pillOpacity: _lerpDouble(pillOpacity, other.pillOpacity, t),
      overlayOpacity: _lerpDouble(overlayOpacity, other.overlayOpacity, t),
      borderOpacity: _lerpDouble(borderOpacity, other.borderOpacity, t),
      backdropBlur: _lerpDouble(backdropBlur, other.backdropBlur, t),
      overlayBlur: _lerpDouble(overlayBlur, other.overlayBlur, t),
      shadowOpacity: _lerpDouble(shadowOpacity, other.shadowOpacity, t),
      tintOpacity: _lerpDouble(tintOpacity, other.tintOpacity, t),
    );
  }
}

double _lerpDouble(double begin, double end, double t) {
  return begin + (end - begin) * t;
}
