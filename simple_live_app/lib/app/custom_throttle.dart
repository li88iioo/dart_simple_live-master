/// 带 trailing 调用的异步节流器。
class DelayedThrottle {
  DelayedThrottle(this.eachDelayMilli);

  bool isInvoking = false;
  final int eachDelayMilli;
  Future Function()? storeFunc;

  void invoke(Future Function() longCostFunc) {
    if (isInvoking) {
      storeFunc = longCostFunc;
      return;
    }
    storeFunc = null;
    isInvoking = true;
    Future.sync(longCostFunc).then<void>(
      (_) => _scheduleNext(),
      onError: (_, __) => _scheduleNext(),
    );
  }

  void _scheduleNext() {
    Future<void>.delayed(Duration(milliseconds: eachDelayMilli), () {
      isInvoking = false;
      final trailing = storeFunc;
      storeFunc = null;
      if (trailing != null) invoke(trailing);
    });
  }
}
