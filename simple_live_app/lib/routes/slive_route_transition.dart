import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';

/// Slive 的轻量页面过渡。
///
/// 页面始终保持不透明，只用固定像素的水平 transform 完成推进/返回。
/// 这样不会像全屏 FadeTransition 那样为玻璃页面创建大面积透明合成层，
/// 也不会在返回时把前后两页文字叠在一起形成残影。固定像素位移还能避免
/// PC 宽屏下按页面宽度计算位移过大、看起来迟钝。
class SliveRouteTransition extends CustomTransition {
  static const double _incomingDistance = 18;
  static const double _coveredDistance = -5;

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
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
    if (MediaQuery.disableAnimationsOf(context)) return routeSurface;

    final primaryMotion = CurvedAnimation(
      parent: animation,
      curve: curve ?? SliveMotion.standard,
      // reverse 时动画值从 1 向 0 变化。easeInCubic 在靠近 1 的区间
      // 立即产生可见位移，避免点击返回后先停顿一帧。
      reverseCurve: Curves.easeInCubic,
    );
    final secondaryMotion = CurvedAnimation(
      parent: secondaryAnimation,
      curve: SliveMotion.standard,
      reverseCurve: Curves.easeInCubic,
    );
    final routeOffset = Tween<double>(
      begin: _incomingDistance,
      end: 0,
    ).animate(primaryMotion);
    final coveredRouteOffset = Tween<double>(
      begin: 0,
      end: _coveredDistance,
    ).animate(secondaryMotion);

    return AnimatedBuilder(
      animation: secondaryMotion,
      child: AnimatedBuilder(
        animation: primaryMotion,
        child: routeSurface,
        builder: (context, child) => Transform.translate(
          offset: Offset(routeOffset.value, 0),
          child: child,
        ),
      ),
      builder: (context, child) => Transform.translate(
        offset: Offset(coveredRouteOffset.value, 0),
        child: child,
      ),
    );
  }
}
