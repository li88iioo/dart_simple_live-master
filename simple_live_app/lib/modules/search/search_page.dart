import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';
import 'package:simple_live_app/modules/search/search_list_view.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_icon_button.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/navigation/slive_platform_tab_bar.dart';

class SearchPage extends GetView<AppSearchController> {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sites = Sites.supportSites;

    return SlivePageScaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 68,
        titleSpacing: SliveLayout.pageHorizontal,
        title: Row(
          children: [
            SliveGlassIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: '返回',
              onPressed: () => Get.back(),
            ),
            const SizedBox(width: 8),
            Expanded(child: _SearchField(controller: controller)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SliveLayout.pageHorizontal,
              2,
              SliveLayout.pageHorizontal,
              10,
            ),
            child: SlivePlatformTabBar(
              controller: controller.tabController,
              sites: sites,
            ),
          ),
        ),
      ),
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: controller.tabController,
        children: sites
            .map((site) => SearchListView(site.id))
            .toList(growable: false),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final AppSearchController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;

    return SliveGlassSurface(
      variant: SliveGlassVariant.pill,
      radius: SliveRadii.pill,
      enableBackdropBlur: true,
      constraints: const BoxConstraints(minHeight: 44, maxHeight: 48),
      child: Row(
        children: [
          PopupMenuButton<int>(
            tooltip: '选择搜索类型',
            position: PopupMenuPosition.under,
            onSelected: (value) {
              controller.searchMode.value = value;
              controller.doSearch();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 0, child: Text('搜索房间')),
              PopupMenuItem(value: 1, child: Text('搜索主播')),
            ],
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 58),
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 5),
                child: Obx(
                  () => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        controller.searchMode.value == 0 ? '房间' : '主播',
                        maxLines: 1,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 17,
                        color: colors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: colors.divider.withValues(alpha: 0.18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller.searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              maxLines: 1,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: '搜点什么吧',
                hintStyle: TextStyle(
                  color: colors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onSubmitted: (_) => controller.doSearch(),
            ),
          ),
          SizedBox.square(
            dimension: 42,
            child: IconButton(
              tooltip: '搜索',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: controller.doSearch,
              icon: Icon(
                Icons.search_rounded,
                color: colors.textPrimary,
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}
