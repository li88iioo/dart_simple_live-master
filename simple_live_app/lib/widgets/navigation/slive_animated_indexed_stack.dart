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
  });

  static const Duration defaultDuration = Duration(milliseconds: 150);

  final int index;
  final List<Widget> children;
  final Duration duration;

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
    _jumpToCurrentPage();

    // forward(from: 0) 可立即中断上一次位移；PageView 已通过 jumpToPage
    // 切到新页，因此动画期间只有新页被绘制。
    if (MediaQuery.disableAnimationsOf(context) ||
        widget.duration == Duration.zero) {
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

    return ClipRect(
      child: AnimatedBuilder(
        animation: animation,
        child: PageView.custom(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          allowImplicitScrolling: false,
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
        ),
        builder: (context, child) {
          final progress = SliveMotion.standard.transform(animation.value);
          final horizontalOffset = _direction * 7 * (1 - progress);
          return Transform.translate(
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
  });

  final TabController controller;
  final List<Widget> children;
  final Duration duration;

  @override
  State<SliveTabIndexedStack> createState() => _SliveTabIndexedStackState();
}

class _SliveTabIndexedStackState extends State<SliveTabIndexedStack> {
  late int _index = _resolveIndex();

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
    }
    _index = _resolveIndex();
  }

  void _handleControllerChange() {
    final nextIndex = _resolveIndex();
    if (!mounted || nextIndex == _index) return;
    setState(() => _index = nextIndex);
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
