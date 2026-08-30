import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_icon_button.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/live_room_card.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';
import 'package:simple_live_core/simple_live_core.dart';

class FollowUserPage extends GetView<FollowUserController> {
  const FollowUserPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final isPortrait = mediaQuery.orientation == Orientation.portrait;
    var compactColumnCount = width ~/ 500;
    if (compactColumnCount < 1) compactColumnCount = 1;
    var cardColumnCount = width ~/ 200;
    if (cardColumnCount < 2) cardColumnCount = 2;

    final bottomContentPadding = mediaQuery.viewPadding.bottom +
        (isPortrait
            ? SliveLayout.bottomDockHeight + SliveLayout.bottomDockGap + 14
            : 16);
    final listPadding = EdgeInsets.fromLTRB(
      SliveLayout.pageHorizontal,
      4,
      SliveLayout.pageHorizontal,
      bottomContentPadding,
    );

    return SlivePageScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        leadingWidth: 68,
        leading: SizedBox(
          width: 68,
          child: Align(
            alignment: Alignment.center,
            child: Obx(
              () => _FollowRefreshButton(
                updating: FollowService.instance.updating.value,
                onPressed: controller.refreshData,
              ),
            ),
          ),
        ),
        title: Text(
          '关注用户',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: context.sliveColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.28,
              ),
        ),
        actions: [
          SizedBox(
            width: 68,
            child: Align(
              alignment: Alignment.center,
              child: _FollowMoreMenuButton(
                onSelected: _handleMenuSelection,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SliveLayout.pageHorizontal,
              2,
              SliveLayout.pageHorizontal,
              10,
            ),
            child: Obx(
              () => FollowFilterBar(
                options: controller.tagList.toList(growable: false),
                selectedId: controller.filterMode.value.id,
                onSelected: controller.setFilterMode,
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => AppSettingsController.instance.followStyleNotGrid.value
                  ? PageGridView(
                      padding: listPadding,
                      crossAxisSpacing: SliveLayout.gridGap,
                      mainAxisSpacing: 10,
                      crossAxisCount: compactColumnCount,
                      pageController: controller,
                      firstRefresh: true,
                      showPCRefreshButton: false,
                      itemBuilder: (_, index) {
                        final item = controller.list[index];
                        final site = Sites.allSites[item.siteId]!;
                        return SliveGlassSurface(
                          variant: SliveGlassVariant.card,
                          radius: SliveRadii.card,
                          enableBackdropBlur: false,
                          child: FollowUserItem(
                            item: item,
                            onRemove: () => controller.removeFollow(item),
                            onTap: () => AppNavigator.toLiveRoomDetail(
                              site: site,
                              roomId: item.roomId,
                            ),
                            onLongPress: () => controller.showBottomMenu(item),
                          ),
                        );
                      },
                    )
                  : KeepAliveWrapper(
                      child: Obx(
                        () {
                          final hideRemoveButton = AppSettingsController
                              .instance.hideRemoveFollowButton.value;
                          return PageGridView(
                            pageController: controller,
                            padding: listPadding,
                            firstRefresh: true,
                            mainAxisSpacing: SliveLayout.gridGap,
                            crossAxisSpacing: SliveLayout.gridGap,
                            crossAxisCount: cardColumnCount,
                            showPCRefreshButton: false,
                            itemBuilder: (_, index) {
                              final item = controller.list[index];
                              final liveRoomItem = LiveRoomItem(
                                roomId: item.roomId,
                                title: item.title.value,
                                cover: item.cover.value,
                                userName: item.userName,
                                online: item.online.value,
                              );
                              final site = Sites.allSites[item.siteId]!;
                              return LiveRoomCard(
                                site,
                                liveRoomItem,
                                onFollowRemove: hideRemoveButton
                                    ? null
                                    : () => controller.removeFollow(item),
                                onLongPress: () =>
                                    controller.showBottomMenu(item),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuSelection(int value) {
    switch (value) {
      case 0:
        SmartDialog.showToast('此功能暂未开放！敬请期待！');
      case 1:
        controller.showFollowStyleDialog();
      case 2:
        controller.showSortDialog();
      case 4:
        Get.toNamed(RoutePath.kSettingsFollow);
    }
  }
}

/// 关注页紧凑筛选栏。
///
/// 外层玻璃条保持页面宽度，内部选项按内容宽度紧凑排列。选中项只增加一层
/// 无描边的柔和玻璃底色，不再使用会在宽屏和手机上拉伸错位的等分滑块。
@visibleForTesting
class FollowFilterBar extends StatelessWidget {
  const FollowFilterBar({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  final List<FollowUserTag> options;
  final String selectedId;
  final ValueChanged<FollowUserTag> onSelected;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    final colors = context.sliveColors;
    return SizedBox(
      key: const ValueKey('follow-filter-bar'),
      height: 44,
      child: SliveGlassSurface(
        variant: SliveGlassVariant.pill,
        radius: SliveRadii.pill,
        enableBackdropBlur: false,
        showShadow: false,
        shadowColor: Colors.transparent,
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.all(3),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < options.length; index++) ...[
                if (index > 0) const SizedBox(width: 2),
                _FollowFilterSegment(
                  key: ValueKey(options[index].id),
                  id: options[index].id,
                  text: options[index].tag,
                  selected: options[index].id == selectedId,
                  indicatorColor:
                      options[index].tag == '直播中' ? colors.success : null,
                  onTap: () => onSelected(options[index]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowFilterSegment extends StatefulWidget {
  const _FollowFilterSegment({
    super.key,
    required this.id,
    required this.text,
    required this.selected,
    required this.onTap,
    this.indicatorColor,
  });

  final String id;
  final String text;
  final bool selected;
  final VoidCallback onTap;
  final Color? indicatorColor;

  @override
  State<_FollowFilterSegment> createState() => _FollowFilterSegmentState();
}

class _FollowFilterSegmentState extends State<_FollowFilterSegment> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.sliveColors;
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final selectionDuration =
        reduceMotion ? Duration.zero : SliveMotion.selection;
    final pressDuration = reduceMotion ? Duration.zero : SliveMotion.press;
    final activeColor = Color.lerp(
      theme.colorScheme.primary,
      colors.textPrimary,
      isDark ? 0.12 : 0.08,
    )!;
    final inactiveColor = colors.textSecondary.withValues(
      alpha: isDark ? 0.86 : 0.76,
    );
    final selectedBase = Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: isDark ? 0.11 : 0.065),
      colors.glassStrong.withValues(alpha: isDark ? 0.48 : 0.94),
    );
    final selectedTop = Color.alphaBlend(
      Colors.white.withValues(alpha: isDark ? 0.025 : 0.18),
      selectedBase,
    );

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.text,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: AnimatedScale(
            scale: _pressed ? 0.975 : 1,
            duration: pressDuration,
            curve: SliveMotion.standard,
            child: TweenAnimationBuilder<double>(
              duration: selectionDuration,
              curve: SliveMotion.standard,
              tween: Tween<double>(
                begin: widget.selected ? 1 : 0,
                end: widget.selected ? 1 : 0,
              ),
              builder: (context, selectionProgress, child) {
                final foreground = Color.lerp(
                  inactiveColor,
                  activeColor,
                  selectionProgress,
                )!;
                final transparent = selectedBase.withValues(alpha: 0);

                return ConstrainedBox(
                  key: ValueKey('follow-filter-slot-${widget.id}'),
                  constraints: const BoxConstraints(
                    minWidth: 96,
                    minHeight: 38,
                  ),
                  child: DecoratedBox(
                    key: widget.selected
                        ? const ValueKey('follow-filter-selection')
                        : null,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(
                            transparent,
                            selectedTop,
                            selectionProgress,
                          )!,
                          Color.lerp(
                            transparent,
                            selectedBase,
                            selectionProgress,
                          )!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(SliveRadii.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.indicatorColor != null) ...[
                            _FollowLiveStatusDot(
                              color: widget.indicatorColor!,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            widget.text,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: foreground,
                              fontSize: 13,
                              height: 1,
                              letterSpacing: 0.02,
                              fontWeight: FontWeight.lerp(
                                FontWeight.w600,
                                FontWeight.w800,
                                selectionProgress,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowLiveStatusDot extends StatefulWidget {
  const _FollowLiveStatusDot({required this.color});

  final Color color;

  @override
  State<_FollowLiveStatusDot> createState() => _FollowLiveStatusDotState();
}

class _FollowLiveStatusDotState extends State<_FollowLiveStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  void _syncAnimation() {
    final shouldAnimate = !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (_isAnimating == shouldAnimate) return;
    _isAnimating = shouldAnimate;
    if (shouldAnimate) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.90),
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(dimension: 6),
    );

    if (!_isAnimating) {
      return SizedBox.square(
        dimension: 10,
        child: Center(child: dot),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      child: dot,
      builder: (context, child) {
        final progress = Curves.easeInOut.transform(_controller.value);
        return SizedBox.square(
          dimension: 10,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.16 * (1 - progress),
                child: Transform.scale(
                  scale: 0.82 + (progress * 0.68),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 10),
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.95 + (progress * 0.06),
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FollowRefreshButton extends StatelessWidget {
  const _FollowRefreshButton({
    required this.updating,
    required this.onPressed,
  });

  final bool updating;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : SliveMotion.selection;

    return Semantics(
      button: true,
      enabled: !updating,
      label: updating ? '正在刷新关注状态' : '刷新关注状态',
      child: ExcludeSemantics(
        child: SliveGlassSurface(
          variant: SliveGlassVariant.pill,
          radius: SliveRadii.pill,
          enableBackdropBlur: true,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          onTap: updating ? null : onPressed,
          child: Center(
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: SliveMotion.standard,
              switchOutCurve: SliveMotion.standard,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: updating
                  ? reduceMotion
                      ? Icon(
                          Icons.sync_rounded,
                          key: const ValueKey('refreshing-static'),
                          size: 20,
                          color: context.sliveColors.textSecondary,
                        )
                      : SizedBox.square(
                          key: const ValueKey('refreshing-progress'),
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            strokeCap: StrokeCap.round,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                  : Icon(
                      Icons.refresh_rounded,
                      key: const ValueKey('refresh-idle'),
                      size: 22,
                      color: context.sliveColors.textPrimary,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowMoreMenuButton extends StatelessWidget {
  const _FollowMoreMenuButton({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final materials = context.sliveMaterials;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget menuItem({
      required int value,
      required IconData icon,
      required String label,
    }) {
      return MenuItemButton(
        onPressed: () => onSelected(value),
        leadingIcon: Icon(
          icon,
          size: 19,
          color: colors.textSecondary,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        alignment: AlignmentDirectional.topEnd,
        backgroundColor: WidgetStatePropertyAll(
          colors.glassStrong.withValues(alpha: isDark ? 0.96 : 0.94),
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(
          const Color(0xFF8E7E6E).withValues(alpha: isDark ? 0.24 : 0.14),
        ),
        elevation: const WidgetStatePropertyAll(12),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(176, 0)),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: colors.glassBorder.withValues(
              alpha: materials.borderOpacity * (isDark ? 0.58 : 0.84),
            ),
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SliveRadii.control),
          ),
        ),
      ),
      menuChildren: [
        menuItem(value: 0, icon: Remix.trophy_line, label: '赛事订阅'),
        menuItem(value: 1, icon: Remix.blender_line, label: '模式切换'),
        menuItem(value: 2, icon: Remix.sort_asc, label: '按序排列'),
        menuItem(value: 4, icon: Remix.heart_line, label: '关注设置'),
      ],
      builder: (context, menuController, child) {
        return SliveGlassIconButton(
          icon: Icons.more_horiz_rounded,
          tooltip: '更多操作',
          size: 44,
          enableBackdropBlur: true,
          onPressed: () {
            if (menuController.isOpen) {
              menuController.close();
            } else {
              menuController.open();
            }
          },
        );
      },
    );
  }
}
