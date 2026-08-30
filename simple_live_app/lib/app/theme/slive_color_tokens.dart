import 'package:flutter/material.dart';

@immutable
class SliveColorTokens extends ThemeExtension<SliveColorTokens> {
  const SliveColorTokens({
    required this.backgroundStart,
    required this.backgroundBase,
    required this.backgroundEnd,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.ambientPink,
    required this.ambientOrange,
    required this.ambientBlue,
    required this.ambientAccent,
    required this.glassBase,
    required this.glassStrong,
    required this.glassBorder,
    required this.divider,
    required this.bilibili,
    required this.douyu,
    required this.huya,
    required this.douyin,
    required this.twitch,
    required this.success,
    required this.danger,
  });

  factory SliveColorTokens.light(Color accent) {
    return SliveColorTokens(
      backgroundStart: const Color(0xFFFAF7F2),
      backgroundBase: const Color(0xFFF6F3ED),
      backgroundEnd: const Color(0xFFF0EBE2),
      textPrimary: const Color(0xFF2B2623),
      textSecondary: const Color(0xFF7A716A),
      textTertiary: const Color(0xFFABA29A),
      ambientPink: const Color(0xFFFFC9D8),
      ambientOrange: const Color(0xFFFFD4AE),
      ambientBlue: Color.lerp(const Color(0xFFC8DFFF), accent, 0.24)!,
      ambientAccent: accent,
      glassBase: Colors.white,
      glassStrong: const Color(0xFFFFFDF9),
      glassBorder: Colors.white,
      divider: const Color(0xFF7A716A),
      bilibili: const Color(0xFFFB7299),
      douyu: const Color(0xFFFF6E26),
      huya: const Color(0xFFF5A623),
      douyin: const Color(0xFF536071),
      twitch: const Color(0xFF8B72D9),
      success: const Color(0xFF65A97A),
      danger: const Color(0xFFE56D74),
    );
  }

  factory SliveColorTokens.dark(Color accent) {
    return SliveColorTokens(
      backgroundStart: const Color(0xFF171513),
      backgroundBase: const Color(0xFF1C1917),
      backgroundEnd: const Color(0xFF241F1B),
      textPrimary: const Color(0xFFF8F1E9),
      textSecondary: const Color(0xFFC8BBB0),
      textTertiary: const Color(0xFF91877F),
      ambientPink: const Color(0xFF82445A),
      ambientOrange: const Color(0xFF8B5735),
      ambientBlue: Color.lerp(const Color(0xFF41536D), accent, 0.28)!,
      ambientAccent: accent,
      glassBase: const Color(0xFF302B27),
      glassStrong: const Color(0xFF39322D),
      glassBorder: Colors.white,
      divider: const Color(0xFFC8BBB0),
      bilibili: const Color(0xFFFF86A7),
      douyu: const Color(0xFFFF8A52),
      huya: const Color(0xFFFFBC62),
      douyin: const Color(0xFFBBC6D4),
      twitch: const Color(0xFFA88BF2),
      success: const Color(0xFF7FC091),
      danger: const Color(0xFFFF8B91),
    );
  }

  final Color backgroundStart;
  final Color backgroundBase;
  final Color backgroundEnd;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color ambientPink;
  final Color ambientOrange;
  final Color ambientBlue;
  final Color ambientAccent;
  final Color glassBase;
  final Color glassStrong;
  final Color glassBorder;
  final Color divider;
  final Color bilibili;
  final Color douyu;
  final Color huya;
  final Color douyin;
  final Color twitch;
  final Color success;
  final Color danger;

  Color platform(String siteId) {
    return switch (siteId) {
      'bilibili' => bilibili,
      'douyu' => douyu,
      'huya' => huya,
      'douyin' => douyin,
      'twitch' => twitch,
      _ => ambientAccent,
    };
  }

  @override
  SliveColorTokens copyWith({
    Color? backgroundStart,
    Color? backgroundBase,
    Color? backgroundEnd,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? ambientPink,
    Color? ambientOrange,
    Color? ambientBlue,
    Color? ambientAccent,
    Color? glassBase,
    Color? glassStrong,
    Color? glassBorder,
    Color? divider,
    Color? bilibili,
    Color? douyu,
    Color? huya,
    Color? douyin,
    Color? twitch,
    Color? success,
    Color? danger,
  }) {
    return SliveColorTokens(
      backgroundStart: backgroundStart ?? this.backgroundStart,
      backgroundBase: backgroundBase ?? this.backgroundBase,
      backgroundEnd: backgroundEnd ?? this.backgroundEnd,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      ambientPink: ambientPink ?? this.ambientPink,
      ambientOrange: ambientOrange ?? this.ambientOrange,
      ambientBlue: ambientBlue ?? this.ambientBlue,
      ambientAccent: ambientAccent ?? this.ambientAccent,
      glassBase: glassBase ?? this.glassBase,
      glassStrong: glassStrong ?? this.glassStrong,
      glassBorder: glassBorder ?? this.glassBorder,
      divider: divider ?? this.divider,
      bilibili: bilibili ?? this.bilibili,
      douyu: douyu ?? this.douyu,
      huya: huya ?? this.huya,
      douyin: douyin ?? this.douyin,
      twitch: twitch ?? this.twitch,
      success: success ?? this.success,
      danger: danger ?? this.danger,
    );
  }

  @override
  SliveColorTokens lerp(
    covariant ThemeExtension<SliveColorTokens>? other,
    double t,
  ) {
    if (other is! SliveColorTokens) return this;
    return SliveColorTokens(
      backgroundStart: Color.lerp(backgroundStart, other.backgroundStart, t)!,
      backgroundBase: Color.lerp(backgroundBase, other.backgroundBase, t)!,
      backgroundEnd: Color.lerp(backgroundEnd, other.backgroundEnd, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      ambientPink: Color.lerp(ambientPink, other.ambientPink, t)!,
      ambientOrange: Color.lerp(ambientOrange, other.ambientOrange, t)!,
      ambientBlue: Color.lerp(ambientBlue, other.ambientBlue, t)!,
      ambientAccent: Color.lerp(ambientAccent, other.ambientAccent, t)!,
      glassBase: Color.lerp(glassBase, other.glassBase, t)!,
      glassStrong: Color.lerp(glassStrong, other.glassStrong, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      bilibili: Color.lerp(bilibili, other.bilibili, t)!,
      douyu: Color.lerp(douyu, other.douyu, t)!,
      huya: Color.lerp(huya, other.huya, t)!,
      douyin: Color.lerp(douyin, other.douyin, t)!,
      twitch: Color.lerp(twitch, other.twitch, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}
