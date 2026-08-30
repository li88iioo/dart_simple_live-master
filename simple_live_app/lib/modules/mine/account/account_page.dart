import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/mine/account/account_controller.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/platform_service.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_icon_button.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';

class AccountPage extends GetView<AccountController> {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;

    return SlivePageScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 68,
        leadingWidth: 68,
        leading: Align(
          child: SliveGlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: '返回',
            onPressed: () => Get.back(),
          ),
        ),
        titleSpacing: 0,
        title: Text(
          '账号管理',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.28,
              ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          MediaQuery.viewPaddingOf(context).bottom + 28,
        ),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SliveGlassSurface(
                    variant: SliveGlassVariant.panel,
                    radius: SliveRadii.panel,
                    enableBackdropBlur: false,
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colors.ambientBlue.withValues(alpha: 0.18),
                                colors.ambientPink.withValues(alpha: 0.09),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.ambientBlue.withValues(alpha: 0.13),
                            ),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: colors.ambientBlue,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '平台登录与配置',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '哔哩哔哩账号登录后可观看更高清晰度直播；其他平台按需维护 Cookie 或播放配置。',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colors.textSecondary,
                                      height: 1.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      '已支持的平台',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                    ),
                  ),
                  SliveGlassSurface(
                    variant: SliveGlassVariant.panel,
                    radius: SliveRadii.panel,
                    enableBackdropBlur: false,
                    child: Column(
                      children: [
                        Obx(() {
                          final service = BiliBiliAccountService.instance;
                          final isLoggedIn = service.logined.value;
                          return _AccountTile(
                            logo: 'assets/images/bilibili_2.png',
                            color: colors.bilibili,
                            title: '哔哩哔哩',
                            statusLabel: isLoggedIn ? '已登录' : '未登录',
                            statusColor: isLoggedIn
                                ? colors.success
                                : colors.textTertiary,
                            subtitle:
                                isLoggedIn ? service.name.value : '登录后可解锁更高清晰度',
                            trailingIcon: isLoggedIn
                                ? Icons.logout_rounded
                                : Icons.chevron_right_rounded,
                            onTap: controller.bilibiliTap,
                          );
                        }),
                        _AccountDivider(color: colors.divider),
                        _AccountTile(
                          logo: 'assets/images/douyu.png',
                          color: colors.douyu,
                          title: '斗鱼直播',
                          statusLabel: '免登录',
                          statusColor: colors.success,
                          subtitle: '当前无需登录即可观看',
                          trailingIcon: Icons.check_rounded,
                        ),
                        _AccountDivider(color: colors.divider),
                        Obx(() {
                          final hasConfig = PlatformService
                              .instance.huyaSdkUa.value.isNotEmpty;
                          return _AccountTile(
                            logo: 'assets/images/huya.png',
                            color: colors.huya,
                            title: '虎牙直播',
                            statusLabel: hasConfig ? '已配置' : '待更新',
                            statusColor:
                                hasConfig ? colors.success : colors.huya,
                            subtitle: hasConfig ? '已自定义 HYSDK_UA' : '点击拉取最新配置',
                            trailingIcon: Icons.chevron_right_rounded,
                            onTap: () async {
                              final result = await Utils.showAlertDialog(
                                '是否从网络拉取虎牙最新配置？',
                                title: '拉取虎牙配置',
                              );
                              if (result) {
                                await PlatformService.instance.fetchHuyaSdkUa();
                              }
                            },
                          );
                        }),
                        _AccountDivider(color: colors.divider),
                        Obx(() {
                          final service = PlatformService.instance;
                          final isLoggedIn = service.douyinLogined.value;
                          return _AccountTile(
                            logo: 'assets/images/douyin.png',
                            color: colors.douyin,
                            title: '抖音直播',
                            statusLabel: isLoggedIn ? '已登录' : '未登录',
                            statusColor: isLoggedIn
                                ? colors.success
                                : colors.textTertiary,
                            subtitle: service.douyinName.value,
                            trailingIcon: isLoggedIn
                                ? Icons.logout_rounded
                                : Icons.chevron_right_rounded,
                            onTap: controller.douyinTap,
                          );
                        }),
                      ],
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

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.logo,
    required this.color,
    required this.title,
    required this.statusLabel,
    required this.statusColor,
    required this.subtitle,
    required this.trailingIcon,
    this.onTap,
  });

  final String logo;
  final Color color;
  final String title;
  final String statusLabel;
  final Color statusColor;
  final String subtitle;
  final IconData trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: isDark ? 0.24 : 0.17),
                  color.withValues(alpha: isDark ? 0.10 : 0.07),
                ],
              ),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: color.withValues(alpha: 0.14)),
            ),
            child: Image.asset(logo, filterQuality: FilterQuality.medium),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    _StatusPill(label: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            trailingIcon,
            color: onTap == null ? colors.textTertiary : colors.textSecondary,
            size: 21,
          ),
        ],
      ),
    );

    if (onTap == null) {
      content = Opacity(opacity: 0.62, child: content);
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SliveRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
      ),
    );
  }
}

class _AccountDivider extends StatelessWidget {
  const _AccountDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.7,
      indent: 77,
      endIndent: 14,
      color: color.withValues(alpha: 0.18),
    );
  }
}
