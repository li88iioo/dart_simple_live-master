import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/home/home_controller.dart';
import 'package:simple_live_app/modules/home/home_list_view.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_icon_button.dart';
import 'package:simple_live_app/widgets/navigation/slive_animated_indexed_stack.dart';
import 'package:simple_live_app/widgets/navigation/slive_platform_tab_bar.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final sites = Sites.supportSites;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SlivePlatformTabBar(
                controller: controller.tabController,
                sites: sites,
                trailing: SliveGlassIconButton(
                  icon: Icons.search_rounded,
                  tooltip: '搜索直播',
                  onPressed: controller.toSearch,
                  enableBackdropBlur: false,
                ),
              ),
            ),
            Expanded(
              child: SliveTabIndexedStack(
                controller: controller.tabController,
                children: sites
                    .map((site) => HomeListView(site.id))
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
