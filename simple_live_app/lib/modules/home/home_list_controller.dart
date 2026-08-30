import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_core/simple_live_core.dart';

class HomeListController extends BasePageController<LiveRoomItem> {
  final Site site;
  HomeListController(this.site);
  bool _initialLoadRequested = false;

  Future<void> ensureInitialLoad() async {
    if (_initialLoadRequested || list.isNotEmpty || loadding) return;
    _initialLoadRequested = true;
    await refreshData();
    if (list.isEmpty && pageError.value) {
      _initialLoadRequested = false;
    }
  }

  @override
  Future<List<LiveRoomItem>> getData(int page, int pageSize) async {
    var result = await site.liveSite.getRecommendRooms(page: page);

    return result.items;
  }
}
