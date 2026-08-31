import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 直播间专用的轻量顶层页面转场。
///
/// 普通页面使用 Flutter 平台原生转场；播放器页面包含持续更新的原生纹理，
/// 因此不制作整页快照，也不通过 [secondaryAnimation] 移动下层页面。进入时仅
/// 当前直播间从右侧滑入，返回时立即向右退出，首页始终保持静止。
class SliveRouteTransition extends CustomTransition {
  static const Curve _enterCurve = Curves.easeOutCubic;
  static const Curve _exitCurve = Curves.easeInCubic;

  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final routeSurface = ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 1),
      child: child,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return routeSurface;
    }

    final position = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: _enterCurve,
        reverseCurve: _exitCurve,
      ),
    );

    return ClipRect(
      child: SlideTransition(
        position: position,
        transformHitTests: false,
        child: routeSurface,
      ),
    );
  }
}
