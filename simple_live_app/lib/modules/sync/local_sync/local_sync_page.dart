import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/sync/local_sync/local_sync_controller.dart';
import 'package:simple_live_app/services/sync_service.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_icon_button.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class LocalSyncPage extends GetView<LocalSyncController> {
  const LocalSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;

    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('局域网数据同步'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SliveGlassIconButton(
              icon: Icons.qr_code_2_rounded,
              tooltip: '本机信息',
              onPressed: controller.showInfo,
            ),
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
          SliveGlassSurface(
            variant: SliveGlassVariant.panel,
            enableBackdropBlur: true,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _LocalSyncIconBox(
                      icon: Remix.link_m,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '连接另一台设备',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '输入局域网地址与 8 位配对码',
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
                const SizedBox(height: 18),
                TextField(
                  controller: controller.addressController,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => controller.connect(),
                  decoration: InputDecoration(
                    labelText: '客户端地址',
                    hintText: '例如 192.168.1.8:8080',
                    prefixIcon: const Icon(Icons.lan_outlined),
                    suffixIcon: Platform.isAndroid || Platform.isIOS
                        ? IconButton(
                            tooltip: '扫一扫',
                            onPressed: controller.toScanQr,
                            icon: const Icon(Remix.qr_scan_line),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller.pairingCodeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: '配对码',
                    hintText: '输入对方设备显示的 8 位配对码',
                    prefixIcon: Icon(Icons.password_rounded),
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                  ),
                  onSubmitted: (_) => controller.connect(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 50,
                  child: Obx(() {
                    final starting = SyncService.instance.starting.value;
                    return FilledButton.icon(
                      onPressed: starting ? null : controller.connect,
                      icon: SizedBox.square(
                        dimension: 20,
                        child: starting
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : const Icon(Icons.arrow_forward_rounded, size: 20),
                      ),
                      label: Text(starting ? '正在启动服务…' : '连接'),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Obx(
                  () => Text(
                    '已发现设备  ${SyncService.instance.scanClients.length}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              SliveGlassIconButton(
                icon: Icons.refresh_rounded,
                tooltip: '刷新设备',
                size: 40,
                iconSize: 20,
                onPressed: controller.refreshClients,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SettingsCard(
            child: Obx(() {
              final clients = SyncService.instance.scanClients;
              if (clients.isEmpty) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 106),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 20,
                    ),
                    child: Row(
                      children: [
                        _LocalSyncIconBox(
                          icon: Icons.radar_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '暂未发现设备',
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
                                '请确认两台设备位于同一局域网，或手动输入地址。',
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

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < clients.length; index++) ...[
                    if (index > 0) const _LocalSyncDivider(),
                    ListTile(
                      minVerticalPadding: 12,
                      leading: _LocalSyncIconBox(
                        icon: _deviceIcon(clients[index].type),
                        color: Theme.of(context).colorScheme.primary,
                        size: 44,
                      ),
                      title: Text(
                        clients[index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        clients[index].address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: colors.textTertiary,
                      ),
                      onTap: () => controller.connectClient(clients[index]),
                    ),
                  ],
                ],
              );
            }),
          ),
          const SizedBox(height: 14),
          SliveGlassSurface(
            variant: SliveGlassVariant.pill,
            enableBackdropBlur: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '如果无法扫描到设备，请手动输入地址。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
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

class _LocalSyncIconBox extends StatelessWidget {
  const _LocalSyncIconBox({
    required this.icon,
    required this.color,
    this.size = 48,
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
        color: color.withValues(alpha: isDark ? 0.19 : 0.12),
        borderRadius: BorderRadius.circular(size >= 48 ? 16 : 14),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

class _LocalSyncDivider extends StatelessWidget {
  const _LocalSyncDivider();

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
