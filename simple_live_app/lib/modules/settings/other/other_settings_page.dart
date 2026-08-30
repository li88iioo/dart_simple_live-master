import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/settings/other/other_settings_controller.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_menu.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';
import 'package:url_launcher/url_launcher_string.dart';

class OtherSettingsPage extends GetView<OtherSettingsController> {
  const OtherSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('其他设置'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _SettingsPageBody(
        children: [
          const _SectionLabel(
            title: '配置管理',
            description: '导入、导出或恢复 Slive 的本地设置',
            first: true,
          ),
          SettingsCard(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _ConfigActions(
                actions: [
                  _ConfigActionData(
                    label: '导出配置',
                    icon: Remix.export_line,
                    onPressed: controller.exportConfig,
                  ),
                  _ConfigActionData(
                    label: '导入配置',
                    icon: Remix.import_line,
                    onPressed: controller.importConfig,
                  ),
                  _ConfigActionData(
                    label: '重置配置',
                    icon: Remix.restart_line,
                    onPressed: controller.resetDefaultConfig,
                  ),
                ],
              ),
            ),
          ),
          const _SectionLabel(
            title: '播放器高级设置',
            description: '仅在了解 MPV 参数含义时调整以下选项',
          ),
          SliveGlassSurface(
            variant: SliveGlassVariant.card,
            enableBackdropBlur: false,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: context.sliveColors.huya,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '错误的输出驱动或硬件解码参数可能导致无法播放。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.sliveColors.textSecondary,
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: 3),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(44, 44),
                        ),
                        onPressed: () {
                          launchUrlString(
                            'https://mpv.io/manual/stable/#video-output-drivers',
                          );
                        },
                        child: const Text('查看 MPV 文档'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => SettingsSwitch(
                    value:
                        AppSettingsController.instance.customPlayerOutput.value,
                    title: '自定义输出驱动与硬件加速',
                    onChanged:
                        AppSettingsController.instance.setCustomPlayerOutput,
                  ),
                ),
                const _SettingsDivider(),
                Obx(
                  () => SettingsMenu(
                    title: '视频输出驱动（--vo）',
                    value:
                        AppSettingsController.instance.videoOutputDriver.value,
                    valueMap: controller.videoOutputDrivers,
                    onChanged:
                        AppSettingsController.instance.setVideoOutputDriver,
                  ),
                ),
                const _SettingsDivider(),
                Obx(
                  () => SettingsMenu(
                    title: '音频输出驱动（--ao）',
                    value:
                        AppSettingsController.instance.audioOutputDriver.value,
                    valueMap: controller.audioOutputDrivers,
                    onChanged:
                        AppSettingsController.instance.setAudioOutputDriver,
                  ),
                ),
                const _SettingsDivider(),
                Obx(
                  () => SettingsMenu(
                    title: '硬件解码器（--hwdec）',
                    value: AppSettingsController
                        .instance.videoHardwareDecoder.value,
                    valueMap: controller.hardwareDecoder,
                    onChanged:
                        AppSettingsController.instance.setVideoHardwareDecoder,
                  ),
                ),
                const _SettingsDivider(),
                Obx(
                  () => SettingsSwitch(
                    value: AppSettingsController
                        .instance.videoDoubleBuffering.value,
                    title: '自定义开启双重缓存',
                    onChanged:
                        AppSettingsController.instance.setVideoDoubleBuffering,
                  ),
                ),
              ],
            ),
          ),
          const _SectionLabel(
            title: '日志记录',
            description: '仅在排查问题时开启，避免持续写入带来的额外功耗',
          ),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => SettingsSwitch(
                    value: AppSettingsController.instance.logEnable.value,
                    title: '开启日志记录',
                    subtitle: '记录调试日志，可将日志文件提供给开发者排查问题',
                    onChanged: controller.setLogEnable,
                  ),
                ),
                if (Platform.isAndroid) ...[
                  const _SettingsDivider(),
                  Obx(
                    () => SettingsSwitch(
                      value:
                          AppSettingsController.instance.firebaseEnable.value,
                      title: '开启崩溃分析',
                      subtitle: '应用崩溃时自动上传脱敏日志以协助排查问题',
                      onChanged: controller.setFirebaseEnable,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _SectionHeaderAction(
            title: '日志列表',
            description: '日志区域保持固定高度，刷新文件时不会造成页面跳动',
            onPressed: controller.cleanLog,
          ),
          SettingsCard(
            child: SizedBox(
              height: 320,
              child: Obx(() {
                final logs = controller.logFiles;
                if (logs.isEmpty) {
                  return const _EmptyLogs();
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const _SettingsDivider(),
                  itemBuilder: (context, index) {
                    final item = logs[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                      title: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(Utils.parseFileSize(item.size)),
                      trailing: SizedBox(
                        width: Platform.isLinux ? 44 : 88,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!Platform.isLinux)
                              Tooltip(
                                message: '分享日志',
                                child: IconButton(
                                  constraints: const BoxConstraints.tightFor(
                                    width: 44,
                                    height: 44,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    controller.shareLogFile(item);
                                  },
                                  icon: const Icon(Icons.share_outlined),
                                ),
                              ),
                            Tooltip(
                              message: '保存日志',
                              child: IconButton(
                                constraints: const BoxConstraints.tightFor(
                                  width: 44,
                                  height: 44,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  controller.saveLogFile(item);
                                },
                                icon: const Icon(Icons.save_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
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

class _SectionHeaderAction extends StatelessWidget {
  const _SectionHeaderAction({
    required this.title,
    required this.description,
    required this.onPressed,
  });

  final String title;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 26, 4, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.sliveColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.sliveColors.textTertiary,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.clear_all_rounded, size: 19),
            label: const Text('清空'),
          ),
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

class _ConfigActionData {
  const _ConfigActionData({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

class _ConfigActions extends StatelessWidget {
  const _ConfigActions({required this.actions});

  final List<_ConfigActionData> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final columns = textScale > 1.25 && constraints.maxWidth < 520
            ? 1
            : constraints.maxWidth >= 520
                ? 3
                : constraints.maxWidth >= 300
                    ? 2
                    : 1;
        const spacing = 8.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions
              .map(
                (action) => SizedBox(
                  width: itemWidth,
                  height: 52,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SliveRadii.control),
                      ),
                    ),
                    onPressed: action.onPressed,
                    icon: Icon(action.icon, size: 20),
                    label: Text(action.label),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _EmptyLogs extends StatelessWidget {
  const _EmptyLogs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            color: context.sliveColors.textTertiary,
          ),
          const SizedBox(height: 8),
          Text(
            '暂无日志文件',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.sliveColors.textTertiary,
                ),
          ),
        ],
      ),
    );
  }
}
