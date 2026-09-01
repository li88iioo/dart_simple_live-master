import 'package:flutter/material.dart';

/// 虎牙聊天身份牌的公共视觉 token。
///
/// 粉丝牌保留横向等级牌，爵位采用更轻的小方印；两者共享字阶与垂直基线，
/// 但使用独立色板，避免把粉丝牌等级色误当作虎牙爵位色。
abstract final class HuyaChatBadgeStyle {
  static const double radius = 4;
  static const double badgeToBadgeGap = 3;
  static const double badgeToTextGap = 5;
  static const double outlineWidth = 0.55;

  static double height(double fontSize) =>
      (fontSize + 4).clamp(18.0, 20.0).toDouble();

  static double labelFontSize(double fontSize) =>
      (fontSize - 3).clamp(9.5, 11.0).toDouble();

  static double compactFontSize(double fontSize) =>
      (fontSize - 3.2).clamp(9.3, 10.2).toDouble();
}

@immutable
class HuyaChatBadgePalette {
  const HuyaChatBadgePalette({
    required this.leading,
    required this.bodyStart,
    required this.bodyEnd,
  });

  final Color leading;
  final Color bodyStart;
  final Color bodyEnd;
}

/// 粉丝牌六档低饱和色阶。
HuyaChatBadgePalette huyaChatBadgePaletteForTier(int tier) {
  return switch (tier.clamp(1, 6)) {
    6 => const HuyaChatBadgePalette(
        leading: Color(0xFFB64C3D),
        bodyStart: Color(0xFFD96948),
        bodyEnd: Color(0xFFE58B55),
      ),
    5 => const HuyaChatBadgePalette(
        leading: Color(0xFF9A5A32),
        bodyStart: Color(0xFFC17B3E),
        bodyEnd: Color(0xFFD9A259),
      ),
    4 => const HuyaChatBadgePalette(
        leading: Color(0xFF9E496F),
        bodyStart: Color(0xFFBE5F8A),
        bodyEnd: Color(0xFFD77BA2),
      ),
    3 => const HuyaChatBadgePalette(
        leading: Color(0xFF6556A7),
        bodyStart: Color(0xFF7B69BE),
        bodyEnd: Color(0xFF9A87D2),
      ),
    2 => const HuyaChatBadgePalette(
        leading: Color(0xFF367F8A),
        bodyStart: Color(0xFF4697A0),
        bodyEnd: Color(0xFF69B2B8),
      ),
    _ => const HuyaChatBadgePalette(
        leading: Color(0xFF416E9E),
        bodyStart: Color(0xFF5685B5),
        bodyEnd: Color(0xFF78A1C8),
      ),
  };
}

/// 虎牙爵位固定配色：剑士土、骑士绿、领主蓝、公爵红、君王紫、帝皇金。
HuyaChatBadgePalette huyaNobleBadgePaletteForLevel(int level) {
  return switch (level.clamp(1, 6)) {
    6 => const HuyaChatBadgePalette(
        leading: Color(0xFF7D601F),
        bodyStart: Color(0xFFA17D32),
        bodyEnd: Color(0xFFC4A252),
      ),
    5 => const HuyaChatBadgePalette(
        leading: Color(0xFF584574),
        bodyStart: Color(0xFF70598F),
        bodyEnd: Color(0xFF8D74A8),
      ),
    4 => const HuyaChatBadgePalette(
        leading: Color(0xFF813F3D),
        bodyStart: Color(0xFF9C524F),
        bodyEnd: Color(0xFFBC706A),
      ),
    3 => const HuyaChatBadgePalette(
        leading: Color(0xFF345F85),
        bodyStart: Color(0xFF46769D),
        bodyEnd: Color(0xFF668FB1),
      ),
    2 => const HuyaChatBadgePalette(
        leading: Color(0xFF2F665A),
        bodyStart: Color(0xFF417D6F),
        bodyEnd: Color(0xFF609888),
      ),
    _ => const HuyaChatBadgePalette(
        leading: Color(0xFF665548),
        bodyStart: Color(0xFF806B59),
        bodyEnd: Color(0xFF9A826D),
      ),
  };
}

Color huyaNobleBadgeForegroundForLevel(int level) {
  return switch (level.clamp(1, 6)) {
    1 => const Color(0xFFFFF8EE),
    2 => const Color(0xFFF3FFF9),
    3 => const Color(0xFFF5FAFF),
    4 => const Color(0xFFFFF7F5),
    5 => const Color(0xFFFCF8FF),
    _ => const Color(0xFFFFF9E8),
  };
}

int huyaFansBadgeTier(int level) {
  if (level >= 26) return 6;
  if (level >= 21) return 5;
  if (level >= 16) return 4;
  if (level >= 11) return 3;
  if (level >= 6) return 2;
  return 1;
}
