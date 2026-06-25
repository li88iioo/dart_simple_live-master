import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';
import 'package:simple_live_app/modules/search/search_list_view.dart';

class SearchPage extends GetView<AppSearchController> {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Container(
          height: 38,
          decoration: BoxDecoration(
            color: Get.isDarkMode
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(19),
          ),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: Get.back,
                icon: const Icon(Icons.arrow_back, size: 20),
              ),
              Obx(
                () => DropdownButton<int>(
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, size: 16),
                  style: TextStyle(
                    color: Get.theme.textTheme.bodyMedium?.color,
                    fontSize: 13,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text("房间"),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text("主播"),
                    ),
                  ],
                  value: controller.searchMode.value,
                  onChanged: (e) {
                    controller.searchMode.value = e ?? 0;
                    controller.doSearch();
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: controller.searchController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: "搜点什么吧",
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (e) {
                    controller.doSearch();
                  },
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: controller.doSearch,
                icon: const Icon(Icons.search, size: 20),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        bottom: TabBar(
          controller: controller.tabController,
          padding: EdgeInsets.zero,
          tabAlignment: TabAlignment.center,
          tabs: Sites.supportSites
              .map(
                (e) => Tab(
                  //text: e.name,
                  child: Row(
                    children: [
                      Image.asset(
                        e.logo,
                        width: 24,
                      ),
                      AppStyle.hGap8,
                      Text(e.name),
                    ],
                  ),
                ),
              )
              .toList(),
          labelPadding: AppStyle.edgeInsetsH20,
          isScrollable: true,
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: controller.tabController,
        children: Sites.supportSites
            .map((e) => SearchListView(
                      e.id,
                    )
                // (e) => e.id == Constant.kDouyin
                //     ? const DouyinSearchView()
                //     : SearchListView(
                //         e.id,
                //       ),
                )
            .toList(),
      ),
    );
  }
}
