import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/utils/operation_generation.dart';

void main() {
  test('新一代令牌会立即使旧异步流程失效', () {
    final generation = OperationGeneration();
    final first = generation.next();

    expect(generation.isCurrent(first), isTrue);

    final second = generation.next();

    expect(generation.isCurrent(first), isFalse);
    expect(generation.isCurrent(second), isTrue);
  });
}
