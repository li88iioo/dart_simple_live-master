import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/settings/appstyle_settings/appstyle_setting_contorller.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_menu.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';

class AppStyleSettingPage extends GetView<AppStyleSettingController> {
  const AppStyleSettingPage({super.key});

  Widget _fontIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
        iconSize: 22,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }

  Widget trailingBuild({required Widget action}) {
    final isDownloaded = controller.fontState.value == DownloadState.downloaded;
    return SizedBox(
      width: 132,
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _fontIconButton(
            tooltip: '重置为默认字体',
            icon: Icons.settings_backup_restore_outlined,
            onPressed: controller.fontReset,
          ),
          Visibility(
            visible: isDownloaded,
            maintainAnimation: true,
            maintainSize: true,
            maintainState: true,
            child: _fontIconButton(
              tooltip: '删除字体',
              icon: Icons.delete_outline_rounded,
              onPressed: controller.fontDelete,
            ),
          ),
          SizedBox.square(
            dimension: 44,
            child: Center(child: action),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomBackgroundPicker(BuildContext context) async {
    final color = await showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _BackgroundColorPickerSheet(
        initialColor: Color(controller.customBackgroundColor.value),
      ),
    );
    if (color != null) {
      await controller.setCustomBackgroundColor(color);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('外观设置'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _SettingsPageBody(
        children: [
          const _SectionLabel(
            title: '显示主题',
            description: '跟随系统，或固定使用柔润浅色与深色外观',
            first: true,
          ),
          SettingsCard(
            child: Obx(
              () => RadioGroup<int>(
                groupValue: AppSettingsController.instance.themeMode.value,
                onChanged: (value) {
                  controller.setTheme(value ?? 0);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RadioListTile<int>(
                      title: Text('跟随系统'),
                      value: 0,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    const _SettingsDivider(),
                    const RadioListTile<int>(
                      title: Text('浅色模式'),
                      value: 1,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    const _SettingsDivider(),
                    const RadioListTile<int>(
                      title: Text('深色模式'),
                      value: 2,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const _SectionLabel(
            title: '玻璃材质',
            description: '材质渲染不依赖 Android 版本；柔和模式优先流畅与续航',
          ),
          SettingsCard(
            child: Obx(
              () => SettingsMenu<SliveGlassMode>(
                title: '材质倾向',
                subtitle: controller.glassMode.value.description,
                value: controller.glassMode.value,
                valueMap: const {
                  SliveGlassMode.clear: '通透',
                  SliveGlassMode.soft: '柔和',
                },
                onChanged: (mode) {
                  controller.setGlassMode(mode);
                },
              ),
            ),
          ),
          const _SectionLabel(
            title: '强调色',
            description: '用于按钮、选中态和环境光，不会直接染色页面背景',
          ),
          SettingsCard(
            child: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSwitch(
                    value: controller.isDynamic.value,
                    title: '强调色跟随系统',
                    subtitle: '从壁纸提取控件强调色；关闭后使用下方手动颜色',
                    onChanged: controller.setIsDynamic,
                  ),
                  if (!controller.isDynamic.value) ...[
                    const _SettingsDivider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: const <Color>[
                          Color(0xFFEF5350),
                          Color(0xFF3498DB),
                          Color(0xFFF06292),
                          Color(0xFF9575CD),
                          Color(0xFF26C6DA),
                          Color(0xFF26A69A),
                          Color(0xFFFFF176),
                          Color(0xFFFF9800),
                        ]
                            .map(
                              (color) => _ThemeColorSwatch(
                                color: color,
                                selected:
                                    controller.styleColor.value == color.v,
                                onTap: () => controller.setAccentColor(color.v),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const _SectionLabel(
            title: '浅色背景',
            description: '背景与强调色独立，保持低饱和和稳定的文字对比度',
          ),
          SettingsCard(
            child: Obx(
              () {
                final source = controller.backgroundSource.value;
                final customColor =
                    Color(controller.customBackgroundColor.value);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RadioGroup<SliveBackgroundSource>(
                      groupValue: source,
                      onChanged: (value) {
                        if (value != null) {
                          controller.setBackgroundSource(value);
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var index = 0;
                              index < SliveBackgroundSource.values.length;
                              index++) ...[
                            RadioListTile<SliveBackgroundSource>(
                              value: SliveBackgroundSource.values[index],
                              title: Text(
                                SliveBackgroundSource.values[index].label,
                              ),
                              subtitle: Text(
                                SliveBackgroundSource.values[index].description,
                              ),
                              secondary: _BackgroundSourceBadge(
                                source: SliveBackgroundSource.values[index],
                                customColor: customColor,
                                preset: controller.backgroundPreset.value,
                              ),
                              contentPadding:
                                  const EdgeInsets.fromLTRB(12, 2, 16, 2),
                            ),
                            if (index !=
                                SliveBackgroundSource.values.length - 1)
                              const _SettingsDivider(),
                          ],
                        ],
                      ),
                    ),
                    if (source == SliveBackgroundSource.preset) ...[
                      const _SettingsDivider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final itemWidth = (constraints.maxWidth - 20) / 3;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: SliveBackgroundPreset.values
                                  .map(
                                    (preset) => _BackgroundPresetTile(
                                      preset: preset,
                                      width: itemWidth,
                                      selected:
                                          controller.backgroundPreset.value ==
                                              preset,
                                      onTap: () => controller
                                          .setBackgroundPreset(preset),
                                    ),
                                  )
                                  .toList(growable: false),
                            );
                          },
                        ),
                      ),
                    ],
                    if (source == SliveBackgroundSource.custom) ...[
                      const _SettingsDivider(),
                      _CustomBackgroundTile(
                        color: customColor,
                        onTap: () => _showCustomBackgroundPicker(context),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const _SectionLabel(
            title: '字体设置',
            description: '下载、应用或恢复 Slive 的界面字体',
          ),
          SettingsCard(
            child: Obx(
              () => SettingsMenu(
                title: controller.curFontModel.value!.name,
                value: controller.curFontModel.value!,
                valueMap: controller.fontMap,
                onChanged: controller.onFontSelected,
                trailing: Obx(() {
                  return switch (controller.fontState.value) {
                    DownloadState.notDownloaded => trailingBuild(
                        action: _fontIconButton(
                          tooltip: '下载字体',
                          icon: Icons.download_rounded,
                          onPressed: controller.downloadFont,
                        ),
                      ),
                    DownloadState.downloading => trailingBuild(
                        action: const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    DownloadState.downloaded => trailingBuild(
                        action: _fontIconButton(
                          tooltip: '应用字体',
                          icon: Icons.check_circle_outline_rounded,
                          onPressed: controller.changeFontFamily,
                        ),
                      ),
                  };
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPageBody extends StatelessWidget {
  const _SettingsPageBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth > 760 ? 760.0 : constraints.maxWidth;
          final horizontalPadding = width < 360 ? 12.0 : 16.0;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  8,
                  horizontalPadding,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                children: children,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    this.description,
    this.first = false,
  });

  final String title;
  final String? description;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, first ? 4 : 26, 12, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.15,
                ),
          ),
          if (description != null) ...[
            const SizedBox(height: 3),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textTertiary,
                    height: 1.35,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: context.sliveColors.divider.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.10,
      ),
    );
  }
}

class _BackgroundSourceBadge extends StatelessWidget {
  const _BackgroundSourceBadge({
    required this.source,
    required this.customColor,
    required this.preset,
  });

  final SliveBackgroundSource source;
  final Color customColor;
  final SliveBackgroundPreset preset;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final palette = switch (source) {
      SliveBackgroundSource.systemDynamic => SliveBackgroundPalette(
          start: Color.lerp(colors.backgroundStart, colors.ambientPink, 0.16)!,
          base: Color.lerp(colors.backgroundBase, colors.ambientBlue, 0.14)!,
          end: Color.lerp(colors.backgroundEnd, colors.ambientOrange, 0.12)!,
        ),
      SliveBackgroundSource.preset => preset.lightPalette,
      SliveBackgroundSource.custom =>
        SliveBackgroundPalette.fromLightBase(customColor),
    };

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.start, palette.base, palette.end],
        ),
        border: Border.all(
          color: colors.glassBorder.withValues(alpha: 0.76),
        ),
      ),
      child: Icon(
        switch (source) {
          SliveBackgroundSource.systemDynamic => Icons.auto_awesome_rounded,
          SliveBackgroundSource.preset => Icons.palette_outlined,
          SliveBackgroundSource.custom => Icons.tune_rounded,
        },
        size: 19,
        color: colors.textSecondary.withValues(alpha: 0.78),
      ),
    );
  }
}

class _BackgroundPresetTile extends StatelessWidget {
  const _BackgroundPresetTile({
    required this.preset,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final SliveBackgroundPreset preset;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: '背景预设：${preset.label}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: width,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected
                  ? primary.withValues(alpha: 0.055)
                  : colors.glassBase.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? primary.withValues(alpha: 0.52)
                    : colors.glassBorder.withValues(alpha: 0.64),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [preset.start, preset.base, preset.end],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: selected ? 1 : 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.84),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  preset.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected ? primary : colors.textSecondary,
                        fontWeight: FontWeight.w700,
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

class _CustomBackgroundTile extends StatelessWidget {
  const _CustomBackgroundTile({
    required this.color,
    required this.onTap,
  });

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final palette = SliveBackgroundPalette.fromLightBase(color);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.start, palette.base, palette.end],
                ),
                border: Border.all(
                  color: colors.glassBorder.withValues(alpha: 0.82),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '自定义柔和背景',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '仅允许高明度与低饱和，确保内容清晰',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('调整'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundColorPickerSheet extends StatefulWidget {
  const _BackgroundColorPickerSheet({required this.initialColor});

  final Color initialColor;

  @override
  State<_BackgroundColorPickerSheet> createState() =>
      _BackgroundColorPickerSheetState();
}

class _BackgroundColorPickerSheetState
    extends State<_BackgroundColorPickerSheet> {
  late double _hue;
  late double _saturation;
  late double _lightness;

  @override
  void initState() {
    super.initState();
    final initial = HSLColor.fromColor(
      SliveBackgroundStyle.normalizeLightColor(widget.initialColor),
    );
    _hue = initial.hue;
    _saturation = initial.saturation;
    _lightness = initial.lightness;
  }

  Color get _color => HSLColor.fromAHSL(
        1,
        _hue,
        _saturation.clamp(0.0, 0.15).toDouble(),
        _lightness.clamp(0.88, 0.96).toDouble(),
      ).toColor();

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final palette = SliveBackgroundPalette.fromLightBase(_color);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '自定义浅色背景',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                '颜色会自动限制在舒适的高明度、低饱和区间，避免与强调色冲突。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 104,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [palette.start, palette.base, palette.end],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(SliveRadii.pill),
                  ),
                  child: Text(
                    '柔润背景预览',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF3E3B38),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _ColorParameterSlider(
                label: '色相',
                valueLabel: '${_hue.round()}°',
                value: _hue,
                min: 0,
                max: 360,
                activeColor: _color,
                onChanged: (value) => setState(() => _hue = value),
              ),
              _ColorParameterSlider(
                label: '饱和度',
                valueLabel: '${(_saturation * 100).round()}%',
                value: _saturation,
                min: 0,
                max: 0.15,
                activeColor: _color,
                onChanged: (value) => setState(() => _saturation = value),
              ),
              _ColorParameterSlider(
                label: '明度',
                valueLabel: '${(_lightness * 100).round()}%',
                value: _lightness,
                min: 0.88,
                max: 0.96,
                activeColor: _color,
                onChanged: (value) => setState(() => _lightness = value),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_color),
                    child: const Text('应用背景'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorParameterSlider extends StatelessWidget {
  const _ColorParameterSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                valueLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textTertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: activeColor,
            inactiveColor: colors.divider.withValues(alpha: 0.13),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ThemeColorSwatch extends StatelessWidget {
  const _ThemeColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final foreground =
        color.computeLuminance() > 0.58 ? colors.textPrimary : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: '选择强调色',
      child: Tooltip(
        message: selected ? '当前强调色' : '应用此强调色',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(SliveRadii.control),
            onTap: onTap,
            child: Ink(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SliveRadii.control),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(color, Colors.white, 0.12)!,
                    Color.lerp(color, colors.textPrimary, 0.04)!,
                  ],
                ),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.94)
                      : colors.glassBorder.withValues(alpha: 0.68),
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Icon(
                Icons.check_rounded,
                color: selected ? foreground : Colors.transparent,
                size: 21,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension ColorExt on Color {
  static int _floatToInt8(double value) {
    return (value * 255.0).round() & 0xff;
  }

  int get v =>
      _floatToInt8(a) << 24 |
      _floatToInt8(r) << 16 |
      _floatToInt8(g) << 8 |
      _floatToInt8(b);
}
