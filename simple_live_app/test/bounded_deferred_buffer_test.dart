import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/chat/bounded_deferred_buffer.dart';

void main() {
  test('自动滚动时始终保留最新的可见消息', () {
    final buffer = BoundedDeferredBuffer<int>(
      maxVisible: 3,
      maxDeferred: 2,
    );
    final visible = <int>[1, 2];

    buffer.append(visible, [3, 4, 5], preserveVisible: false);

    expect(visible, [3, 4, 5]);
    expect(buffer.deferredCount, 0);
  });

  test('用户阅读旧消息时不移动可见列表并有界保留最新消息', () {
    final buffer = BoundedDeferredBuffer<int>(
      maxVisible: 3,
      maxDeferred: 2,
    );
    final visible = <int>[1, 2, 3];

    buffer.append(visible, [4, 5, 6], preserveVisible: true);

    expect(visible, [1, 2, 3]);
    expect(buffer.deferredCount, 2);

    buffer.resume(visible);
    expect(visible, [3, 5, 6]);
    expect(buffer.deferredCount, 0);
  });

  test('可见列表未满时先补足，其余进入有界延迟队列', () {
    final buffer = BoundedDeferredBuffer<int>(
      maxVisible: 4,
      maxDeferred: 2,
    );
    final visible = <int>[1, 2];

    final added = buffer.append(
      visible,
      [3, 4, 5],
      preserveVisible: true,
    );

    expect(added, 2);
    expect(visible, [1, 2, 3, 4]);
    expect(buffer.deferredCount, 1);
  });
}
