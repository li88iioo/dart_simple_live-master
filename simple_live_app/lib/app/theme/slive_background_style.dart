import 'package:flutter/material.dart';

/// 背景颜色来源。
///
/// [id] 会写入本地配置，必须保持稳定，避免枚举顺序调整破坏旧数据。
enum SliveBackgroundSource {
  systemDynamic(
    id: 'dynamic',
    label: '系统动态',
    description: '使用壁纸提取的中性色；设备不支持时回退暖瓷米霜',
  ),
  preset(
    id: 'preset',
    label: '内置预设',
    description: '使用 Slive 调校的低饱和柔润浅色',
  ),
  custom(
    id: 'custom',
    label: '自定义',
    description: '手动选择高明度、低饱和的安全背景色',
  );

  const SliveBackgroundSource({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  static SliveBackgroundSource fromId(String? id) {
    return SliveBackgroundSource.values.firstWhere(
      (source) => source.id == id,
      orElse: () => SliveBackgroundSource.preset,
    );
  }
}

/// Slive 内置浅色背景。
///
/// 每个预设使用稳定 [id] 持久化，颜色独立于强调色，避免大面积背景与
/// 选中态、按钮和链接争夺视觉层级。
enum SliveBackgroundPreset {
  warmPorcelain(
    id: 'warmPorcelain',
    label: '暖瓷米霜',
    description: '温润米霜白，保留 Slive 现有视觉',
    start: Color(0xFFFAF7F2),
    base: Color(0xFFF6F3ED),
    end: Color(0xFFF0EBE2),
  ),
  mistBlue(
    id: 'mistBlue',
    label: '雾蓝灰',
    description: '清透克制的低饱和蓝灰',
    start: Color(0xFFF8FAFB),
    base: Color(0xFFF1F4F6),
    end: Color(0xFFE8EEF2),
  ),
  sageMilk(
    id: 'sageMilk',
    label: '鼠尾草奶白',
    description: '安静柔和的低饱和草木奶白',
    start: Color(0xFFFAFAF6),
    base: Color(0xFFF2F4EE),
    end: Color(0xFFE7ECE2),
  );

  const SliveBackgroundPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.start,
    required this.base,
    required this.end,
  });

  final String id;
  final String label;
  final String description;
  final Color start;
  final Color base;
  final Color end;

  SliveBackgroundPalette get lightPalette => SliveBackgroundPalette(
        start: start,
        base: base,
        end: end,
      );

  static SliveBackgroundPreset fromId(String? id) {
    return SliveBackgroundPreset.values.firstWhere(
      (preset) => preset.id == id,
      orElse: () => SliveBackgroundPreset.warmPorcelain,
    );
  }
}

/// 页面背景使用的三段柔和渐变色板。
@immutable
class SliveBackgroundPalette {
  const SliveBackgroundPalette({
    required this.start,
    required this.base,
    required this.end,
  });

  final Color start;
  final Color base;
  final Color end;

  /// 从任意颜色生成安全的浅色背景。
  ///
  /// 最终颜色被约束为高明度、低饱和，以保证深色正文和玻璃层级可读。
  factory SliveBackgroundPalette.fromLightBase(Color color) {
    final safeBase = SliveBackgroundStyle.normalizeLightColor(color);
    final hsl = HSLColor.fromColor(safeBase);
    final startLightness = (hsl.lightness + 0.026).clamp(0.90, 0.985);
    final endLightness = (hsl.lightness - 0.038).clamp(0.86, 0.94);

    return SliveBackgroundPalette(
      start: hsl
          .withSaturation(hsl.saturation * 0.66)
          .withLightness(startLightness.toDouble())
          .toColor(),
      base: safeBase,
      end: hsl
          .withSaturation(hsl.saturation * 0.88)
          .withLightness(endLightness.toDouble())
          .toColor(),
    );
  }

  /// 根据背景色相派生低饱和深色，避免把浅色背景直接压暗后产生脏色。
  factory SliveBackgroundPalette.darkFrom(Color color) {
    final hsl = HSLColor.fromColor(color);
    final saturation = hsl.saturation.clamp(0.0, 0.10).toDouble();

    return SliveBackgroundPalette(
      start: HSLColor.fromAHSL(
        1,
        hsl.hue,
        saturation * 0.64,
        0.075,
      ).toColor(),
      base: HSLColor.fromAHSL(
        1,
        hsl.hue,
        saturation * 0.82,
        0.102,
      ).toColor(),
      end: HSLColor.fromAHSL(
        1,
        hsl.hue,
        saturation,
        0.142,
      ).toColor(),
    );
  }
}

/// 可持久化的 Slive 背景选择。
@immutable
class SliveBackgroundStyle {
  const SliveBackgroundStyle({
    this.source = SliveBackgroundSource.preset,
    this.preset = SliveBackgroundPreset.warmPorcelain,
    this.customColor = defaultCustomColor,
  });

  static const Color defaultCustomColor = Color(0xFFF1F4F3);

  final SliveBackgroundSource source;
  final SliveBackgroundPreset preset;
  final Color customColor;

  /// 解析最终背景色板。
  ///
  /// 当 [source] 为系统动态时，主应用应把系统 ColorScheme 的 surface
  /// 中性色传入 [dynamicSurface]。若设备不支持动态颜色，则安全回退到
  /// 暖瓷米霜，而不会错误地用强调色充当背景。
  SliveBackgroundPalette resolve(
    Brightness brightness, {
    Color? dynamicSurface,
  }) {
    final lightPalette = switch (source) {
      SliveBackgroundSource.systemDynamic => dynamicSurface == null
          ? SliveBackgroundPreset.warmPorcelain.lightPalette
          : SliveBackgroundPalette.fromLightBase(dynamicSurface),
      SliveBackgroundSource.preset => preset.lightPalette,
      SliveBackgroundSource.custom =>
        SliveBackgroundPalette.fromLightBase(customColor),
    };

    if (brightness == Brightness.light) {
      return lightPalette;
    }
    return SliveBackgroundPalette.darkFrom(lightPalette.base);
  }

  /// 将用户输入约束为不抢强调色层级的安全浅色。
  static Color normalizeLightColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return HSLColor.fromAHSL(
      1,
      hsl.hue,
      hsl.saturation.clamp(0.0, 0.15).toDouble(),
      hsl.lightness.clamp(0.88, 0.96).toDouble(),
    ).toColor();
  }

  /// Flutter Color 到稳定 ARGB int，避免依赖已弃用的 `Color.value`。
  static int colorToArgb(Color color) {
    int channel(double value) => (value * 255.0).round().clamp(0, 255).toInt();

    return channel(color.a) << 24 |
        channel(color.r) << 16 |
        channel(color.g) << 8 |
        channel(color.b);
  }
}
