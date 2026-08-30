import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/glass/slive_ambient_background.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/navigation/liquid_glass_bottom_bar.dart';

import 'indexed_controller.dart';

class IndexedPage extends GetView<IndexedController> {
  const IndexedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return SliveAmbientBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: Row(
              children: [
                Visibility(
                  visible: orientation == Orientation.landscape,
                  child: Obx(
                    () => SliveGlassSurface(
                      variant: SliveGlassVariant.panel,
                      radius: 0,
                      enableBackdropBlur: true,
                      child: NavigationRail(
                        backgroundColor: Colors.transparent,
                        selectedIndex: controller.index.value,
                        onDestinationSelected: controller.setIndex,
                        labelType: NavigationRailLabelType.all,
                        selectedLabelTextStyle: TextStyle(
                          color: Get.theme.colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelTextStyle: TextStyle(
                          color: context.sliveColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedIconTheme: IconThemeData(
                          color: Get.theme.colorScheme.primary,
                          size: 24,
                        ),
                        unselectedIconTheme: IconThemeData(
                          color: context.sliveColors.textSecondary,
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
                    () => IndexedStack(
                      index: controller.index.value,
                      children: controller.pages,
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
          ),
        );
      },
    );
  }
}
