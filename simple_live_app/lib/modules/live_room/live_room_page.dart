import 'dart:io';

import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_overlay.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/desktop_refresh_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_icon_button.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';
import 'package:simple_live_app/widgets/superchat_card.dart';
import 'package:simple_live_core/simple_live_core.dart';

class LiveRoomPage extends GetView<LiveRoomController> {
  const LiveRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    final page = Obx(
      () {
        if (controller.loadError.value) {
          return _buildLoadError(context);
        }
        if (controller.fullScreenState.value) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (e, r) {
              controller.exitFull();
            },
            child: Scaffold(
              body: buildMediaPlayer(),
            ),
          );
        } else {
          return buildPageUI();
        }
      },
    );
    if (!Platform.isAndroid) {
      return page;
    }
    return PiPSwitcher(
      floating: controller.pip,
      childWhenDisabled: page,
      childWhenEnabled: buildMediaPlayer(),
    );
  }

  Widget _buildLoadError(BuildContext context) {
    final colors = context.sliveColors;
    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text("直播间加载失败"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SliveGlassSurface(
              variant: SliveGlassVariant.panel,
              radius: SliveRadii.panel,
              enableBackdropBlur: true,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LottieBuilder.asset(
                    'assets/lotties/error.json',
                    height: 140,
                    repeat: false,
                  ),
                  Text(
                    "直播间加载失败",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.error?.toString() ?? "未知错误",
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${controller.rxSite.value.id} · ${controller.rxRoomId.value}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: controller.copyErrorDetail,
                        icon: const Icon(Remix.file_copy_line),
                        label: const Text("复制信息"),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: controller.refreshRoom,
                        icon: const Icon(Remix.refresh_line),
                        label: const Text("重新加载"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPageUI() {
    return OrientationBuilder(
      builder: (context, orientation) {
        return SlivePageScaffold(
          appBar: AppBar(
            leadingWidth: 60,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
              child: SliveGlassIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: '返回',
                onPressed: Get.back,
              ),
            ),
            title: Obx(
              () => Text(
                controller.detail.value?.title ?? "直播间",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            actions: buildAppbarActions(context),
          ),
          body: orientation == Orientation.portrait
              ? buildPhoneUI(context)
              : buildTabletUI(context),
        );
      },
    );
  }

  Widget buildPhoneUI(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildPlayerFrame(context),
          ),
        ),
        buildUserProfile(context),
        buildMessageArea(context),
        buildBottomActions(context),
      ],
    );
  }

  Widget buildTabletUI(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                Expanded(child: _buildPlayerFrame(context)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 320,
                  child: Column(
                    children: [
                      buildUserProfile(context, horizontalMargin: 0),
                      buildMessageArea(context, horizontalPadding: 0),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        buildBottomActions(context),
      ],
    );
  }

  Widget _buildPlayerFrame(BuildContext context) {
    return SliveGlassSurface(
      variant: SliveGlassVariant.panel,
      radius: SliveRadii.player,
      enableBackdropBlur: false,
      color: Colors.black,
      borderColor: Colors.white.withValues(alpha: 0.18),
      shadowColor: context.sliveColors.ambientOrange.withValues(alpha: 0.10),
      child: buildMediaPlayer(),
    );
  }

  Widget buildMediaPlayer() {
    var boxFit = BoxFit.contain;
    double? aspectRatio;
    if (AppSettingsController.instance.scaleMode.value == 0) {
      boxFit = BoxFit.contain;
    } else if (AppSettingsController.instance.scaleMode.value == 1) {
      boxFit = BoxFit.fill;
    } else if (AppSettingsController.instance.scaleMode.value == 2) {
      boxFit = BoxFit.cover;
    } else if (AppSettingsController.instance.scaleMode.value == 3) {
      boxFit = BoxFit.contain;
      aspectRatio = 16 / 9;
    } else if (AppSettingsController.instance.scaleMode.value == 4) {
      boxFit = BoxFit.contain;
      aspectRatio = 4 / 3;
    }
    return Stack(
      children: [
        Video(
          key: controller.globalPlayerKey,
          controller: controller.videoController,
          pauseUponEnteringBackgroundMode:
              AppSettingsController.instance.playerAutoPause.value,
          resumeUponEnteringForegroundMode:
              AppSettingsController.instance.playerAutoPause.value,
          controls: (state) {
            return playerControls(state, controller);
          },
          aspectRatio: aspectRatio,
          fit: boxFit,
          // 自己实现
          wakelock: false,
        ),
        HuyaGiftDanmakuOverlay(controller: controller),
        Obx(
          () => Visibility(
            visible: !controller.liveStatus.value,
            child: const Center(
              child: Text(
                "未开播",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildUserProfile(
    BuildContext context, {
    double horizontalMargin = 12,
  }) {
    return SliveGlassSurface(
      variant: SliveGlassVariant.panel,
      radius: 20,
      enableBackdropBlur: false,
      margin: EdgeInsets.fromLTRB(horizontalMargin, 8, horizontalMargin, 4),
      padding: const EdgeInsets.all(10),
      child: Obx(() {
        final site = controller.site;
        final colors = context.sliveColors;
        final platformColor = colors.platform(site.id);
        final vipCount = controller.vipCount.value;
        final showVipCount =
            site.id == Constant.kHuya || (vipCount != null && vipCount > 0);
        final heat = Utils.onlineToString(
          site.id == Constant.kHuya
              ? controller.online.value
              : (controller.detail.value?.online ?? 0),
        );

        return Row(
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    platformColor,
                    Color.lerp(platformColor, colors.ambientPink, 0.42)!,
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colors.glassStrong,
                  shape: BoxShape.circle,
                ),
                child: NetImage(
                  controller.detail.value?.userAvatar ?? "",
                  width: 42,
                  height: 42,
                  borderRadius: 24,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controller.detail.value?.userName ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Image.asset(
                        site.logo,
                        width: 17,
                        height: 17,
                        filterQuality: FilterQuality.medium,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          site.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMetricPill(
                  context,
                  icon: Remix.fire_fill,
                  text: heat,
                  color: colors.huya,
                ),
                if (showVipCount) ...[
                  const SizedBox(height: 5),
                  _buildMetricPill(
                    context,
                    icon: Remix.vip_crown_fill,
                    text: vipCount?.toString() ?? "--",
                    color: const Color(0xFFB58A2B),
                    muted: vipCount == null,
                  ),
                ],
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMetricPill(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Color color,
    bool muted = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(SliveRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 13,
              color: muted ? context.sliveColors.textTertiary : color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: muted ? context.sliveColors.textTertiary : color,
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBottomActions(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: SizedBox(
        height: 60,
        child: SliveGlassSurface(
          variant: SliveGlassVariant.dock,
          radius: 30,
          enableBackdropBlur: true,
          child: Row(
            children: [
              Expanded(
                child: Obx(
                  () => _buildDockAction(
                    context,
                    icon: controller.followed.value
                        ? Remix.heart_fill
                        : Remix.heart_line,
                    label: controller.followed.value ? "已关注" : "关注",
                    color: controller.followed.value
                        ? context.sliveColors.danger
                        : null,
                    onTap: controller.followed.value
                        ? controller.removeFollowUser
                        : controller.followUser,
                  ),
                ),
              ),
              Expanded(
                child: _buildDockAction(
                  context,
                  icon: Remix.refresh_line,
                  label: "刷新",
                  onTap: controller.refreshRoom,
                ),
              ),
              Expanded(
                child: _buildDockAction(
                  context,
                  icon: Remix.share_line,
                  label: "分享",
                  onTap: controller.share,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final foreground = color ?? context.sliveColors.textPrimary;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(SliveRadii.pill),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10.5,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMessageArea(
    BuildContext context, {
    double horizontalPadding = 12,
  }) {
    return Expanded(
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 4, horizontalPadding, 2),
              child: SizedBox(
                height: 42,
                child: SliveGlassSurface(
                  variant: SliveGlassVariant.pill,
                  enableBackdropBlur: true,
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelPadding: EdgeInsets.zero,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: context.sliveColors.glassStrong.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.16
                            : 0.82,
                      ),
                      borderRadius: BorderRadius.circular(SliveRadii.pill),
                      border: Border.all(
                        color: context.sliveColors.glassBorder.withValues(
                          alpha: context.sliveMaterials.borderOpacity * 0.72,
                        ),
                      ),
                    ),
                    tabs: [
                      const Tab(text: "聊天"),
                      Tab(
                        child: Obx(
                          () => Text(
                            controller.superChats.isNotEmpty
                                ? "SC(${controller.superChats.length})"
                                : "SC",
                          ),
                        ),
                      ),
                      const Tab(text: "关注"),
                      const Tab(text: "设置"),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Obx(() {
                    final gap =
                        AppSettingsController.instance.chatTextGap.value * 2;
                    return Stack(
                      children: [
                        ListView.separated(
                          controller: controller.scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          addAutomaticKeepAlives: false,
                          separatorBuilder: (_, i) => SizedBox(height: gap),
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                          itemCount: controller.messages.length,
                          itemBuilder: (_, i) {
                            final item = controller.messages[i];
                            return buildMessageItem(context, item);
                          },
                        ),
                        if (controller.disableAutoScroll.value)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: SliveGlassSurface(
                              variant: SliveGlassVariant.pill,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              onTap: controller.resumeChatAutoScroll,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.expand_more, size: 18),
                                  SizedBox(width: 4),
                                  Text("最新"),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                  buildSuperChats(),
                  buildFollowList(),
                  buildSettings(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMessageItem(BuildContext context, LiveMessage message) {
    final isGift = message.type == LiveMessageType.gift;
    final isVipEnter = message.type == LiveMessageType.vipEnter;
    final isSystem = message.userName == "LiveSysMessage";

    return Obx(() {
      final colors = context.sliveColors;
      final fontSize = AppSettingsController.instance.chatTextSize.value;
      final bubbleStyle = AppSettingsController.instance.chatBubbleStyle.value;

      if (isSystem || isGift || isVipEnter) {
        final accent = isGift
            ? colors.huya
            : isVipEnter
                ? const Color(0xFF8F73C8)
                : colors.textTertiary;
        final icon = isGift
            ? Remix.gift_line
            : isVipEnter
                ? Remix.vip_crown_line
                : Remix.information_line;
        return SliveGlassSurface(
          variant: SliveGlassVariant.card,
          radius: 15,
          enableBackdropBlur: false,
          color: Color.lerp(colors.glassBase, accent, isGift ? 0.08 : 0.04),
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.message,
                  style: TextStyle(
                    color: isSystem ? colors.textSecondary : colors.textPrimary,
                    fontSize: fontSize,
                    height: 1.35,
                    fontWeight: isGift ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      final content = Text.rich(
        TextSpan(
          text: "${message.userName}：",
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(
              text: message.message,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

      if (!bubbleStyle) return content;
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: SliveGlassSurface(
              variant: SliveGlassVariant.card,
              radius: 16,
              enableBackdropBlur: false,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: content,
            ),
          ),
        ],
      );
    });
  }

  Widget buildSuperChats() {
    return KeepAliveWrapper(
      child: Obx(
        () => ListView.separated(
          padding: AppStyle.edgeInsetsA12,
          itemCount: controller.superChats.length,
          separatorBuilder: (_, i) => AppStyle.vGap12,
          itemBuilder: (_, i) {
            var item = controller.superChats[i];
            return SuperChatCard(
              item,
            );
          },
        ),
      ),
    );
  }

  Widget buildSettings() {
    return ListView(
      padding: AppStyle.edgeInsetsA12,
      children: [
        Obx(
          () => Visibility(
            visible: controller.autoExitEnable.value,
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              visualDensity: VisualDensity.compact,
              title: Text("${parseDuration(controller.countdown.value)}后自动关闭"),
            ),
          ),
        ),
        Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "聊天区",
            style: Get.textTheme.titleSmall,
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => SettingsNumber(
                  title: "文字大小",
                  value:
                      AppSettingsController.instance.chatTextSize.value.toInt(),
                  min: 8,
                  max: 36,
                  onChanged: (e) {
                    AppSettingsController.instance
                        .setChatTextSize(e.toDouble());
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "上下间隔",
                  value:
                      AppSettingsController.instance.chatTextGap.value.toInt(),
                  min: 0,
                  max: 12,
                  onChanged: (e) {
                    AppSettingsController.instance.setChatTextGap(e.toDouble());
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "气泡样式",
                  value: AppSettingsController.instance.chatBubbleStyle.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setChatBubbleStyle(e);
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "更多设置",
            style: Get.textTheme.titleSmall,
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsAction(
                title: "关键词屏蔽",
                onTap: controller.showDanmuShield,
              ),
              AppStyle.divider,
              SettingsAction(
                title: "弹幕设置",
                onTap: controller.showDanmuSettingsSheet,
              ),
              AppStyle.divider,
              SettingsAction(
                title: "定时关闭",
                onTap: controller.showAutoExitSheet,
              ),
              AppStyle.divider,
              SettingsAction(
                title: "画面尺寸",
                onTap: controller.showPlayerSettingsSheet,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildFollowList() {
    return Obx(
      () => Stack(
        children: [
          RefreshIndicator(
            onRefresh: FollowService.instance.loadData,
            child: ListView.builder(
              itemCount: FollowService.instance.liveList.length,
              itemBuilder: (_, i) {
                var item = FollowService.instance.liveList[i];
                return Obx(
                  () => FollowUserItem(
                    item: item,
                    playing: controller.rxSite.value.id == item.siteId &&
                        controller.rxRoomId.value == item.roomId,
                    onTap: () {
                      controller.resetRoom(
                        Sites.allSites[item.siteId]!,
                        item.roomId,
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
            Positioned(
              right: 12,
              bottom: 12,
              child: Obx(
                () => DesktopRefreshButton(
                  refreshing: FollowService.instance.updating.value,
                  onPressed: FollowService.instance.loadData,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> buildAppbarActions(BuildContext context) {
    return [
      Padding(
        padding: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
        child: SliveGlassIconButton(
          icon: Icons.more_horiz_rounded,
          tooltip: '更多操作',
          onPressed: showMore,
        ),
      ),
    ];
  }

  void showMore() {
    showModalBottomSheet(
      context: Get.context!,
      constraints: const BoxConstraints(
        maxWidth: 600,
      ),
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: AppStyle.bottomBarHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text("刷新"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                controller.refreshRoom();
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              trailing: const Icon(Icons.chevron_right),
              title: const Text("切换清晰度"),
              onTap: () {
                Get.back();
                controller.showQualitySheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.switch_video_outlined),
              title: const Text("切换线路"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showPlayUrlsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.aspect_ratio_outlined),
              title: const Text("画面尺寸"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showPlayerSettingsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text("截图"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                controller.saveScreenshot();
              },
            ),
            Visibility(
              visible: Platform.isAndroid,
              child: ListTile(
                leading: const Icon(Icons.picture_in_picture),
                title: const Text("小窗播放"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Get.back();
                  controller.enablePIP();
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text("定时关闭"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showAutoExitSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_sharp),
              title: const Text("分享直播间"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.share();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text("复制链接"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.copyUrl();
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text("APP 中打开"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.openNaviteAPP();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text("播放信息"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showDebugInfo();
              },
            ),
          ],
        ),
      ),
    );
  }

  String parseDuration(int sec) {
    // 转为时分秒
    var h = sec ~/ 3600;
    var m = (sec % 3600) ~/ 60;
    var s = sec % 60;
    if (h > 0) {
      return "${h.toString().padLeft(2, '0')}小时${m.toString().padLeft(2, '0')}分钟${s.toString().padLeft(2, '0')}秒";
    }
    if (m > 0) {
      return "${m.toString().padLeft(2, '0')}分钟${s.toString().padLeft(2, '0')}秒";
    }
    return "${s.toString().padLeft(2, '0')}秒";
  }
}
