import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/services/window_service.dart';
import 'package:window_manager/window_manager.dart';

/// Linux 无边框窗口壳。
///
/// 标题栏位于根 Navigator 之外，因此不会参与页面路由转场；直播全屏和
/// 小窗模式只收起应用内标题栏，不会重新打开系统窗口装饰。
class SliveLinuxWindowFrame extends StatelessWidget {
  const SliveLinuxWindowFrame({
    super.key,
    required this.child,
  });

  static const double titleBarHeight = 44;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final windowService = WindowService.instance;

    return Obx(() {
      final showTitleBar =
          !windowService.isFullScreen.value && !windowService.isPIP.value;
      final canResize = showTitleBar && !windowService.isMaximized.value;

      return DragToResizeArea(
        resizeEdgeSize: 6,
        enableResizeEdges: canResize ? null : const <ResizeEdge>[],
        child: ColoredBox(
          color: context.sliveColors.backgroundBase,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Offstage(
                offstage: !showTitleBar,
                child: SizedBox(
                  height: titleBarHeight,
                  child: _SliveLinuxTitleBar(
                    isFocused: windowService.isFocused.value,
                    isMaximized: windowService.isMaximized.value,
                    onToggleMaximize: windowService.toggleMaximize,
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      );
    });
  }
}

class _SliveLinuxTitleBar extends StatelessWidget {
  const _SliveLinuxTitleBar({
    required this.isFocused,
    required this.isMaximized,
    required this.onToggleMaximize,
  });

  static const double _controlsWidth = 44 * 3;

  final bool isFocused;
  final bool isMaximized;
  final Future<void> Function() onToggleMaximize;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final theme = Theme.of(context);
    final titleColor = colors.textPrimary.withValues(
      alpha: isFocused ? 0.92 : 0.68,
    );
    final iconColor = colors.textPrimary.withValues(
      alpha: isFocused ? 0.80 : 0.58,
    );
    final surface = Color.lerp(
      colors.backgroundStart,
      colors.glassBase,
      theme.brightness == Brightness.dark ? 0.28 : 0.46,
    )!;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          border: Border(
            bottom: BorderSide(
              color: colors.divider.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.14 : 0.10,
              ),
            ),
          ),
        ),
        child: Row(
          children: [
            // 拖动区与窗口按钮拆成兄弟节点，避免全幅 GestureDetector
            // 在部分 Linux/Wayland 组合下抢占按钮命中。左侧保留与右侧
            // 控件等宽的平衡区，使标题始终位于窗口几何中心。
            Expanded(
              child: DragToMoveArea(
                child: Row(
                  children: [
                    const SizedBox(width: _controlsWidth),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Slive',
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 14,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.25,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: _controlsWidth,
              child: Row(
                children: [
                  _WindowControlButton(
                    label: '最小化',
                    icon: Icons.horizontal_rule_rounded,
                    iconColor: iconColor,
                    onPressed: windowManager.minimize,
                  ),
                  _WindowControlButton(
                    label: isMaximized ? '还原' : '最大化',
                    icon: isMaximized
                        ? Icons.filter_none_rounded
                        : Icons.crop_square_rounded,
                    iconColor: iconColor,
                    onPressed: onToggleMaximize,
                  ),
                  _WindowControlButton(
                    label: '关闭',
                    icon: Icons.close_rounded,
                    iconColor: iconColor,
                    hoverColor: colors.danger.withValues(alpha: 0.12),
                    pressedColor: colors.danger.withValues(alpha: 0.18),
                    onPressed: windowManager.close,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
    this.hoverColor,
    this.pressedColor,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Future<void> Function() onPressed;
  final Color? hoverColor;
  final Color? pressedColor;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedHover = widget.hoverColor ??
        theme.colorScheme.primary.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.10 : 0.055,
        );
    final resolvedPressed = widget.pressedColor ??
        theme.colorScheme.primary.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.16 : 0.09,
        );
    final fill = _pressed
        ? resolvedPressed
        : _hovered
            ? resolvedHover
            : Colors.transparent;

    return Semantics(
      button: true,
      label: widget.label,
      // 标题栏位于根 Navigator/Overlay 之外，不能使用 Tooltip：
      // Linux 桌面鼠标进入时 Tooltip 会查找 Overlay 并抛出异常，造成
      // 整个按钮区域变灰、图标消失且点击回调被打断。窗口图标本身已
      // 足够明确，保留 Semantics 标签即可兼顾辅助功能。
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            setState(() => _pressed = false);
            unawaited(widget.onPressed());
          },
          child: SizedBox(
            width: 44,
            height: SliveLinuxWindowFrame.titleBarHeight,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: AnimatedContainer(
                duration: SliveMotion.press,
                curve: SliveMotion.standard,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(widget.icon, size: 17, color: widget.iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
