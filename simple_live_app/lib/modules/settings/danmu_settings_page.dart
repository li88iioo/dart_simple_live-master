import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';

class DanmuSettingsPage extends StatelessWidget {
  const DanmuSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('弹幕设置'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: const _SettingsPageBody(
        children: [DanmuSettingsView()],
      ),
    );
  }
}

class DanmuSettingsView extends GetView<AppSettingsController> {
  final Function()? onTapDanmuShield;
  final DanmakuController? danmakuController;

  const DanmuSettingsView({
    this.onTapDanmuShield,
    this.danmakuController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel(
          title: '弹幕筛选',
          description: '控制关键词、重复内容与虎牙礼物视觉特效',
          first: true,
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsAction(
                title: '关键词屏蔽',
                onTap: onTapDanmuShield ??
                    () => Get.toNamed(RoutePath.kSettingsDanmuShield),
              ),
              const _SettingsDivider(),
              Obx(
                () => SettingsSwitch(
                  title: '弹幕去重',
                  subtitle: '测试性功能',
                  value: controller.danmakuMaskEnable.value,
                  onChanged: controller.setDanmakuMaskEnable,
                ),
              ),
              const _SettingsDivider(),
              Obx(
                () => SettingsSwitch(
                  title: '虎牙礼物弹幕',
                  subtitle: '非全屏显示在聊天区右上角，全屏显示在播放器；不受普通弹幕开关影响',
                  value: controller.huyaGiftDanmakuEnable.value,
                  onChanged: controller.setHuyaGiftDanmakuEnable,
                ),
              ),
            ],
          ),
        ),
        const _SectionLabel(
          title: '显示参数',
          description: '调整弹幕区域、字号、速度与曲面屏安全边距',
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => SettingsSwitch(
                  title: '普通弹幕默认开关',
                  subtitle: '仅控制播放器内的普通滚动弹幕',
                  value: controller.danmuEnable.value,
                  onChanged: controller.setDanmuEnable,
                ),
              ),
              const _SettingsDivider(),
              Obx(
                () => SettingsNumber(
                  title: '显示区域',
                  value: (controller.danmuArea.value * 100).toInt(),
                  min: 10,
                  max: 100,
                  step: 10,
                  unit: '%',
                  onChanged: (value) {
                    controller.setDanmuArea(value / 100.0);
                    updateDanmuOption(
                      danmakuController?.option.copyWith(area: value / 100.0),
                    );
                  },
                ),
              ),
              const _SettingsDivider(),
              Obx(
                () => SettingsNumber(
                  title: '不透明度',
                  value: (controller.danmuOpacity.value * 100).toInt(),
                  min: 10,
                  max: 100,
                  step: 10,
                  unit: '%',
                  onChanged: (value) {
                    controller.setDanmuOpacity(value / 100.0);
                    updateDanmuOption(
                      danmakuController?.option
                          .copyWith(opacity: value / 100.0),
                    );
                  },
                ),
              ),
              const _SettingsDivider(),
              Obx(
                () => SettingsNumber(
                  title: '字体大小',
                  value: controller.danmuSize.toInt(),
                  min: 8,
                  max: 48,
                  onChanged: (value) {
                    controller.setDanmuSize(value.toDouble());
                    updateDanmuOption(
                      danmakuController?.option
                          .copyWith(fontSize: value.toDouble()),
                    );
                  },
                ),
              ),
              const _SettingsDivider(),
              Obx(
                () => SettingsNumber(
                  title: '字体粗细',
                  value: controller.danmuFontWeight.value,
                  min: 0,
                  max: 8,
                  step: 1,
                  displayValue: const [
                    '极细',
                    '很细',
                    '细',
                    '正常',
                    '小粗',
                    '偏粗',
                    '粗',
                    '很粗',
                    '极粗',
                  ][controller.danmuFontWeight.value],
                  onChanged: (value) {
                    controller.setDanmuFontWeight(value);
                    updateDanmuOption(
                      danmakuController?.option.copyWith(fontWeight: value),
                    );
                  },
                ),
              ),
              const _SettingsDivider(),
              Obx(
                () => SettingsNumber(
                  title: '滚动速度',
                  subtitle: '弹幕持续时间（秒），数值越小速度越快',
                  value: controller.danmuSpeed.toInt(),
                  min: 4,
                  max: 20,
                  onChanged: (value) {
                    controller.setDanmuSpeed(value.toDouble());
                    updateDanmuOption(
                      danmakuController?.option
                          .copyWith(duration: value.toDouble()),
                    );
                  },
                ),
              ),
              const _SettingsDivider(),
              Obx(
                () => SettingsNumber(
                  title: '字体描边',
                  value: controller.danmuStrokeWidth.toInt(),
                  min: 0,
                  max: 10,
                  onChanged: (value) {
                    controller.setDanmuStrokeWidth(value.toDouble());
                    updateDanmuOption(
                      danmakuController?.option
                          .copyWith(strokeWidth: value.toDouble()),
                    );
                  },
                ),
              ),
              const _SettingsDivider(),
              Obx(
                () => SettingsNumber(
                  title: '顶部边距',
                  subtitle: '曲面屏显示不全可设置此选项',
                  value: controller.danmuTopMargin.toInt(),
                  min: 0,
                  max: 48,
                  step: 4,
                  onChanged: (value) {
                    controller.setDanmuTopMargin(value.toDouble());
                  },
                ),
              ),
              const _SettingsDivider(),
              Obx(
                () => SettingsNumber(
                  title: '底部边距',
                  subtitle: '曲面屏显示不全可设置此选项',
                  value: controller.danmuBottomMargin.toInt(),
                  min: 0,
                  max: 48,
                  step: 4,
                  onChanged: (value) {
                    controller.setDanmuBottomMargin(value.toDouble());
                  },
                ),
              ),
            ],
          ),
        ),
        const _SectionLabel(
          title: '去重参数',
          description: '控制重复识别窗口、文本归一化与显示频率',
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => SettingsNumber(
                  title: '去重窗口大小（秒）',
                  value: AppSettingsController.instance.danmuWindowMs.value,
                  step: 1,
                  max: 45,
                  min: 10,
                  onChanged: AppSettingsController.instance.setDanmuWindowMs,
                ),
              ),
              const _SettingsDivider(),
              Obx(
                () => SettingsSwitch(
                  value: AppSettingsController
                      .instance.danmuTextNormalization.value,
                  title: '文本归一化',
                  onChanged:
                      AppSettingsController.instance.setDanmuTextNormalization,
                ),
              ),
              const _SettingsDivider(),
              Obx(() {
                final frequencyControl =
                    AppSettingsController.instance.danmuFrequencyControl.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsSwitch(
                      value: frequencyControl,
                      title: '弹幕显示频率',
                      onChanged: AppSettingsController
                          .instance.setDanmuFrequencyControl,
                    ),
                    if (frequencyControl) ...[
                      const _SettingsDivider(),
                      SettingsNumber(
                        title: '显示频率（次）',
                        value: AppSettingsController
                            .instance.danmuMaxFrequency.value,
                        step: 1,
                        max: 10,
                        min: 1,
                        onChanged:
                            AppSettingsController.instance.setDanmuMaxFrequency,
                      ),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  void updateDanmuOption(DanmakuOption? option) {
    if (danmakuController == null || option == null) return;
    danmakuController!.updateOption(option);
  }
}

class _SettingsPageBody extends StatelessWidget {
  const _SettingsPageBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth > 760 ? 760.0 : constraints.maxWidth;
          final horizontalPadding = width < 360 ? 12.0 : 16.0;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  8,
                  horizontalPadding,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                children: children,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    this.description,
    this.first = false,
  });

  final String title;
  final String? description;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, first ? 4 : 26, 12, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (description != null) ...[
            const SizedBox(height: 3),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textTertiary,
                    height: 1.35,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: context.sliveColors.divider.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.10,
      ),
    );
  }
}
