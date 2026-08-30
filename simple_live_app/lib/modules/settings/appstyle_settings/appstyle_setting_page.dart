import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
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
                groupValue: controller.themeMode.value,
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
            description: '通透强调环境折射，柔和降低模糊以兼顾续航',
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
                  Get.forceAppUpdate();
                },
              ),
            ),
          ),
          const _SectionLabel(
            title: '环境色',
            description: '让系统主色影响玻璃控件与环境光晕',
          ),
          SettingsCard(
            child: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSwitch(
                    value: controller.isDynamic.value,
                    title: '动态取色',
                    onChanged: (value) {
                      controller.setIsDynamic(value);
                      Get.forceAppUpdate();
                    },
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
                              (color) => Obx(
                                () => _ThemeColorSwatch(
                                  color: color,
                                  selected:
                                      controller.styleColor.value == color.v,
                                  onTap: () {
                                    controller.setStyleColor(color.v);
                                    Get.forceAppUpdate();
                                  },
                                ),
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
    final foreground =
        color.computeLuminance() > 0.58 ? Colors.black54 : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: '选择主题颜色',
      child: Tooltip(
        message: selected ? '当前主题颜色' : '应用此主题颜色',
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
                    Color.lerp(color, Colors.black, 0.06)!,
                  ],
                ),
                border: Border.all(
                  color: selected
                      ? foreground.withValues(alpha: 0.82)
                      : context.sliveColors.glassBorder.withValues(alpha: 0.58),
                  width: selected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: selected ? 0.28 : 0.14),
                    blurRadius: selected ? 14 : 8,
                    spreadRadius: -4,
                    offset: const Offset(0, 5),
                  ),
                ],
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
