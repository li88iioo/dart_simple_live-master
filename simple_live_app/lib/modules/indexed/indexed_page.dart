import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';

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
                      color: Get.theme.colorScheme.surface.withOpacity(
                        Get.isDarkMode ? 0.65 : 0.85,
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
                        color: Get.theme.colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 11,
                      ),
                      selectedIconTheme: IconThemeData(
                        color: Get.theme.colorScheme.primary,
                        size: 24,
                      ),
                      unselectedIconTheme: IconThemeData(
                        color: Get.theme.colorScheme.onSurface.withOpacity(0.5),
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
          bottomNavigationBar: Visibility(
            visible: orientation == Orientation.portrait,
            child: Obx(
              () => ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Get.theme.colorScheme.surface.withOpacity(
                        Get.isDarkMode ? 0.65 : 0.85,
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Get.isDarkMode
                              ? Colors.white.withAlpha(20)
                              : Colors.black.withAlpha(15),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        height: 52,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: controller.items.map((item) {
                            final isSelected =
                                controller.index.value == item.index;
                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => controller.setIndex(item.index),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedScale(
                                      scale: isSelected ? 1.1 : 1.0,
                                      duration: const Duration(milliseconds: 150),
                                      child: Icon(
                                        item.iconData,
                                        color: isSelected
                                            ? Get.theme.colorScheme.primary
                                            : Get.theme.colorScheme.onSurface
                                                .withOpacity(0.4),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Get.theme.colorScheme.primary
                                            : Get.theme.colorScheme.onSurface
                                                .withOpacity(0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
