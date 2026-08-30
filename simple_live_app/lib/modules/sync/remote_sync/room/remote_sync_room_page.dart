import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/sync/remote_sync/room/remote_sync_room_controller.dart';
import 'package:simple_live_app/services/signalr_service.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class RemoteSyncRoomPage extends GetView<RemoteSyncRoomController> {
  const RemoteSyncRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;

    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('数据同步'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ConnectionStatusBadge(service: controller.signalR),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          SliveLayout.pageHorizontal,
          4,
          SliveLayout.pageHorizontal,
          bottomPadding,
        ),
        children: [
          if (controller.roomId.isEmpty) ...[
            SettingsCard(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 58),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      _RemoteIconBox(
                        icon: Remix.timer_line,
                        color: colors.huya,
                        size: 38,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Obx(
                          () => Text(
                            '${controller.countDown.value} 秒后房间将会自动关闭',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          const _RemoteSectionLabel('房间号'),
          const SizedBox(height: 10),
          SliveGlassSurface(
            variant: SliveGlassVariant.panel,
            enableBackdropBlur: true,
            padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
            child: Obx(
              () => Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前同步房间',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: colors.textTertiary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          controller.currentRoomId.value,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RoomActionButton(
                    icon: Icons.copy_rounded,
                    tooltip: '复制房间号',
                    onTap: () => Utils.copyToClipboard(
                      controller.currentRoomId.value,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _RoomActionButton(
                    icon: Icons.qr_code_2_rounded,
                    tooltip: '显示二维码',
                    onTap: controller.showQRInfo,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _RemoteSectionLabel('同步数据至其他设备'),
          const SizedBox(height: 10),
          SettingsCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RemoteActionTile(
                  icon: Remix.heart_line,
                  color: colors.bilibili,
                  title: '发送关注列表',
                  onTap: controller.syncFollow,
                ),
                const _RemoteDivider(),
                _RemoteActionTile(
                  icon: Icons.history_rounded,
                  color: colors.huya,
                  title: '发送观看记录',
                  onTap: controller.syncHistory,
                ),
                const _RemoteDivider(),
                _RemoteActionTile(
                  icon: Remix.shield_keyhole_line,
                  color: colors.success,
                  title: '发送弹幕屏蔽词',
                  onTap: controller.syncBlockedWord,
                ),
                const _RemoteDivider(),
                _RemoteActionTile(
                  icon: Remix.account_circle_line,
                  color: Theme.of(context).colorScheme.primary,
                  title: '发送哔哩哔哩账号',
                  onTap: controller.syncBiliAccount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Obx(
            () => _RemoteSectionLabel(
              '已连接设备  ${controller.roomUsers.length}',
            ),
          ),
          const SizedBox(height: 10),
          SettingsCard(
            child: Obx(() {
              final users = controller.roomUsers;
              if (users.isEmpty) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 104),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 20,
                    ),
                    child: Row(
                      children: [
                        _RemoteIconBox(
                          icon: Icons.devices_other_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 46,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '等待设备加入',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '分享房间号或二维码后，设备会显示在这里。',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colors.textSecondary,
                                      height: 1.4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final localConnectionId =
                  controller.signalR.hubConnection?.connectionId;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < users.length; index++) ...[
                    if (index > 0) const _RemoteDivider(),
                    _ConnectedDeviceTile(
                      user: users[index],
                      isLocal: localConnectionId == users[index].connectionId,
                    ),
                  ],
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStatusBadge extends StatelessWidget {
  const _ConnectionStatusBadge({required this.service});

  final SignalRService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SignalRConnectionState>(
      stream: service.stateStream,
      initialData: service.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? SignalRConnectionState.connecting;
        final colors = context.sliveColors;
        final (label, color) = switch (state) {
          SignalRConnectionState.connected => ('已连接', colors.success),
          SignalRConnectionState.disconnected => ('已断开', colors.danger),
          SignalRConnectionState.connecting => (
              '连接中',
              Theme.of(context).colorScheme.primary,
            ),
        };

        return SliveGlassSurface(
          variant: SliveGlassVariant.pill,
          enableBackdropBlur: false,
          constraints: const BoxConstraints.tightFor(width: 110, height: 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 12,
                child: state == SignalRConnectionState.connecting
                    ? CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: color,
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.36),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RemoteSectionLabel extends StatelessWidget {
  const _RemoteSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: context.sliveColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _RoomActionButton extends StatelessWidget {
  const _RoomActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SliveGlassSurface(
        variant: SliveGlassVariant.pill,
        enableBackdropBlur: false,
        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        onTap: onTap,
        child: Icon(
          icon,
          size: 20,
          color: context.sliveColors.textSecondary,
        ),
      ),
    );
  }
}

class _RemoteActionTile extends StatelessWidget {
  const _RemoteActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 11,
      leading: _RemoteIconBox(icon: icon, color: color),
      title: Text(title),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.sliveColors.textTertiary,
      ),
      onTap: onTap,
    );
  }
}

class _ConnectedDeviceTile extends StatelessWidget {
  const _ConnectedDeviceTile({
    required this.user,
    required this.isLocal,
  });

  final RoomUser user;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final accent = Theme.of(context).colorScheme.primary;

    return ListTile(
      minVerticalPadding: 12,
      leading: _RemoteIconBox(
        icon: _platformIcon(user.platform),
        color: accent,
        size: 46,
      ),
      title: Wrap(
        spacing: 7,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            user.shortId,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (user.isCreator == true)
            _RemoteStatusPill(
              label: '创建者',
              color: accent,
            ),
          if (isLocal)
            _RemoteStatusPill(
              label: '本机',
              color: colors.success,
            ),
        ],
      ),
      subtitle: Text(
        '${user.app} · v${user.version}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _RemoteStatusPill extends StatelessWidget {
  const _RemoteStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(SliveRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _RemoteIconBox extends StatelessWidget {
  const _RemoteIconBox({
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
        borderRadius: BorderRadius.circular(size >= 46 ? 16 : 14),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

class _RemoteDivider extends StatelessWidget {
  const _RemoteDivider();

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

IconData _platformIcon(String platform) {
  return switch (platform.toLowerCase()) {
    'android' => Remix.android_line,
    'ios' => Remix.apple_line,
    'tv' => Remix.tv_2_line,
    'windows' => Remix.microsoft_fill,
    'xbox' => Remix.xbox_line,
    'macos' => Remix.mac_line,
    'linux' => Remix.ubuntu_line,
    _ => Remix.device_line,
  };
}
