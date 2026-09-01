import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/player/player_system_lease.dart';

void main() {
  test('旧播放器不能消费新播放器持有的系统状态恢复权', () {
    final coordinator = PlayerSystemLeaseCoordinator();
    final oldLease = coordinator.acquire();
    coordinator.markSystemUiChanged(oldLease);
    coordinator.markOrientationChanged(oldLease);

    final newLease = coordinator.acquire();

    expect(coordinator.takeForReset(oldLease), isNull);
    final reset = coordinator.takeForReset(newLease);
    expect(reset, isNotNull);
    expect(reset!.systemUiChanged, isTrue);
    expect(reset.orientationChanged, isTrue);
  });

  test('只有真实改变过的系统状态会进入恢复快照', () {
    final coordinator = PlayerSystemLeaseCoordinator();
    final lease = coordinator.acquire();
    coordinator.markBrightnessChanged(lease);

    final reset = coordinator.takeForReset(lease)!;

    expect(reset.systemUiChanged, isFalse);
    expect(reset.orientationChanged, isFalse);
    expect(reset.brightnessChanged, isTrue);
  });
}
