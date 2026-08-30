import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/remote_sync_webdav_controller.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class RemoteSyncWebDAVPage extends GetView<RemoteSyncWebDAVController> {
  const RemoteSyncWebDAVPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;

    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('WebDAV 同步'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          SliveLayout.pageHorizontal,
          4,
          SliveLayout.pageHorizontal,
          bottomPadding,
        ),
        children: [
          Obx(() {
            final notLogin = controller.notLogin.value;
            return SliveGlassSurface(
              variant: SliveGlassVariant.panel,
              enableBackdropBlur: true,
              constraints: const BoxConstraints(minHeight: 108),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Row(
                children: [
                  _WebDavIconBox(
                    icon: notLogin
                        ? Icons.cloud_off_outlined
                        : Icons.cloud_done_outlined,
                    color: notLogin ? colors.textTertiary : colors.success,
                    size: 54,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notLogin ? '尚未连接 WebDAV' : 'WebDAV 已连接',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          notLogin
                              ? '登录后可备份、恢复或双向同步应用数据。'
                              : controller.user.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.textSecondary,
                                    height: 1.4,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          Text(
            '同步操作',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          SettingsCard(
            child: Obx(() {
              if (controller.notLogin.value) {
                return _WebDavActionTile(
                  icon: Icons.login_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  title: '登录 WebDAV',
                  subtitle: '配置服务器地址、账号和密码',
                  onTap: () => Get.toNamed(RoutePath.kRemoteSyncWebDavConfig),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WebDavActionTile(
                    icon: Icons.account_circle_outlined,
                    color: colors.success,
                    title: '已登录',
                    subtitle: controller.user.value,
                    trailingIcon: Icons.logout_rounded,
                    onTap: controller.onLogout,
                  ),
                  const _WebDavDivider(),
                  _WebDavActionTile(
                    icon: Icons.drive_folder_upload_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    title: '云端备份目录',
                    subtitle: controller.webDavBackupDirectory.value,
                    onTap: _showEditBackupDirectory,
                  ),
                  const _WebDavDivider(),
                  _WebDavActionTile(
                    icon: Icons.cloud_upload_outlined,
                    color: colors.huya,
                    title: '上传到云端',
                    subtitle: '上次上传：${controller.lastUploadTime.value}',
                    onTap: controller.doWebDAVUpload,
                  ),
                  const _WebDavDivider(),
                  _WebDavActionTile(
                    icon: Icons.cloud_download_outlined,
                    color: colors.success,
                    title: '恢复到本地',
                    subtitle: '上次恢复：${controller.lastRecoverTime.value}',
                    trailing: _RecoveryActions(
                      onSettings: showSetting,
                    ),
                    onTap: controller.doWebDAVRecovery,
                    onLongPress: showSetting,
                  ),
                  const _WebDavDivider(),
                  _WebDavActionTile(
                    icon: Icons.cloud_sync_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    title: '双向同步数据',
                    subtitle: '上次同步：${controller.lastRecoverTime.value}',
                    onTap: controller.doWebDAVBidirectional,
                    onLongPress: showSetting,
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  void showSetting() {
    Utils.showBottomSheet(
      title: '同步选项',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: SliveGlassSurface(
          variant: SliveGlassVariant.panel,
          enableBackdropBlur: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(
                () => CheckboxListTile(
                  secondary: const Icon(Remix.heart_line),
                  title: const Text('同步关注列表'),
                  value: controller.isSyncFollows.value,
                  controlAffinity: ListTileControlAffinity.trailing,
                  onChanged: (_) => controller.changeIsSyncFollows(),
                ),
              ),
              const _WebDavDivider(indent: 56),
              Obx(
                () => CheckboxListTile(
                  secondary: const Icon(Icons.history_rounded),
                  title: const Text('同步播放历史记录'),
                  value: controller.isSyncHistories.value,
                  controlAffinity: ListTileControlAffinity.trailing,
                  onChanged: (_) => controller.changeIsSyncHistories(),
                ),
              ),
              const _WebDavDivider(indent: 56),
              Obx(
                () => CheckboxListTile(
                  secondary: const Icon(Remix.shield_keyhole_line),
                  title: const Text('同步屏蔽字'),
                  value: controller.isSyncBlockWord.value,
                  controlAffinity: ListTileControlAffinity.trailing,
                  onChanged: (_) => controller.changeIsSyncBlockWord(),
                ),
              ),
              const _WebDavDivider(indent: 56),
              Obx(
                () => CheckboxListTile(
                  secondary: const Icon(Remix.account_circle_line),
                  title: const Text('同步用户平台账号'),
                  value: controller.isSyncAccount.value,
                  controlAffinity: ListTileControlAffinity.trailing,
                  onChanged: (_) => controller.changeIsSyncAccount(),
                ),
              ),
              const _WebDavDivider(indent: 56),
              Obx(
                () => CheckboxListTile(
                  secondary: const Icon(Remix.user_settings_line),
                  title: const Text('同步用户设置'),
                  value: controller.isSyncSetting.value,
                  controlAffinity: ListTileControlAffinity.trailing,
                  onChanged: (_) => controller.changeIsSyncSetting(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditBackupDirectory() async {
    var directory = await Utils.showEditTextDialog(
      controller.webDavBackupDirectory.value,
      title: '修改远程备份文件夹',
    );
    if (directory == null || directory.isEmpty) {
      return;
    }
    controller.setWebDavBackupDirectory(newDirectory: directory);
  }
}

class _WebDavActionTile extends StatelessWidget {
  const _WebDavActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingIcon = Icons.chevron_right_rounded,
    this.trailing,
    this.onLongPress,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final IconData trailingIcon;
  final Widget? trailing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 11,
      leading: _WebDavIconBox(icon: icon, color: color),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: trailing ??
          Icon(
            trailingIcon,
            color: context.sliveColors.textTertiary,
          ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _RecoveryActions extends StatelessWidget {
  const _RecoveryActions({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '同步选项',
          onPressed: onSettings,
          icon: const Icon(Icons.tune_rounded, size: 20),
        ),
        Icon(
          Icons.chevron_right_rounded,
          color: context.sliveColors.textTertiary,
        ),
      ],
    );
  }
}

class _WebDavIconBox extends StatelessWidget {
  const _WebDavIconBox({
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.13),
        borderRadius: BorderRadius.circular(size > 48 ? 18 : 14),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

class _WebDavDivider extends StatelessWidget {
  const _WebDavDivider({this.indent = 70});

  final double indent;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 0.7,
      indent: indent,
      endIndent: 14,
      color: colors.divider.withValues(alpha: isDark ? 0.14 : 0.09),
    );
  }
}
