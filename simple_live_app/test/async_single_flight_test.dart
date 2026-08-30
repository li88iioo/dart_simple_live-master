import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/utils/async_single_flight.dart';

void main() {
  test('并发调用共享同一个进行中的异步任务', () async {
    final flight = AsyncSingleFlight<int>();
    final release = Completer<int>();
    var runs = 0;

    final first = flight.run(() {
      runs++;
      return release.future;
    });
    final second = flight.run(() {
      runs++;
      return Future.value(2);
    });

    expect(identical(first, second), isTrue);
    expect(flight.isRunning, isTrue);
    expect(runs, 1);

    release.complete(7);
    expect(await first, 7);
    expect(flight.isRunning, isFalse);
  });

  test('任务完成后允许下一轮执行', () async {
    final flight = AsyncSingleFlight<int>();
    var runs = 0;

    expect(await flight.run(() async => ++runs), 1);
    expect(await flight.run(() async => ++runs), 2);
    expect(runs, 2);
  });
}
