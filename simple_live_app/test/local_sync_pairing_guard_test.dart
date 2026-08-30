import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/local_sync_pairing_guard.dart';

void main() {
  late DateTime now;
  late LocalSyncPairingGuard guard;

  setUp(() {
    now = DateTime.utc(2026, 8, 30, 12);
    guard = LocalSyncPairingGuard(
      maxFailures: 3,
      failureWindow: const Duration(minutes: 1),
      blockDuration: const Duration(seconds: 30),
      now: () => now,
    );
  });

  test('达到失败阈值后临时阻止同一来源继续配对', () {
    guard.registerFailure('192.168.1.8');
    guard.registerFailure('192.168.1.8');
    expect(guard.blockedFor('192.168.1.8'), isNull);

    guard.registerFailure('192.168.1.8');

    expect(
      guard.blockedFor('192.168.1.8'),
      const Duration(seconds: 30),
    );
    expect(guard.blockedFor('192.168.1.9'), isNull);
  });

  test('阻止时间结束后允许重新尝试', () {
    for (var index = 0; index < 3; index++) {
      guard.registerFailure('192.168.1.8');
    }

    now = now.add(const Duration(seconds: 31));

    expect(guard.blockedFor('192.168.1.8'), isNull);
    guard.registerFailure('192.168.1.8');
    expect(guard.blockedFor('192.168.1.8'), isNull);
  });

  test('成功配对会清除之前的失败计数', () {
    guard.registerFailure('192.168.1.8');
    guard.registerFailure('192.168.1.8');
    guard.registerSuccess('192.168.1.8');

    guard.registerFailure('192.168.1.8');
    expect(guard.blockedFor('192.168.1.8'), isNull);
  });

  test('来源状态超过容量后淘汰最久未访问项', () {
    guard = LocalSyncPairingGuard(
      maxFailures: 3,
      maxTrackedClients: 2,
      now: () => now,
    );

    guard.registerFailure('192.168.1.1');
    now = now.add(const Duration(seconds: 1));
    guard.registerFailure('192.168.1.2');
    now = now.add(const Duration(seconds: 1));
    guard.registerFailure('192.168.1.3');

    expect(guard.trackedClientCount, 2);
  });

  test('失败窗口过期后重新计数', () {
    guard.registerFailure('192.168.1.8');
    guard.registerFailure('192.168.1.8');
    now = now.add(const Duration(minutes: 2));

    guard.registerFailure('192.168.1.8');

    expect(guard.blockedFor('192.168.1.8'), isNull);
  });
}
