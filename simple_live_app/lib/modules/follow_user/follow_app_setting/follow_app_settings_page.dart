import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/modules/follow_user/follow_app_setting/follow_app_settings_controller.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_menu_check.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';

class FollowSettingsPage extends GetView<FollowAppSettingsController> {
  const FollowSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('关注设置'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _SettingsPageBody(
        children: [
          const _SectionLabel(
            title: '标签管理',
            description: '整理关注用户与自定义分组',
            first: true,
          ),
          SettingsCard(
            child: SettingsAction(
              title: '标签管理',
              onTap: controller.showTagsManager,
            ),
          ),
          const _SectionLabel(
            title: '关注清理',
            description: '按观看记录筛选低活跃关注，确认后再执行清理',
          ),
          SettingsCard(
            child: SettingsMenuCheck<FollowUser>(
              title: '选择要清理的用户',
              subtitle: '默认条件：观看时长低于 30 分钟，且位于历史观看底部 15 名',
              confirmText: '清理',
              itemToString: (user) => user.userName,
              itemsProvider: () async => controller.buildAutoCleanPool(),
              onConfirm: controller.cleanFollow,
            ),
          ),
          const _SectionLabel(
            title: '显示与快照',
            description: '控制离线用户、快捷操作与短时直播状态恢复',
          ),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => SettingsSwitch(
                    value: controller.appC.hideOfflineFollow.value,
                    title: '隐藏离线关注',
                    onChanged: controller.setFollowSetting,
                  ),
                ),
                const _SettingsDivider(),
                Obx(
                  () => SettingsSwitch(
                    value: controller.appC.hideRemoveFollowButton.value,
                    title: '隐藏快速取关按钮',
                    onChanged: controller.setRemoveFollowButton,
                  ),
                ),
                const _SettingsDivider(),
                Obx(
                  () => SettingsSwitch(
                    value: controller.appC.followSnapshotEnable.value,
                    title: '直播状态快照',
                    subtitle: '恢复短时间内直播状态，降低风控风险',
                    onChanged: controller.appC.setFollowSnapshotEnable,
                  ),
                ),
              ],
            ),
          ),
          const _SectionLabel(
            title: '自动更新',
            description: '控制后台刷新节奏；更短间隔和更多线程会增加功耗与风控风险',
          ),
          SettingsCard(
            child: Obx(() {
              final enabled = controller.appC.autoUpdateFollowEnable.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SettingsSwitch(
                    value: enabled,
                    title: '自动更新关注直播状态',
                    onChanged: (value) {
                      controller.appC.setAutoUpdateFollowEnable(value);
                      FollowService.instance.initTimer();
                    },
                  ),
                  if (enabled) ...[
                    const _SettingsDivider(),
                    SettingsAction(
                      title: '自动更新间隔',
                      value:
                          '${controller.appC.autoUpdateFollowDuration.value ~/ 60}小时${controller.appC.autoUpdateFollowDuration.value % 60}分钟',
                      onTap: () => setTimer(context),
                    ),
                  ],
                  const _SettingsDivider(),
                  SettingsNumber(
                    value: controller.appC.updateFollowThreadCount.value,
                    title: '更新线程数',
                    subtitle: '多线程可能更快，但请求过于频繁时可能读取状态失败',
                    min: 1,
                    max: 12,
                    onChanged: controller.appC.setUpdateFollowThreadCount,
                  ),
                ],
              );
            }),
          ),
          const _SectionLabel(
            title: '关注导入导出',
            description: '通过文件或文本迁移本地关注数据',
          ),
          fileImportAndExportBuild(),
          const _SectionLabel(
            title: '数据校准',
            description: '仅在关注或标签数据错乱时使用，请勿重复点击',
          ),
          SettingsCard(
            child: SettingsAction(
              title: '数据校准',
              subtitle: '重新整理关注与标签关联数据',
              onTap: controller.followDataCheck,
            ),
          ),
        ],
      ),
    );
  }

  Widget fileImportAndExportBuild() {
    return SettingsCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsAction(
            leading: const _SoftActionIcon(icon: Remix.save_2_line),
            title: '导出文件',
            onTap: FollowService.instance.exportFile,
          ),
          const _SettingsDivider(indent: 68),
          SettingsAction(
            leading: const _SoftActionIcon(icon: Remix.folder_open_line),
            title: '导入文件',
            onTap: FollowService.instance.inputFile,
          ),
          const _SettingsDivider(indent: 68),
          SettingsAction(
            leading: const _SoftActionIcon(icon: Remix.text),
            title: '导出文本',
            onTap: FollowService.instance.exportText,
          ),
          const _SettingsDivider(indent: 68),
          SettingsAction(
            leading: const _SoftActionIcon(icon: Remix.file_text_line),
            title: '导入文本',
            onTap: FollowService.instance.inputText,
          ),
        ],
      ),
    );
  }

  void setTimer(BuildContext context) async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: controller.appC.autoUpdateFollowDuration.value ~/ 60,
        minute: controller.appC.autoUpdateFollowDuration.value % 60,
      ),
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (_, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );
    if (value == null || (value.hour == 0 && value.minute == 0)) {
      return;
    }
    final duration = Duration(hours: value.hour, minutes: value.minute);
    controller.appC.setAutoUpdateFollowDuration(duration.inMinutes);
    FollowService.instance.initTimer();
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
  const _SettingsDivider({this.indent = 16});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: indent,
      endIndent: 16,
      color: context.sliveColors.divider.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.10,
      ),
    );
  }
}

class _SoftActionIcon extends StatelessWidget {
  const _SoftActionIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.10,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: context.sliveColors.glassBorder.withValues(alpha: 0.42),
        ),
      ),
      child: Icon(icon, size: 20, color: primary),
    );
  }
}
