import 'dart:collection';

class BoundedDeferredBuffer<T> {
  BoundedDeferredBuffer({
    required this.maxVisible,
    required this.maxDeferred,
  })  : assert(maxVisible > 0),
        assert(maxDeferred >= 0);

  final int maxVisible;
  final int maxDeferred;
  final ListQueue<T> _deferred = ListQueue<T>();

  int get deferredCount => _deferred.length;

  int append(
    List<T> target,
    Iterable<T> items, {
    required bool preserveVisible,
  }) {
    _trimVisible(target);
    final incoming = List<T>.of(items);
    if (incoming.isEmpty) return 0;

    if (!preserveVisible) {
      target.addAll(incoming);
      _trimVisible(target);
      return incoming.length;
    }

    final available = maxVisible - target.length;
    final visibleCount = available > 0
        ? (incoming.length < available ? incoming.length : available)
        : 0;
    if (visibleCount > 0) {
      target.addAll(incoming.take(visibleCount));
    }
    for (final item in incoming.skip(visibleCount)) {
      _enqueueDeferred(item);
    }
    return visibleCount;
  }

  int resume(List<T> target) {
    if (_deferred.isEmpty) return 0;
    final count = _deferred.length;
    target.addAll(_deferred);
    _deferred.clear();
    _trimVisible(target);
    return count;
  }

  void clear() {
    _deferred.clear();
  }

  void _enqueueDeferred(T item) {
    if (maxDeferred == 0) return;
    if (_deferred.length >= maxDeferred) {
      _deferred.removeFirst();
    }
    _deferred.addLast(item);
  }

  void _trimVisible(List<T> target) {
    final overflow = target.length - maxVisible;
    if (overflow > 0) {
      target.removeRange(0, overflow);
    }
  }
}
