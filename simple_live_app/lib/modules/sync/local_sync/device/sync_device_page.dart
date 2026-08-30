import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/sync/local_sync/device/sync_device_controller.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class SyncDevicePage extends GetView<SyncDeviceController> {
  const SyncDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final accent = Theme.of(context).colorScheme.primary;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;

    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('同步'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          SliveLayout.pageHorizontal,
          4,
          SliveLayout.pageHorizontal,
          bottomPadding,
        ),
        children: [
          Text(
            '目标设备',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          SettingsCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _DeviceIconBox(
                    icon: _deviceIcon(controller.info.type),
                    color: accent,
                    size: 54,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.info.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          controller.info.type.toUpperCase(),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          controller.info.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '选择同步内容',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SyncActionTile(
                  icon: Remix.heart_line,
                  color: context.sliveColors.bilibili,
                  title: '同步关注列表',
                  subtitle: '包含关注用户与标签',
                  onTap: controller.syncFollowAndTag,
                ),
                const _DeviceDivider(),
                _SyncActionTile(
                  icon: Icons.history_rounded,
                  color: colors.huya,
                  title: '同步观看记录',
                  subtitle: '发送本机观看历史',
                  onTap: controller.syncHistory,
                ),
                const _DeviceDivider(),
                _SyncActionTile(
                  icon: Remix.shield_keyhole_line,
                  color: colors.success,
                  title: '同步弹幕屏蔽词',
                  subtitle: '发送当前屏蔽规则',
                  onTap: controller.syncBlockedWord,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncActionTile extends StatelessWidget {
  const _SyncActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 11,
      leading: _DeviceIconBox(icon: icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.sliveColors.textTertiary,
      ),
      onTap: onTap,
    );
  }
}

class _DeviceIconBox extends StatelessWidget {
  const _DeviceIconBox({
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

class _DeviceDivider extends StatelessWidget {
  const _DeviceDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 0.7,
      indent: 70,
      endIndent: 14,
      color: colors.divider.withValues(alpha: isDark ? 0.14 : 0.09),
    );
  }
}

IconData _deviceIcon(String type) {
  return switch (type.toLowerCase()) {
    'android' => Remix.android_line,
    'ios' => Remix.apple_line,
    'tv' => Remix.tv_2_line,
    'windows' => Remix.microsoft_fill,
    'macos' => Remix.mac_line,
    'linux' => Remix.ubuntu_line,
    _ => Remix.device_line,
  };
}
