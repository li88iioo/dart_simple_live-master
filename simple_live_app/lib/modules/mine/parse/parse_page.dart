import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/mine/parse/parse_controller.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_icon_button.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';

class ParsePage extends GetView<ParseController> {
  const ParsePage({super.key});

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
          '链接解析',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.28,
              ),
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ParseCard(
                    icon: Remix.play_circle_line,
                    iconColor: colors.success,
                    title: '直播间跳转',
                    subtitle: '识别平台与房间号后直接进入直播间',
                    child: _ParseForm(
                      controller: controller.roomJumpToController,
                      hintText: '输入或粘贴哔哩哔哩、虎牙、斗鱼或抖音直播链接',
                      actionIcon: Remix.play_circle_line,
                      actionLabel: '链接跳转',
                      onSubmitted: controller.jumpToRoom,
                      onPressed: () => controller.jumpToRoom(
                        controller.roomJumpToController.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ParseCard(
                    icon: Remix.link,
                    iconColor: colors.ambientBlue,
                    title: '获取直链',
                    subtitle: '读取清晰度与线路，并将所选地址复制到剪贴板',
                    child: _ParseForm(
                      controller: controller.getUrlController,
                      hintText: '输入或粘贴支持平台的直播链接',
                      actionIcon: Remix.link,
                      actionLabel: '获取直链',
                      onSubmitted: controller.getPlayUrl,
                      onPressed: () => controller.getPlayUrl(
                        controller.getUrlController.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SliveGlassSurface(
                    variant: SliveGlassVariant.card,
                    radius: SliveRadii.card,
                    enableBackdropBlur: false,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _IconWell(
                              icon: Icons.info_outline_rounded,
                              color: colors.ambientOrange,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                '支持的链接格式',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SelectableText(
                          '''哔哩哔哩
https://live.bilibili.com/xxxxx
https://b23.tv/xxxxx

虎牙直播
https://www.huya.com/xxxxx

斗鱼直播
https://www.douyu.com/xxxxx
https://www.douyu.com/topic/xxxx

抖音直播
https://live.douyin.com/xxxxx
https://webcast.amemv.com/douyin/webcast/reflow/xxxxx''',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.textSecondary,
                                    fontFamily: 'monospace',
                                    height: 1.55,
                                  ),
                        ),
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

class _ParseCard extends StatelessWidget {
  const _ParseCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;

    return SliveGlassSurface(
      variant: SliveGlassVariant.panel,
      radius: SliveRadii.panel,
      enableBackdropBlur: false,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: iconColor.withValues(alpha: 0.05),
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: colors.textSecondary,
          collapsedIconColor: colors.textTertiary,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Row(
            children: [
              _IconWell(icon: icon, color: iconColor),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textTertiary,
                            height: 1.3,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _ParseForm extends StatelessWidget {
  const _ParseForm({
    required this.controller,
    required this.hintText,
    required this.actionIcon,
    required this.actionLabel,
    required this.onSubmitted,
    required this.onPressed,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData actionIcon;
  final String actionLabel;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          minLines: 3,
          maxLines: 3,
          controller: controller,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          autocorrect: false,
          enableSuggestions: false,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            height: 1.45,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: colors.textTertiary, height: 1.4),
            filled: true,
            fillColor: colors.glassStrong.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.13 : 0.42,
            ),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: colors.glassBorder.withValues(alpha: 0.34),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary.withValues(
                      alpha: 0.42,
                    ),
                width: 1.2,
              ),
            ),
          ),
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 10),
        SliveGlassSurface(
          variant: SliveGlassVariant.pill,
          radius: SliveRadii.pill,
          enableBackdropBlur: false,
          onTap: onPressed,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(actionIcon, size: 19, color: colors.textPrimary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  actionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconWell extends StatelessWidget {
  const _IconWell({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: isDark ? 0.24 : 0.17),
            color.withValues(alpha: isDark ? 0.10 : 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
