import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

/// 兼容旧的 `/sync` 路由，仅保留局域网同步入口。
class SyncPage extends StatelessWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('局域网同步'),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
            child: Text(
              '设备间同步',
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: ListTile(
              title: const Text('局域网同步'),
              subtitle: const Text('在同一局域网内同步关注、标签、历史记录和弹幕屏蔽词'),
              leading: const Icon(Remix.device_line),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(RoutePath.kLocalSync),
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 16),
            child: Text(
              '同步服务只会在局域网同步页面打开期间运行，退出页面后会自动关闭。',
              style: Get.textTheme.bodySmall?.copyWith(
                color: Get.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
