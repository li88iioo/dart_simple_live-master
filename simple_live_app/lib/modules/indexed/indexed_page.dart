import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/widgets/navigation/liquid_glass_bottom_bar.dart';

import 'indexed_controller.dart';

class IndexedPage extends GetView<IndexedController> {
  const IndexedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return Scaffold(
          extendBody: true,
          body: Row(
            children: [
              Visibility(
                visible: orientation == Orientation.landscape,
                child: Obx(
                  () => Container(
                    decoration: BoxDecoration(
                      color: Get.theme.colorScheme.surface.withValues(
                        alpha: Get.isDarkMode ? 0.65 : 0.85,
                      ),
                      border: Border(
                        right: BorderSide(
                          color: Get.isDarkMode
                              ? Colors.white.withAlpha(20)
                              : Colors.black.withAlpha(15),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: NavigationRail(
                      backgroundColor: Colors.transparent,
                      selectedIndex: controller.index.value,
                      onDestinationSelected: controller.setIndex,
                      labelType: NavigationRailLabelType.all,
                      selectedLabelTextStyle: TextStyle(
                        color: Get.theme.colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelTextStyle: TextStyle(
                        color: Get.theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                      selectedIconTheme: IconThemeData(
                        color: Get.theme.colorScheme.primary,
                        size: 24,
                      ),
                      unselectedIconTheme: IconThemeData(
                        color: Get.theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                        size: 22,
                      ),
                      destinations: controller.items
                          .map(
                            (item) => NavigationRailDestination(
                              icon: Icon(item.iconData),
                              label: Text(item.title),
                              padding: AppStyle.edgeInsetsV12,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Obx(
                  () => Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: orientation == Orientation.landscape
                            ? BorderSide(
                                color: Colors.grey.withAlpha(50),
                                width: 0.5,
                              )
                            : BorderSide.none,
                      ),
                    ),
                    child: IndexedStack(
                      index: controller.index.value,
                      children: controller.pages,
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: orientation == Orientation.portrait
              ? Obx(
                  () => LiquidGlassBottomBar(
                    selectedValue: controller.index.value,
                    onDestinationSelected: controller.setIndex,
                    destinations: controller.items
                        .asMap()
                        .entries
                        .map(
                          (entry) => LiquidGlassBottomBarDestination(
                            icon: entry.value.iconData,
                            label: entry.value.title,
                            value: entry.key,
                          ),
                        )
                        .toList(growable: false),
                  ),
                )
              : null,
        );
      },
    );
  }
}
