class AsyncSingleFlight<T> {
  Future<T>? _active;

  bool get isRunning => _active != null;

  Future<T> run(Future<T> Function() task) {
    final active = _active;
    if (active != null) return active;

    late final Future<T> tracked;
    tracked = Future<T>.sync(task).whenComplete(() {
      if (identical(_active, tracked)) {
        _active = null;
      }
    });
    _active = tracked;
    return tracked;
  }
}
