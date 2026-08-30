import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';

class DanmuShieldController extends BaseController {
  final TextEditingController textEditingController = TextEditingController();
  final AppSettingsController settingsController =
      Get.find<AppSettingsController>();
  Future<void> add() async {
    if (textEditingController.text.isEmpty) {
      SmartDialog.showToast("请输入关键词");
      return;
    }

    await settingsController.addShieldList(textEditingController.text.trim());
    textEditingController.text = "";
  }

  Future<void> remove(String item) async {
    await settingsController.removeShieldList(item);
  }

  @override
  void onClose() {
    textEditingController.dispose();
    super.onClose();
  }
}
