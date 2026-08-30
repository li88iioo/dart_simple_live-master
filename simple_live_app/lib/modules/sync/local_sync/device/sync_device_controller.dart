import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/sync_client_info_model.dart';
import 'package:simple_live_app/requests/sync_client_request.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/sync_service.dart';

class SyncDeviceController extends BaseController {
  final SyncClinet client;
  final SyncClientInfoModel info;
  SyncDeviceController({required this.client, required this.info});
  final SyncClientRequest request = SyncClientRequest();
  bool _syncing = false;

  Future<bool> showOverlayDialog() async {
    var overlay = await Utils.showAlertDialog(
      "是否覆盖远端数据？",
      title: "数据覆盖",
      confirm: "覆盖",
      cancel: "不覆盖",
    );
    return overlay;
  }

  Future<void> syncFollowAndTag() async {
    if (!_beginSync()) return;

    try {
      var overlay = await showOverlayDialog();
      SmartDialog.showLoading(msg: "同步中...");
      final users = DBService.instance.getAllFollowList();
      final tags = DBService.instance.getFollowTagList();
      final followData = users.map((item) => item.toJson()).toList();
      final tagData = tags.map((item) => item.toJson()).toList();
      await request.syncFollowBundle(
        client,
        follows: followData,
        tags: tagData,
        overlay: overlay,
      );
      SmartDialog.showToast("已同步关注列表和标签");
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
      _syncing = false;
    }
  }

  Future<void> syncHistory() async {
    if (!_beginSync()) return;

    try {
      var overlay = await showOverlayDialog();
      SmartDialog.showLoading(msg: "同步中...");
      final histories = DBService.instance.getHistories();
      final data = histories.map((item) => item.toJson()).toList();
      await request.syncHistory(client, data, overlay: overlay);
      SmartDialog.showToast("已同步历史记录");
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
      _syncing = false;
    }
  }

  Future<void> syncBlockedWord() async {
    if (!_beginSync()) return;

    try {
      var overlay = await showOverlayDialog();
      SmartDialog.showLoading(msg: "同步中...");
      final shieldList = AppSettingsController.instance.shieldList;
      await request.syncBlockedWord(
        client,
        shieldList.toList(),
        overlay: overlay,
      );
      SmartDialog.showToast("已同步屏蔽词");
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
      _syncing = false;
    }
  }

  bool _beginSync() {
    if (_syncing) {
      SmartDialog.showToast('已有同步任务正在进行');
      return false;
    }
    _syncing = true;
    return true;
  }
}
