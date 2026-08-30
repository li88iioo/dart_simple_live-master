import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/follow_user/follow_info_setting/follow_info_controller.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_menu.dart';

class FollowInfoPage extends GetView<FollowInfoController> {
  const FollowInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;

    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('关注信息设置'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Obx(
              () => _FollowRefreshButton(
                loading: controller.pageLoadding.value,
                onPressed: controller.refreshData,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          SliveLayout.pageHorizontal,
          4,
          SliveLayout.pageHorizontal,
          bottomPadding,
        ),
        children: [
          Obx(() => _buildProfileCard(context)),
          const SizedBox(height: 20),
          Text(
            '关注信息',
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
                Obx(() {
                  final items = controller.tagOptions;
                  final selected = controller.selectedTag.value;
                  final valueMap = <String, String>{
                    for (final item in items) item.tag: item.tag,
                  };
                  return SettingsMenu<String>(
                    title: '标签设置',
                    value: selected?.tag ?? '全部',
                    valueMap: valueMap,
                    onChanged: (value) {
                      final target = items.firstWhere(
                        (item) => item.tag == value,
                        orElse: () => items.first,
                      );
                      controller.changeTag(target);
                    },
                  );
                }),
                const _FollowInfoDivider(),
                Obx(() {
                  final remark = controller.followUser.value?.remark;
                  return ListTile(
                    minVerticalPadding: 11,
                    leading: _FollowInfoIconBox(
                      icon: Icons.edit_note_rounded,
                      color: colors.huya,
                    ),
                    title: const Text('备注设置'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 112),
                          child: Text(
                            remark?.isNotEmpty == true ? remark! : '无',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.textTertiary,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.textTertiary,
                        ),
                      ],
                    ),
                    onTap: _showRemarkDialog,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '平台迁移',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          SettingsCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FollowInfoIconBox(
                        icon: Remix.link,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '迁移到新的直播间',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '粘贴主播在新平台的直播链接，解析后更新当前关注。',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.textSecondary,
                                    height: 1.45,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller.migrationUrlController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    decoration: const InputDecoration(
                      hintText: 'https://...',
                      prefixIcon: Icon(Icons.link_rounded),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                    ),
                    onSubmitted: (_) => controller.parseAndMigrate(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: controller.pasteFromClipboard,
                            icon: const Icon(Remix.clipboard_line, size: 19),
                            label: const Text('粘贴'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: controller.parseAndMigrate,
                            icon: const Icon(
                              Remix.arrow_right_line,
                              size: 19,
                            ),
                            label: const Text('迁移'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final user = controller.followUser.value;
    final colors = context.sliveColors;
    if (user == null) {
      return SliveGlassSurface(
        variant: SliveGlassVariant.panel,
        enableBackdropBlur: true,
        constraints: const BoxConstraints(minHeight: 112),
        child: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    final site = Sites.allSites[user.siteId];
    final accent = colors.platform(user.siteId);
    final remark = user.remark;

    return SliveGlassSurface(
      variant: SliveGlassVariant.panel,
      enableBackdropBlur: true,
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            child: ClipOval(
              child: Image.network(
                user.face,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: accent.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.person_rounded,
                    color: accent,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.userName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (remark?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    '备注 · $remark',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    if (site != null)
                      Image.asset(
                        site.logo,
                        width: 19,
                        height: 19,
                      ),
                    if (site != null) const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${site?.name ?? user.siteId} · 房间号 ${user.roomId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colors.textTertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRemarkDialog() async {
    final remark = await Utils.showEditTextDialog(
      controller.followUser.value?.remark ?? '',
      title: '修改备注',
      hintText: '请输入备注名',
    );
    if (remark == null) return;
    controller.updateRemark(remark.trim());
  }
}

class _FollowRefreshButton extends StatelessWidget {
  const _FollowRefreshButton({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: loading ? '正在刷新' : '刷新用户信息',
      child: SliveGlassSurface(
        variant: SliveGlassVariant.pill,
        enableBackdropBlur: false,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        onTap: loading ? null : onPressed,
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: loading
                ? const CircularProgressIndicator(strokeWidth: 2)
                : Icon(
                    Icons.refresh_rounded,
                    size: 21,
                    color: context.sliveColors.textPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}

class _FollowInfoIconBox extends StatelessWidget {
  const _FollowInfoIconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _FollowInfoDivider extends StatelessWidget {
  const _FollowInfoDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 0.7,
      indent: 60,
      endIndent: 14,
      color: colors.divider.withValues(alpha: isDark ? 0.14 : 0.09),
    );
  }
}
