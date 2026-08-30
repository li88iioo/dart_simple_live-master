import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

/// 兼容旧的 `/sync` 路由，仅保留局域网同步入口。
class SyncPage extends StatelessWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;

    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('局域网同步'),
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
            '设备间同步',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          SliveGlassSurface(
            variant: SliveGlassVariant.panel,
            enableBackdropBlur: true,
            onTap: () => Get.toNamed(RoutePath.kLocalSync),
            padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SyncIconBox(
                  icon: Remix.device_line,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '局域网同步',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '在同一局域网内同步关注、标签、历史记录和弹幕屏蔽词',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                              height: 1.45,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textTertiary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SettingsCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 20,
                    color: colors.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '同步服务只会在局域网同步页面打开期间运行，退出页面后会自动关闭。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncIconBox extends StatelessWidget {
  const _SyncIconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.13),
        borderRadius: BorderRadius.circular(SliveRadii.control),
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }
}
