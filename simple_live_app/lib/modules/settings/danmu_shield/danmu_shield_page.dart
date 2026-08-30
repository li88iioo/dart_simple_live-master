import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/settings/danmu_shield/danmu_shield_controller.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';

class DanmuShieldPage extends GetView<DanmuShieldController> {
  const DanmuShieldPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('弹幕屏蔽'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _SettingsPageBody(
        children: [
          const _SectionLabel(
            title: '添加屏蔽规则',
            description: '普通文字按关键词匹配；以“/”开头和结尾时按正则表达式匹配',
            first: true,
          ),
          SliveGlassSurface(
            variant: SliveGlassVariant.panel,
            enableBackdropBlur: false,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.textEditingController,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: '请输入关键词或正则表达式',
                      prefixIcon: Icon(Icons.shield_outlined),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                    ),
                    onSubmitted: (_) => controller.add(),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: '添加屏蔽规则',
                  child: SizedBox.square(
                    dimension: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(SliveRadii.control),
                        ),
                      ),
                      onPressed: controller.add,
                      child: const Icon(Icons.add_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Obx(
            () => _SectionLabel(
              title:
                  '已添加 ${controller.settingsController.shieldList.length} 个规则',
              description: '点击任意规则即可移除；例如 /\\d+/ 可屏蔽所有数字',
            ),
          ),
          Obx(() {
            final rules = controller.settingsController.shieldList;
            return SliveGlassSurface(
              variant: SliveGlassVariant.panel,
              enableBackdropBlur: false,
              padding: const EdgeInsets.all(14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (rules.isEmpty) {
                    return const SizedBox(
                      height: 92,
                      child: _EmptyRules(),
                    );
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 92),
                    child: Wrap(
                      runSpacing: 10,
                      spacing: 10,
                      children: rules
                          .map(
                            (rule) => _ShieldRuleChip(
                              rule: rule,
                              maxWidth: constraints.maxWidth,
                              onRemove: () => controller.remove(rule),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                    height: 1.4,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShieldRuleChip extends StatelessWidget {
  const _ShieldRuleChip({
    required this.rule,
    required this.maxWidth,
    required this.onRemove,
  });

  final String rule;
  final double maxWidth;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Semantics(
        button: true,
        label: '移除屏蔽规则 $rule',
        child: SliveGlassSurface(
          variant: SliveGlassVariant.pill,
          enableBackdropBlur: false,
          constraints: const BoxConstraints(minHeight: 44),
          onTap: onRemove,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  rule,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.sliveColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.close_rounded,
                size: 17,
                color: context.sliveColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRules extends StatelessWidget {
  const _EmptyRules();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            color: context.sliveColors.textTertiary,
          ),
          const SizedBox(height: 7),
          Text(
            '暂无屏蔽规则',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.sliveColors.textTertiary,
                ),
          ),
        ],
      ),
    );
  }
}
