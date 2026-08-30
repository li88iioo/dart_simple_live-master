import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/settings/appstyle_settings/appstyle_setting_contorller.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/platform_service.dart';
import 'package:simple_live_app/services/signalr_service.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MinePage extends StatelessWidget {
  const MinePage({super.key});

  static const _historyColor = Color(0xFF5B9BEA);
  static const _accountColor = Color(0xFF62B486);
  static const _syncColor = Color(0xFF50B4AC);
  static const _linkColor = Color(0xFFE39B56);
  static const _appearanceColor = Color(0xFF788BE1);
  static const _homeColor = Color(0xFFE58EAD);
  static const _playerColor = Color(0xFFA17ED1);
  static const _danmakuColor = Color(0xFF55B4C2);
  static const _timerColor = Color(0xFFDAA044);
  static const _otherColor = Color(0xFF7F8D99);
  static const _dangerColor = Color(0xFFE47B77);
  static const _githubColor = Color(0xFF59636E);
  static const _updateColor = Color(0xFFE8767D);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.orientation == Orientation.portrait
        ? mediaQuery.viewPadding.bottom +
            SliveLayout.bottomDockHeight +
            SliveLayout.bottomDockGap +
            34
        : 34.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileCard(context),
                      const SizedBox(height: 22),
                      _SectionLabel(label: '工具与数据'),
                      const SizedBox(height: 8),
                      _GlassSection(
                        children: [
                          _MineActionTile(
                            icon: Remix.history_line,
                            iconColor: _historyColor,
                            title: '观看记录',
                            subtitle: const _TileSubtitle('继续查看浏览过的直播间'),
                            onTap: () => Get.toNamed(RoutePath.kHistory),
                          ),
                          _MineActionTile(
                            icon: Remix.account_circle_line,
                            iconColor: _accountColor,
                            title: '账号管理',
                            subtitle: const _BoundPlatformStatus(),
                            onTap: () =>
                                Get.toNamed(RoutePath.kSettingsAccount),
                          ),
                          _MineActionTile(
                            icon: Icons.devices_rounded,
                            iconColor: _syncColor,
                            title: '局域网同步',
                            subtitle: const _TileSubtitle('在可信局域网内同步应用数据'),
                            onTap: () => Get.toNamed(RoutePath.kLocalSync),
                          ),
                          _MineActionTile(
                            icon: Remix.link,
                            iconColor: _linkColor,
                            title: '链接解析',
                            subtitle: const _TileSubtitle('解析支持平台的直播链接'),
                            onTap: () => Get.toNamed(RoutePath.kTools),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _SectionLabel(label: '偏好设置'),
                      const SizedBox(height: 8),
                      _GlassSection(
                        children: [
                          _MineActionTile(
                            icon: Remix.moon_line,
                            iconColor: _appearanceColor,
                            title: '外观设置',
                            subtitle: const _AppearanceStatus(),
                            onTap: () =>
                                Get.toNamed(RoutePath.kAppstyleSetting),
                          ),
                          _MineActionTile(
                            icon: Remix.home_2_line,
                            iconColor: _homeColor,
                            title: '主页设置',
                            subtitle: const _TileSubtitle('调整平台顺序与默认首页'),
                            onTap: () =>
                                Get.toNamed(RoutePath.kSettingsIndexed),
                          ),
                          _MineActionTile(
                            icon: Remix.play_circle_line,
                            iconColor: _playerColor,
                            title: '直播设置',
                            subtitle: const _TileSubtitle('画质、播放与后台行为'),
                            onTap: () => Get.toNamed(RoutePath.kSettingsPlay),
                          ),
                          _MineActionTile(
                            icon: Remix.text,
                            iconColor: _danmakuColor,
                            title: '弹幕设置',
                            subtitle: const _TileSubtitle('字号、区域与礼物弹幕'),
                            onTap: () => Get.toNamed(RoutePath.kSettingsDanmu),
                          ),
                          _MineActionTile(
                            icon: Remix.timer_2_line,
                            iconColor: _timerColor,
                            title: '定时关闭',
                            subtitle: const _TileSubtitle('按计划停止当前播放'),
                            onTap: () =>
                                Get.toNamed(RoutePath.kSettingsAutoExit),
                          ),
                          _MineActionTile(
                            icon: Remix.apps_line,
                            iconColor: _otherColor,
                            title: '其他设置',
                            subtitle: const _TileSubtitle('日志、更新与实验选项'),
                            onTap: () => Get.toNamed(RoutePath.kSettingsOther),
                          ),
                          if (kDebugMode)
                            _MineActionTile(
                              icon: Remix.bug_line,
                              iconColor: _dangerColor,
                              title: '测试',
                              subtitle: const _TileSubtitle('SignalR 调试入口'),
                              onTap: _runDebugSignalR,
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _SectionLabel(label: '关于 Slive'),
                      const SizedBox(height: 8),
                      _GlassSection(
                        children: [
                          _MineActionTile(
                            icon: Remix.error_warning_line,
                            iconColor: _dangerColor,
                            title: '免责声明',
                            subtitle: const _TileSubtitle('使用前请了解服务边界'),
                            onTap: Utils.showStatement,
                          ),
                          _MineActionTile(
                            icon: Remix.github_line,
                            iconColor: _githubColor,
                            title: '开源主页',
                            subtitle: const _TileSubtitle('查看项目源码与许可证'),
                            onTap: () {
                              launchUrlString(
                                'https://github.com/slotsun/dart_simple_live',
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                          _MineActionTile(
                            icon: Remix.upload_2_line,
                            iconColor: _updateColor,
                            title: '检查更新',
                            subtitle: const _TileSubtitle('获取最新版本状态'),
                            trailingLabel: 'Ver ${Utils.packageInfo.version}',
                            onTap: () => Utils.checkUpdate(showMsg: true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final colors = context.sliveColors;
    final primary = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      label: '关于 Slive，版本 ${Utils.packageInfo.version}',
      child: SliveGlassSurface(
        variant: SliveGlassVariant.panel,
        radius: SliveRadii.panel,
        enableBackdropBlur: true,
        onTap: _showAboutDialog,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112),
          child: Stack(
            children: [
              Positioned(
                right: -28,
                top: -52,
                child: IgnorePointer(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          colors.ambientBlue.withValues(alpha: 0.30),
                          colors.ambientPink.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 88,
                bottom: -62,
                child: IgnorePointer(
                  child: Container(
                    width: 174,
                    height: 116,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: RadialGradient(
                        colors: [
                          colors.ambientOrange.withValues(alpha: 0.16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 14, 17),
                child: Row(
                  children: [
                    const _SliveWaveBadge(size: 68),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Slive',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.35,
                                  height: 1.08,
                                ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '我就默默看你表演',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                          ),
                          const SizedBox(height: 8),
                          _ProfilePill(
                            label: '聚合直播 · ${Utils.packageInfo.version}',
                            color: primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SoftChevron(color: colors.textTertiary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    Get.dialog(
      AboutDialog(
        applicationIcon: const _SliveWaveBadge(size: 52),
        applicationName: 'Slive',
        applicationVersion: '我就默默看你表演',
        applicationLegalese: 'Ver ${Utils.packageInfo.version}',
      ),
    );
  }

  Future<void> _runDebugSignalR() async {
    final signalRService = SignalRService();
    await signalRService.connect();
    final room = await signalRService.createRoom();
    Log.logPrint(room);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.sliveColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.55,
            ),
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  const _GlassSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final separatedChildren = <Widget>[];

    for (var index = 0; index < children.length; index++) {
      separatedChildren.add(children[index]);
      if (index != children.length - 1) {
        separatedChildren.add(
          Divider(
            height: 1,
            thickness: 0.7,
            indent: 56,
            endIndent: 14,
            color: colors.divider.withValues(alpha: isDark ? 0.13 : 0.09),
          ),
        );
      }
    }

    return SliveGlassSurface(
      variant: SliveGlassVariant.card,
      radius: 24,
      enableBackdropBlur: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: separatedChildren,
      ),
    );
  }
}

class _MineActionTile extends StatelessWidget {
  const _MineActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingLabel,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;
  final Widget? subtitle;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
            child: Row(
              children: [
                _MacaronIcon(icon: icon, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        subtitle!,
                      ],
                    ],
                  ),
                ),
                if (trailingLabel != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      trailingLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.textTertiary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 21,
                  color: colors.textTertiary.withValues(alpha: 0.82),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MacaronIcon extends StatelessWidget {
  const _MacaronIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Color.lerp(color, Colors.white, 0.28)! : color;

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: isDark ? 0.25 : 0.18),
            color.withValues(alpha: isDark ? 0.12 : 0.08),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor, size: 16),
    );
  }
}

class _TileSubtitle extends StatelessWidget {
  const _TileSubtitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.sliveColors.textTertiary,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            height: 1.18,
          ),
    );
  }
}

class _BoundPlatformStatus extends StatelessWidget {
  const _BoundPlatformStatus();

  @override
  Widget build(BuildContext context) {
    final hasBilibili = Get.isRegistered<BiliBiliAccountService>();
    final hasPlatformService = Get.isRegistered<PlatformService>();

    if (!hasBilibili && !hasPlatformService) {
      return const _TileSubtitle('账号状态可在管理页查看');
    }

    return Obx(() {
      var count = 0;
      if (hasBilibili && BiliBiliAccountService.instance.logined.value) {
        count++;
      }
      if (hasPlatformService && PlatformService.instance.douyinLogined.value) {
        count++;
      }
      return _TileSubtitle('已绑定 $count 个平台');
    });
  }
}

class _AppearanceStatus extends StatelessWidget {
  const _AppearanceStatus();

  @override
  Widget build(BuildContext context) {
    final tone =
        Theme.of(context).brightness == Brightness.light ? '柔润浅色' : '柔润深色';

    if (!Get.isRegistered<AppStyleSettingController>()) {
      return _TileSubtitle('$tone · ${context.sliveMaterials.mode.label}');
    }

    return Obx(
      () => _TileSubtitle(
        '$tone · ${AppStyleSettingController.instance.glassMode.value.label}',
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: isDark ? 0.13 : 0.08),
          colors.glassBase.withValues(alpha: isDark ? 0.14 : 0.34),
        ),
        borderRadius: BorderRadius.circular(SliveRadii.pill),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
              height: 1.1,
            ),
      ),
    );
  }
}

class _SoftChevron extends StatelessWidget {
  const _SoftChevron({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.08),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.chevron_right_rounded,
        size: 21,
        color: color.withValues(alpha: 0.88),
      ),
    );
  }
}

class _SliveWaveBadge extends StatelessWidget {
  const _SliveWaveBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final blueEnd = Color.lerp(const Color(0xFF266BE5), primary, 0.18)!;

    return Semantics(
      image: true,
      label: 'Slive 流线徽标',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.31),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF78D7FF),
              const Color(0xFF4A9AF6),
              blueEnd,
            ],
            stops: const [0, 0.52, 1],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.56),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3A8DF0).withValues(alpha: 0.24),
              blurRadius: 18,
              spreadRadius: -5,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.31),
          child: CustomPaint(
            painter: const _SliveWavePainter(),
          ),
        ),
      ),
    );
  }
}

class _SliveWavePainter extends CustomPainter {
  const _SliveWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.34),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.28, size.height * 0.22),
          radius: size.width * 0.54,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.28, size.height * 0.22),
      size.width * 0.54,
      glowPaint,
    );

    final broadWave = Path()
      ..moveTo(-size.width * 0.10, size.height * 0.62)
      ..cubicTo(
        size.width * 0.16,
        size.height * 0.28,
        size.width * 0.36,
        size.height * 0.82,
        size.width * 0.62,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.28,
        size.width * 0.92,
        size.height * 0.42,
        size.width * 1.10,
        size.height * 0.26,
      );
    canvas.drawPath(
      broadWave,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = size.width * 0.080,
    );

    final fineWave = Path()
      ..moveTo(-size.width * 0.08, size.height * 0.79)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.52,
        size.width * 0.42,
        size.height * 0.92,
        size.width * 0.72,
        size.height * 0.62,
      )
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.49,
        size.width * 0.98,
        size.height * 0.54,
        size.width * 1.08,
        size.height * 0.46,
      );
    canvas.drawPath(
      fineWave,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.46)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = size.width * 0.030,
    );

    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.28),
      size.width * 0.045,
      Paint()..color = Colors.white.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant _SliveWavePainter oldDelegate) => false;
}
