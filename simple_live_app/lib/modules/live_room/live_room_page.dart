import 'dart:async';
import 'dart:io';

import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:simple_live_app/modules/live_room/chat/huya_chat_identity_spans.dart';
import 'package:simple_live_app/modules/live_room/chat/huya_noble_badge.dart';
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
              body: buildMediaPlayer(
                giftPlacement: controller.smallWindowState.value
                    ? null
                    : HuyaGiftOverlayPlacement.player,
              ),
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
        // 竖屏下即使主播卡与控制栏都已自动隐藏，也保留一段稳定呼吸区，
        // 避免首条弹幕视觉上直接贴入播放器圆角边缘。横屏双栏不使用该间距。
        const SizedBox(height: 10),
        buildMessageArea(context),
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
                      buildMessageArea(
                        context,
                        horizontalPadding: 0,
                        respectLeftSafeArea: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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

  Widget buildMediaPlayer({HuyaGiftOverlayPlacement? giftPlacement}) {
    return Obx(() {
      if (!controller.playerRuntimeReady.value) {
        return const _PlayerWarmupPlaceholder();
      }

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
          if (giftPlacement != null)
            HuyaGiftDanmakuOverlay(
              controller: controller,
              placement: giftPlacement,
            ),
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
    });
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
          // Dock 位于高频滚动/视频附近，使用静态柔和玻璃，避免每帧重采样。
          enableBackdropBlur: false,
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
    bool respectLeftSafeArea = true,
  }) {
    return Expanded(
      child: SafeArea(
        top: false,
        // 横屏双栏时聊天区位于屏幕右侧，设备左侧挖孔已由播放器一侧
        // 承接；若在这里再次应用全局左安全区，会把整列弹幕额外右推。
        // 右侧与底部安全区仍保留，以兼容反向横屏和手势导航区域。
        left: respectLeftSafeArea,
        child: _LiveRoomMessageArea(
          controller: controller,
          horizontalPadding: horizontalPadding,
          profileBuilder: () => buildUserProfile(
            context,
            horizontalMargin: horizontalPadding,
          ),
          messageItemBuilder: buildMessageItem,
          superChatsBuilder: buildSuperChats,
          followListBuilder: buildFollowList,
          settingsBuilder: buildSettings,
          bottomActionsBuilder: () => buildBottomActions(context),
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

      if (isVipEnter) {
        return HuyaVipEnterMessage(
          message: message,
          fontSize: fontSize,
          bubbleStyle: bubbleStyle,
        );
      }

      if (isSystem || isGift) {
        final accent = isGift ? colors.huya : colors.textTertiary;
        final icon = isGift ? Remix.gift_line : Remix.information_line;
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
          children: [
            ...buildHuyaChatIdentitySpans(
              message: message,
              fontSize: fontSize,
            ),
            TextSpan(
              text: "${message.userName}：",
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: message.message,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: fontSize,
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

/// 直播间 Tab 的轻量视口。
///
/// 使用禁用手势的 [PageView] 作为惰性 Sliver 视口：任一时刻只有当前页
/// 参与布局与绘制，已访问页面由 keep-alive bucket 保存状态，不会像
/// [Offstage] / [IndexedStack] 那样继续挂在活动 RenderObject 子链中布局。
/// 索引变化直接跳页，只有新页面执行短距离 transform 合成动画。

class _PlayerWarmupPlaceholder extends StatelessWidget {
  const _PlayerWarmupPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.live_tv_rounded, size: 28, color: Colors.white54),
            SizedBox(height: 8),
            Text(
              '正在准备播放器',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveRoomTabViewport extends StatefulWidget {
  const LiveRoomTabViewport({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutQuart,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;
  final Curve curve;

  @override
  State<LiveRoomTabViewport> createState() => _LiveRoomTabViewportState();
}

class _LiveRoomTabViewportState extends State<LiveRoomTabViewport>
    with SingleTickerProviderStateMixin {
  static const double _enterOffset = 5;

  late final AnimationController _animationController;
  late final ValueNotifier<int> _activeIndexNotifier;
  late final PageController _pageController;
  late int _currentIndex;
  int _direction = 1;
  bool _pageSyncScheduled = false;

  int _safeIndex(int value) {
    if (widget.children.isEmpty) return 0;
    return value.clamp(0, widget.children.length - 1);
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void initState() {
    super.initState();
    _currentIndex = _safeIndex(widget.index);
    _activeIndexNotifier = ValueNotifier<int>(_currentIndex);
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion && _animationController.isAnimating) {
      _animationController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant LiveRoomTabViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _animationController.duration = widget.duration;
    }

    if (widget.children.isEmpty) {
      _currentIndex = 0;
      _activeIndexNotifier.value = 0;
      _animationController.value = 1;
      return;
    }

    final nextIndex = _safeIndex(widget.index);
    if (nextIndex == _currentIndex) {
      return;
    }

    _direction = nextIndex > _currentIndex ? 1 : -1;
    _currentIndex = nextIndex;
    // 先停用旧页 Ticker/焦点/语义，再跳转 Sliver 视口，避免切换首帧
    // 聊天礼物动画或列表内动画继续在 keep-alive bucket 中后台运行。
    _activeIndexNotifier.value = nextIndex;
    _syncPagePosition();
    if (_reduceMotion || widget.duration == Duration.zero) {
      _animationController.value = 1;
    } else {
      // forward(from: 0) 会立即中断前一次过渡，连续快速点击无需等待队列。
      _animationController.forward(from: 0);
    }
  }

  void _syncPagePosition() {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentIndex);
      return;
    }
    if (_pageSyncScheduled) return;
    _pageSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageSyncScheduled = false;
      if (!mounted || !_pageController.hasClients || widget.children.isEmpty) {
        return;
      }
      _pageController.jumpToPage(_currentIndex);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _activeIndexNotifier.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    final pageView = PageView.custom(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      pageSnapping: false,
      allowImplicitScrolling: false,
      clipBehavior: Clip.hardEdge,
      childrenDelegate: SliverChildBuilderDelegate(
        (context, index) => ValueListenableBuilder<int>(
          valueListenable: _activeIndexNotifier,
          child: KeepAliveWrapper(
            child: KeyedSubtree(
              key: PageStorageKey<int>(index),
              child: widget.children[index],
            ),
          ),
          builder: (context, activeIndex, child) {
            final active = activeIndex == index;
            return TickerMode(
              enabled: active,
              child: IgnorePointer(
                ignoring: !active,
                child: ExcludeFocus(
                  excluding: !active,
                  child: ExcludeSemantics(
                    excluding: !active,
                    child: child!,
                  ),
                ),
              ),
            );
          },
        ),
        childCount: widget.children.length,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: false,
        addSemanticIndexes: false,
      ),
    );

    return ClipRect(
      child: AnimatedBuilder(
        animation: _animationController,
        child: pageView,
        builder: (context, child) {
          final progress = widget.curve.transform(_animationController.value);
          final offset = _direction * _enterOffset * (1 - progress);
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
      ),
    );
  }
}

class _LiveRoomMessageArea extends StatefulWidget {
  const _LiveRoomMessageArea({
    required this.controller,
    required this.horizontalPadding,
    required this.profileBuilder,
    required this.messageItemBuilder,
    required this.superChatsBuilder,
    required this.followListBuilder,
    required this.settingsBuilder,
    required this.bottomActionsBuilder,
  });

  final LiveRoomController controller;
  final double horizontalPadding;
  final Widget Function() profileBuilder;
  final Widget Function(BuildContext context, LiveMessage message)
      messageItemBuilder;
  final Widget Function() superChatsBuilder;
  final Widget Function() followListBuilder;
  final Widget Function() settingsBuilder;
  final Widget Function() bottomActionsBuilder;

  @override
  State<_LiveRoomMessageArea> createState() => _LiveRoomMessageAreaState();
}

class _LiveRoomMessageAreaState extends State<_LiveRoomMessageArea>
    with SingleTickerProviderStateMixin {
  static const Duration _chatTabHideDelay = Duration(milliseconds: 2800);
  static const Duration _bottomDockHideDelay = Duration(milliseconds: 2300);
  static const Duration _tabSwitchDuration = Duration(milliseconds: 180);
  static const double _tabBarHeight = 42;
  static const double _tabContentInset = 50;

  late final TabController _tabController;
  late final List<Widget> _tabPages;
  Timer? _hideTimer;
  Timer? _bottomDockHideTimer;
  int _activeIndex = 0;
  bool _tabsVisible = true;
  bool _bottomActionsVisible = true;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    // 页面 Widget 只创建一次：首次访问时由 LiveRoomTabViewport 懒挂载，
    // 后续切换保留 Element/滚动状态，避免设置列表等重型子树反复重建。
    _tabPages = <Widget>[
      Builder(builder: _buildChatTab),
      Builder(builder: (_) => _withTabInset(widget.superChatsBuilder())),
      Builder(builder: (_) => _withTabInset(widget.followListBuilder())),
      Builder(builder: (_) => _withTabInset(widget.settingsBuilder())),
    ];
    _tabController = TabController(
      length: 4,
      vsync: this,
      animationDuration: _tabSwitchDuration,
    )..addListener(_handleTabControllerChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleAutoHide();
      _scheduleBottomActionsAutoHide();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _bottomDockHideTimer?.cancel();
    _tabController
      ..removeListener(_handleTabControllerChange)
      ..dispose();
    super.dispose();
  }

  void _handleTabControllerChange() {
    final nextIndex = _tabController.index;
    if (_activeIndex == nextIndex) return;
    setState(() => _activeIndex = nextIndex);
    _showTabs(scheduleAutoHide: nextIndex == 0);
  }

  void _scheduleAutoHide() {
    _hideTimer?.cancel();
    if (_activeIndex != 0) return;
    _hideTimer = Timer(_chatTabHideDelay, _hideTabs);
  }

  void _showTabs({bool scheduleAutoHide = true}) {
    _hideTimer?.cancel();
    if (!_tabsVisible && mounted) {
      setState(() => _tabsVisible = true);
    }
    if (scheduleAutoHide && _activeIndex == 0) {
      _scheduleAutoHide();
    }
  }

  void _hideTabs() {
    _hideTimer?.cancel();
    if (!mounted || _activeIndex != 0 || !_tabsVisible) return;
    setState(() => _tabsVisible = false);
  }

  void _scheduleBottomActionsAutoHide() {
    _bottomDockHideTimer?.cancel();
    _bottomDockHideTimer = Timer(_bottomDockHideDelay, _hideBottomActions);
  }

  void _showBottomActions({bool scheduleAutoHide = true}) {
    _bottomDockHideTimer?.cancel();
    if (!_bottomActionsVisible && mounted) {
      setState(() => _bottomActionsVisible = true);
    }
    if (scheduleAutoHide) {
      _scheduleBottomActionsAutoHide();
    }
  }

  void _hideBottomActions() {
    _bottomDockHideTimer?.cancel();
    if (!mounted || !_bottomActionsVisible) return;
    setState(() => _bottomActionsVisible = false);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activeIndex == 0) {
      _showTabs();
    }
    _showBottomActions();
  }

  bool _handleChatScroll(UserScrollNotification notification) {
    if (_activeIndex != 0) return false;
    switch (notification.direction) {
      case ScrollDirection.reverse:
      case ScrollDirection.forward:
        _hideTabs();
        _hideBottomActions();
        break;
      case ScrollDirection.idle:
        if (_tabsVisible) _scheduleAutoHide();
        if (_bottomActionsVisible) _scheduleBottomActionsAutoHide();
        break;
    }
    return false;
  }

  Duration get _visibilityDuration =>
      _disableAnimations ? Duration.zero : SliveMotion.selection;

  Widget _buildAutoHidingProfile() {
    final visible = _activeIndex == 0 && _tabsVisible;
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedCrossFade(
          firstChild: RepaintBoundary(child: widget.profileBuilder()),
          secondChild: const SizedBox(width: double.infinity),
          crossFadeState:
              visible ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: _visibilityDuration,
          reverseDuration: _visibilityDuration,
          firstCurve: SliveMotion.standard,
          secondCurve: SliveMotion.standard,
          sizeCurve: SliveMotion.standard,
          alignment: Alignment.topCenter,
          excludeBottomFocus: true,
        ),
      ),
    );
  }

  Widget _buildBottomOcclusionMask(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomColor = Color.lerp(
      colors.backgroundEnd,
      colors.glassBase,
      isDark ? 0.10 : 0.20,
    )!;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: SizedBox(
            height: 96,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Dock 出现时扩大遮挡范围，避免半透明玻璃下方仍能看到
                // 被裁切的弹幕。Dock 隐藏只收起这一层，不影响永久边缘遮罩。
                Positioned.fill(
                  child: AnimatedOpacity(
                    key: const ValueKey('live-room-bottom-dock-mask'),
                    duration: _visibilityDuration,
                    curve: SliveMotion.standard,
                    opacity: _bottomActionsVisible ? 1 : 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.46, 1],
                          colors: [
                            bottomColor.withValues(alpha: 0),
                            bottomColor.withValues(
                              alpha: isDark ? 0.70 : 0.78,
                            ),
                            bottomColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 这层始终保留。新弹幕追底或 Dock 刚隐藏时，列表项会从
                // 可视区域底边逐步进入；用短距离柔和遮罩隐藏不足一行的
                // “小冒头”，避免它贴着系统手势导航条闪一下。
                SizedBox(
                  key: const ValueKey('live-room-bottom-edge-mask'),
                  height: 42,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.34, 0.72, 1],
                        colors: [
                          bottomColor.withValues(alpha: 0),
                          bottomColor.withValues(alpha: isDark ? 0.16 : 0.20),
                          bottomColor.withValues(alpha: isDark ? 0.88 : 0.92),
                          bottomColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: Column(
        children: [
          _buildAutoHidingProfile(),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                LiveRoomTabViewport(
                  index: _activeIndex,
                  duration: _tabSwitchDuration,
                  children: _tabPages,
                ),
                Positioned(
                  top: 4,
                  left: widget.horizontalPadding,
                  right: widget.horizontalPadding,
                  child: IgnorePointer(
                    ignoring: !_tabsVisible,
                    child: AnimatedSlide(
                      duration: _visibilityDuration,
                      curve: SliveMotion.standard,
                      offset:
                          _tabsVisible ? Offset.zero : const Offset(0, -0.28),
                      child: AnimatedOpacity(
                        duration: _visibilityDuration,
                        curve: SliveMotion.standard,
                        opacity: _tabsVisible ? 1 : 0,
                        child: RepaintBoundary(child: _buildTabBar(context)),
                      ),
                    ),
                  ),
                ),
                // 底栏初次出现和自动滚动追底时，列表仍会在半透明 Dock
                // 下方绘制。用同节奏的轻量渐隐层遮住被裁切的半行文字，
                // 避免系统导航栏上方短暂“冒头”，同时不改变列表尺寸和滚动位置。
                _buildBottomOcclusionMask(context),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !_bottomActionsVisible,
                    child: ExcludeSemantics(
                      excluding: !_bottomActionsVisible,
                      child: AnimatedSlide(
                        duration: _visibilityDuration,
                        curve: SliveMotion.standard,
                        offset: _bottomActionsVisible
                            ? Offset.zero
                            : const Offset(0, 1.10),
                        child: AnimatedOpacity(
                          duration: _visibilityDuration,
                          curve: SliveMotion.standard,
                          opacity: _bottomActionsVisible ? 1 : 0,
                          child: RepaintBoundary(
                            child: widget.bottomActionsBuilder(),
                          ),
                        ),
                      ),
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

  Widget _buildChatTab(BuildContext context) {
    return Obx(() {
      final gap = AppSettingsController.instance.chatTextGap.value * 2;
      return NotificationListener<UserScrollNotification>(
        onNotification: _handleChatScroll,
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView.separated(
                controller: widget.controller.scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                addAutomaticKeepAlives: false,
                separatorBuilder: (_, i) => SizedBox(height: gap),
                // Tab 栏是浮层：隐藏后不继续占用顶部空间，避免出现一条
                // 无意义的空白带；同时不动画 padding，防止滚动位置抖动。
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                itemCount: widget.controller.messages.length,
                itemBuilder: (_, i) {
                  final item = widget.controller.messages[i];
                  return widget.messageItemBuilder(context, item);
                },
              ),
            ),
            HuyaGiftDanmakuOverlay(
              controller: widget.controller,
              placement: HuyaGiftOverlayPlacement.chat,
            ),
            if (widget.controller.disableAutoScroll.value)
              Positioned(
                right: 12,
                bottom: 10,
                child: SizedBox(
                  height: 34,
                  child: SliveGlassSurface(
                    variant: SliveGlassVariant.pill,
                    enableBackdropBlur: false,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onTap: widget.controller.resumeChatAutoScroll,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_downward_rounded, size: 14),
                        SizedBox(width: 4),
                        Text(
                          '最新',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _withTabInset(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: _tabContentInset),
      child: child,
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final colors = context.sliveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: _tabBarHeight,
      child: SliveGlassSurface(
        variant: SliveGlassVariant.pill,
        enableBackdropBlur: false,
        showShadow: false,
        shadowColor: Colors.transparent,
        child: TabBar(
          controller: _tabController,
          onTap: (index) {
            _showTabs(scheduleAutoHide: index == 0);
          },
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorAnimation: TabIndicatorAnimation.elastic,
          indicatorPadding: const EdgeInsets.all(2),
          labelPadding: EdgeInsets.zero,
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          indicator: BoxDecoration(
            color: colors.glassStrong.withValues(
              alpha: isDark ? 0.16 : 0.82,
            ),
            borderRadius: BorderRadius.circular(SliveRadii.pill),
          ),
          tabs: [
            const Tab(text: '聊天'),
            Tab(
              child: Obx(
                () => Text(
                  widget.controller.superChats.isNotEmpty
                      ? 'SC(${widget.controller.superChats.length})'
                      : 'SC',
                ),
              ),
            ),
            const Tab(text: '关注'),
            const Tab(text: '设置'),
          ],
        ),
      ),
    );
  }
}
