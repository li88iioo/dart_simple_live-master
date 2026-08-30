import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/widgets/glass/slive_ambient_background.dart';
import 'package:simple_live_app/widgets/navigation/liquid_glass_bottom_bar.dart';
import 'package:simple_live_app/widgets/navigation/slive_animated_indexed_stack.dart';

import 'indexed_controller.dart';

class IndexedPage extends GetView<IndexedController> {
  const IndexedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final destinations = controller.items
            .asMap()
            .entries
            .map(
              (entry) => LiquidGlassBottomBarDestination(
                icon: entry.value.iconData,
                label: entry.value.title,
                value: entry.key,
              ),
            )
            .toList(growable: false);
        final isLandscape = orientation == Orientation.landscape;

        return SliveAmbientBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: Row(
              children: [
                if (isLandscape)
                  Obx(
                    () => LiquidGlassSideRail(
                      selectedValue: controller.index.value,
                      onDestinationSelected: controller.setIndex,
                      destinations: destinations,
                    ),
                  ),
                Expanded(
                  child: Obx(
                    () => SliveAnimatedIndexedStack(
                      index: controller.index.value,
                      children: controller.pages,
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: isLandscape
                ? null
                : Obx(
                    () => LiquidGlassBottomBar(
                      selectedValue: controller.index.value,
                      onDestinationSelected: controller.setIndex,
                      destinations: destinations,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
