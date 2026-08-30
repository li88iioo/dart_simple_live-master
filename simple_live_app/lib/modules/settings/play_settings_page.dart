import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_menu.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';

class PlaySettingsPage extends GetView<AppSettingsController> {
  const PlaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('直播间设置'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _SettingsPageBody(
        children: [
          const _SectionLabel(
            title: '播放器',
            description: '控制解码方式、画面比例与后台播放行为',
            first: true,
          ),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => SettingsSwitch(
                    title: '硬件解码',
                    value: controller.hardwareDecode.value,
                    subtitle: '播放失败可尝试关闭此选项',
                    onChanged: controller.setHardwareDecode,
                  ),
                ),
                if (Platform.isAndroid) ...[
                  const _SettingsDivider(),
                  Obx(
                    () => SettingsSwitch(
                      title: '兼容模式',
                      subtitle: '若播放卡顿可尝试打开此选项',
                      value: controller.playerCompatMode.value,
                      onChanged: controller.setPlayerCompatMode,
                    ),
                  ),
                ],
                const _SettingsDivider(),
                Obx(
                  () => SettingsSwitch(
                    title: '进入后台自动暂停',
                    value: controller.playerAutoPause.value,
                    onChanged: controller.setPlayerAutoPause,
                  ),
                ),
                const _SettingsDivider(),
                Obx(
                  () => SettingsMenu<int>(
                    title: '画面尺寸',
                    value: controller.scaleMode.value,
                    valueMap: const {
                      0: '适应',
                      1: '拉伸',
                      2: '铺满',
                      3: '16:9',
                      4: '4:3',
                    },
                    onChanged: controller.setScaleMode,
                  ),
                ),
                const _SettingsDivider(),
                Obx(
                  () => SettingsSwitch(
                    title: '使用 HTTPS 链接',
                    subtitle: '将 http 播放地址替换为 https',
                    value: controller.playerForceHttps.value,
                    onChanged: controller.setPlayerForceHttps,
                  ),
                ),
                const _SettingsDivider(),
                Obx(
                  () => SettingsSwitch(
                    title: '抖音 HLS 流优先',
                    subtitle: 'HLS 流可缓解部分直播间抖动问题，重启后生效',
                    value: controller.douyinHlsFirst.value,
                    onChanged: controller.setDouyinHlsFirst,
                  ),
                ),
              ],
            ),
          ),
          const _SectionLabel(
            title: '直播间',
            description: '设置进入直播间与系统小窗时的默认行为',
          ),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => SettingsSwitch(
                    title: '进入直播间自动全屏',
                    value: controller.autoFullScreen.value,
                    onChanged: controller.setAutoFullScreen,
                  ),
                ),
                if (Platform.isAndroid) ...[
                  const _SettingsDivider(),
                  Obx(
                    () => SettingsSwitch(
                      title: '进入小窗隐藏弹幕',
                      value: controller.pipHideDanmu.value,
                      onChanged: controller.setPIPHideDanmu,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const _SectionLabel(
            title: '清晰度',
            description: '分别为 Wi-Fi 与移动数据网络选择默认画质',
          ),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => SettingsMenu<int>(
                    title: '默认清晰度',
                    value: controller.qualityLevel.value,
                    valueMap: const {
                      0: '最低',
                      1: '中等',
                      2: '最高',
                    },
                    onChanged: controller.setQualityLevel,
                  ),
                ),
                const _SettingsDivider(),
                Obx(
                  () => SettingsMenu<int>(
                    title: '数据网络清晰度',
                    value: controller.qualityLevelCellular.value,
                    valueMap: const {
                      0: '最低',
                      1: '中等',
                      2: '最高',
                    },
                    onChanged: controller.setQualityLevelCellular,
                  ),
                ),
              ],
            ),
          ),
          const _SectionLabel(
            title: '聊天区',
            description: '调整聊天文本密度与柔润气泡样式',
          ),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => SettingsNumber(
                    title: '文字大小',
                    value: controller.chatTextSize.value.toInt(),
                    min: 8,
                    max: 36,
                    onChanged: (value) {
                      controller.setChatTextSize(value.toDouble());
                    },
                  ),
                ),
                const _SettingsDivider(),
                Obx(
                  () => SettingsNumber(
                    title: '上下间隔',
                    value: controller.chatTextGap.value.toInt(),
                    min: 0,
                    max: 12,
                    onChanged: (value) {
                      controller.setChatTextGap(value.toDouble());
                    },
                  ),
                ),
                const _SettingsDivider(),
                Obx(
                  () => SettingsSwitch(
                    title: '气泡样式',
                    value: controller.chatBubbleStyle.value,
                    onChanged: controller.setChatBubbleStyle,
                  ),
                ),
              ],
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
