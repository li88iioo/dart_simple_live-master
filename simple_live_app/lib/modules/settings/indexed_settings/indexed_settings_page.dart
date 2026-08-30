import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/settings/indexed_settings/indexed_settings_controller.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class IndexedSettingsPage extends GetView<IndexedSettingsController> {
  const IndexedSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('主页设置'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _SettingsPageBody(
        children: [
          const _SectionLabel(
            title: '主页排序',
            description: '长按条目拖动排序，重新启动 Slive 后生效',
            first: true,
          ),
          SettingsCard(
            child: Obx(() {
              final keys = controller.homeSort.toList(growable: false);
              return ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: controller.updateHomeSort,
                proxyDecorator: _dragProxyDecorator,
                children: [
                  for (var index = 0; index < keys.length; index++)
                    _ReorderSettingTile(
                      key: ValueKey('home-${keys[index]}'),
                      title: Constant.allHomePages[keys[index]]!.title,
                      showDivider: index < keys.length - 1,
                      leading: _SoftIconPlate(
                        child: Icon(
                          Constant.allHomePages[keys[index]]!.iconData,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
          const _SectionLabel(
            title: '平台排序',
            description: '控制首页平台胶囊的排列顺序，重新启动后生效',
          ),
          SettingsCard(
            child: Obx(() {
              final keys = controller.siteSort
                  .where((key) => Sites.allSites[key]?.name != 'Twitch')
                  .toList(growable: false);
              return ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: controller.updateSiteSort,
                proxyDecorator: _dragProxyDecorator,
                children: [
                  for (var index = 0; index < keys.length; index++)
                    _ReorderSettingTile(
                      key: ValueKey('site-${Sites.allSites[keys[index]]!.id}'),
                      title: Sites.allSites[keys[index]]!.name,
                      showDivider: index < keys.length - 1,
                      leading: _SoftIconPlate(
                        tint: context.sliveColors
                            .platform(Sites.allSites[keys[index]]!.id),
                        child: Image.asset(
                          Sites.allSites[keys[index]]!.logo,
                          width: 24,
                          height: 24,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _dragProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return Material(
      color: Colors.transparent,
      child: SliveGlassSurface(
        variant: SliveGlassVariant.card,
        enableBackdropBlur: false,
        radius: 18,
        child: child,
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

class _ReorderSettingTile extends StatelessWidget {
  const _ReorderSettingTile({
    required this.title,
    required this.leading,
    required this.showDivider,
    super.key,
  });

  final String title;
  final Widget leading;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title，长按拖动排序',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
            leading: leading,
            title: Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            trailing: Icon(
              Icons.drag_handle_rounded,
              color: context.sliveColors.textTertiary,
            ),
          ),
          if (showDivider)
            Divider(
              height: 0.5,
              thickness: 0.5,
              indent: 66,
              endIndent: 16,
              color: context.sliveColors.divider.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.16
                    : 0.10,
              ),
            ),
        ],
      ),
    );
  }
}

class _SoftIconPlate extends StatelessWidget {
  const _SoftIconPlate({required this.child, this.tint});

  final Widget child;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final resolvedTint = tint ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: resolvedTint.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.10,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.sliveColors.glassBorder.withValues(alpha: 0.42),
        ),
      ),
      child: IconTheme(
        data: IconThemeData(color: resolvedTint),
        child: child,
      ),
    );
  }
}
