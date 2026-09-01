import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/custom_throttle.dart';

void main() {
  test('异步任务失败后节流器仍可执行尾调用', () async {
    final throttle = DelayedThrottle(1);
    final completed = Completer<void>();
    var runs = 0;

    throttle.invoke(() async {
      runs++;
      throw StateError('expected');
    });
    throttle.invoke(() async {
      runs++;
      completed.complete();
    });

    await completed.future.timeout(const Duration(seconds: 1));
    expect(runs, 2);
  });
}
