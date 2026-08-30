import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/widgets/settings/settings_tile_style.dart';

class SettingsMenuCheck<T> extends StatelessWidget {
  const SettingsMenuCheck({
    required this.title,
    required this.itemToString,
    this.items = const [],
    this.initialSelection = const [],
    this.itemsProvider,
    this.initialSelectionProvider,
    this.subtitle,
    this.onConfirm,
    this.confirmText,
    this.modalTitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<T> items;
  final List<T> initialSelection;
  final Future<List<T>> Function()? itemsProvider;
  final List<T> Function(List<T> providedItems)? initialSelectionProvider;
  final String Function(T item) itemToString;
  final ValueChanged<List<T>>? onConfirm;
  final String? confirmText;
  final String? modalTitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 10,
      title: Text(title, style: SettingsTileStyle.title(context)),
      shape: SettingsTileStyle.shape,
      contentPadding: SettingsTileStyle.contentPadding,
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: SettingsTileStyle.subtitle(context)),
      trailing: SettingsTileStyle.trailing(
        context,
        value: '${initialSelection.length}/${items.length}',
      ),
      onTap: () => _handleTap(context),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    List<T> menuItems;
    List<T> menuInitialSelection;
    Timer? loadingDelay;
    var loadingVisible = false;

    if (itemsProvider != null) {
      loadingDelay = Timer(const Duration(milliseconds: 300), () {
        loadingVisible = true;
        SmartDialog.showLoading(msg: '');
      });
      try {
        menuItems = await itemsProvider!();
        menuInitialSelection = initialSelectionProvider?.call(menuItems) ??
            menuItems.toList(growable: false);
      } finally {
        loadingDelay.cancel();
        if (loadingVisible) SmartDialog.dismiss();
      }
    } else {
      menuItems = items;
      menuInitialSelection = initialSelection;
    }

    if (!context.mounted || menuItems.isEmpty) return;
    await _openMenu(context, menuItems, menuInitialSelection);
  }

  Future<void> _openMenu(
    BuildContext context,
    List<T> items,
    List<T> initialSelection,
  ) {
    final selectedItems = RxList<T>.from(initialSelection);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final preferredHeight = 82 + (items.length * 58.0);
    final sheetHeight = math.min(
      math.max(preferredHeight, 190.0),
      viewportHeight * 0.72,
    );

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        modalTitle?.tr ?? title.tr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onConfirm?.call(
                          selectedItems.toList(growable: false),
                        );
                      },
                      icon: const Icon(Remix.check_line, size: 18),
                      label: Text(confirmText?.tr ?? '确定'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return Obx(
                      () => CheckboxListTile(
                        value: selectedItems.contains(item),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          itemToString(item),
                          style: SettingsTileStyle.title(sheetContext),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        onChanged: (_) {
                          if (selectedItems.contains(item)) {
                            selectedItems.remove(item);
                          } else {
                            selectedItems.add(item);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
