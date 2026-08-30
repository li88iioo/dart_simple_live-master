import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/home/home_list_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  test('首页首次请求失败后再次进入会重新加载', () async {
    final controller = _RetryHomeListController();

    await controller.ensureInitialLoad();
    expect(controller.requestCount, 1);
    expect(controller.pageError.value, isTrue);
    expect(controller.list, isEmpty);

    await controller.ensureInitialLoad();
    expect(controller.requestCount, 2);
    expect(controller.pageError.value, isFalse);
    expect(controller.list.single.roomId, 'retry-room');
  });
}

class _RetryHomeListController extends HomeListController {
  _RetryHomeListController() : super(Sites.allSites[Constant.kHuya]!);

  int requestCount = 0;

  @override
  Future<List<LiveRoomItem>> getData(int page, int pageSize) async {
    requestCount++;
    if (requestCount == 1) {
      throw Exception('temporary failure');
    }
    return [
      LiveRoomItem(
        roomId: 'retry-room',
        title: 'retry',
        cover: '',
        userName: 'tester',
        online: 1,
      ),
    ];
  }
}
