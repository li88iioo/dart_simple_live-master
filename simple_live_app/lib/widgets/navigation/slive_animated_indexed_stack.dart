import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';

/// 惰性保活页面、且任一时刻只展示当前页的主导航切换容器。
///
/// 与 [IndexedStack]/[Offstage] 不同，这里使用 [PageView.custom] 的 sliver
/// keep-alive bucket 保存已访问页面：离屏页面保持 State，但不会让全部四页在每次
/// 父布局时一起参与 layout。导航时先 [PageController.jumpToPage] 立即替换当前页，
/// 再只对单一 PageView 做固定像素 translate，不交叉绘制两页，也不创建整页
/// Opacity/RepaintBoundary 中间纹理。
class SliveAnimatedIndexedStack extends StatefulWidget {
  const SliveAnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = defaultDuration,
    this.transitionDistance = 7,
    this.prebuildMountedChildren = false,
    this.precacheAdjacentPages = false,
  });

  static const Duration defaultDuration = Duration(milliseconds: 150);

  final int index;
  final List<Widget> children;
  final Duration duration;
  final double transitionDistance;

  /// 将已经提供的页面保持在同一个 Stack 中，适合少量、需要后台预热的页面。
  /// 未选中的页面停止 ticker、交互和语义，并且不会参与绘制。
  final bool prebuildMountedChildren;

  /// 让 PageView 额外缓存相邻页面，降低平台 Tab 首次切换的构建峰值。
  final bool precacheAdjacentPages;

  @override
  State<SliveAnimatedIndexedStack> createState() =>
      _SliveAnimatedIndexedStackState();
}

class _SliveAnimatedIndexedStackState extends State<SliveAnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late int _currentIndex = _safeIndex(widget.index);
  late final ValueNotifier<int> _activeIndex = ValueNotifier<int>(
    _currentIndex,
  );
  late final PageController _pageController = PageController(
    initialPage: _currentIndex,
  );
  late final AnimationController _transitionController = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );

  int _direction = 1;

  int _safeIndex(int value) {
    if (widget.children.isEmpty) return 0;
    return value.clamp(0, widget.children.length - 1);
  }

  @override
  void didUpdateWidget(covariant SliveAnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _transitionController.duration = widget.duration;
    }

    if (widget.children.isEmpty) {
      _currentIndex = 0;
      _transitionController.value = 1;
      return;
    }

    final nextIndex = _safeIndex(widget.index);
    if (nextIndex == _currentIndex) return;

    _direction = nextIndex > _currentIndex ? 1 : -1;
    _currentIndex = nextIndex;
    _activeIndex.value = nextIndex;
    if (!widget.prebuildMountedChildren) {
      _jumpToCurrentPage();
    }

    // forward(from: 0) 可立即中断上一次位移；PageView 已通过 jumpToPage
    // 切到新页，因此动画期间只有新页被绘制。
    if (MediaQuery.disableAnimationsOf(context) ||
        widget.duration == Duration.zero ||
        widget.transitionDistance == 0) {
      _transitionController.value = 1;
    } else {
      _transitionController.forward(from: 0);
    }
  }

  void _jumpToCurrentPage() {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentIndex);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(_currentIndex);
    });
  }

  @override
  void dispose() {
    _transitionController.dispose();
    _pageController.dispose();
    _activeIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animation = reduceMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : _transitionController;

    final pageHost = widget.prebuildMountedChildren
        ? Stack(
            fit: StackFit.expand,
            children: List<Widget>.generate(
              widget.children.length,
              (index) {
                final active = index == _currentIndex;
                return Positioned.fill(
                  child: Offstage(
                    offstage: !active,
                    child: TickerMode(
                      enabled: active,
                      child: ExcludeFocus(
                        excluding: !active,
                        child: ExcludeSemantics(
                          excluding: !active,
                          child: IgnorePointer(
                            ignoring: !active,
                            child: widget.children[index],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              growable: false,
            ),
          )
        : PageView.custom(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            allowImplicitScrolling: widget.precacheAdjacentPages,
            childrenDelegate: SliverChildBuilderDelegate(
              (context, index) => _KeepAliveIndexedPage(
                key: ValueKey<int>(index),
                index: index,
                activeIndex: _activeIndex,
                child: widget.children[index],
              ),
              childCount: widget.children.length,
              addAutomaticKeepAlives: true,
              addRepaintBoundaries: false,
              addSemanticIndexes: false,
            ),
          );

    if (reduceMotion || widget.transitionDistance == 0) {
      return ClipRect(child: pageHost);
    }

    return ClipRect(
      child: AnimatedBuilder(
        animation: animation,
        child: pageHost,
        builder: (context, child) {
          final progress = SliveMotion.standard.transform(animation.value);
          final horizontalOffset =
              _direction * widget.transitionDistance * (1 - progress);
          return Transform.translate(
            key: const ValueKey<String>('slive-indexed-page-transition'),
            offset: Offset(horizontalOffset, 0),
            child: child,
          );
        },
      ),
    );
  }
}

/// 将 [TabController] 的离散索引变化桥接到惰性页面栈。
///
/// TabController 的 animation 会逐帧通知监听者；这里仅在 index 真正变化时
/// setState 一次，避免平台切换的 150ms 内反复重建重型列表。
class SliveTabIndexedStack extends StatefulWidget {
  const SliveTabIndexedStack({
    super.key,
    required this.controller,
    required this.children,
    this.duration = SliveAnimatedIndexedStack.defaultDuration,
    this.transitionDistance = 0,
    this.prebuildChildren = true,
    this.precacheAdjacentPages = true,
  });

  final TabController controller;
  final List<Widget> children;
  final Duration duration;
  final double transitionDistance;

  /// 平台数量很少且页面网络请求由控制器按选中项触发。预构建空页面后用
  /// Offstage 切换，避免 PageView.jumpToPage 在重列表之间重新布局。
  final bool prebuildChildren;
  final bool precacheAdjacentPages;

  @override
  State<SliveTabIndexedStack> createState() => _SliveTabIndexedStackState();
}

class _SliveTabIndexedStackState extends State<SliveTabIndexedStack> {
  late int _index = _resolveIndex();
  int? _pendingIndex;
  bool _switchScheduled = false;

  int _resolveIndex() {
    if (widget.children.isEmpty) return 0;
    return widget.controller.index.clamp(0, widget.children.length - 1);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant SliveTabIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
      _pendingIndex = null;
      _switchScheduled = false;
      _index = _resolveIndex();
      return;
    }

    // 普通父级重建不应越过已经排队的一帧内容切换，否则胶囊反馈与重型
    // 页面构建又会回到同一帧。仅在 children 的有效索引范围变化时校正。
    if (oldWidget.children.length != widget.children.length) {
      _index = _resolveIndex();
    }
  }

  void _handleControllerChange() {
    final nextIndex = _resolveIndex();
    if (!mounted || nextIndex == _index) return;

    // TabController.animateTo 会先同步修改 index，再开始选中胶囊动画。
    // 将重型内容页延后一帧切换，保证点击后的第一帧先展示导航反馈，
    // 避免首次构建列表把整段胶囊动画堵在同一个 UI 帧里。
    _pendingIndex = nextIndex;
    if (_switchScheduled) return;
    _switchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _switchScheduled = false;
      if (!mounted) return;
      final targetIndex = _pendingIndex;
      _pendingIndex = null;
      if (targetIndex == null || targetIndex == _index) return;
      setState(() => _index = targetIndex);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliveAnimatedIndexedStack(
      index: _index,
      duration: widget.duration,
      transitionDistance: widget.transitionDistance,
      prebuildMountedChildren: widget.prebuildChildren,
      precacheAdjacentPages: widget.precacheAdjacentPages,
      children: widget.children,
    );
  }
}

class _KeepAliveIndexedPage extends StatefulWidget {
  const _KeepAliveIndexedPage({
    super.key,
    required this.index,
    required this.activeIndex,
    required this.child,
  });

  final int index;
  final ValueListenable<int> activeIndex;
  final Widget child;

  @override
  State<_KeepAliveIndexedPage> createState() => _KeepAliveIndexedPageState();
}

class _KeepAliveIndexedPageState extends State<_KeepAliveIndexedPage>
    with AutomaticKeepAliveClientMixin<_KeepAliveIndexedPage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<int>(
      valueListenable: widget.activeIndex,
      child: widget.child,
      builder: (context, activeIndex, child) {
        final active = activeIndex == widget.index;
        return TickerMode(
          enabled: active,
          child: ExcludeFocus(
            excluding: !active,
            child: ExcludeSemantics(
              excluding: !active,
              child: IgnorePointer(
                ignoring: !active,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
