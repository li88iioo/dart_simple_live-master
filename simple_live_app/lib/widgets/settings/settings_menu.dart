import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/widgets/settings/settings_tile_style.dart';

class SettingsMenu<T> extends StatelessWidget {
  const SettingsMenu({
    required this.title,
    required this.value,
    required this.valueMap,
    this.subtitle,
    this.onChanged,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Map<T, String> valueMap;
  final T value;
  final Widget? trailing;
  final ValueChanged<T>? onChanged;

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
      trailing: trailing ??
          SettingsTileStyle.trailing(
            context,
            value: valueMap[value]?.tr ?? '未设置',
          ),
      onTap: () => openMenu(context),
    );
  }

  Future<void> openMenu(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: RadioGroup<T>(
            groupValue: value,
            onChanged: (nextValue) {
              if (nextValue == null) return;
              Navigator.of(sheetContext).pop();
              onChanged?.call(nextValue);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: valueMap.entries
                  .map(
                    (entry) => RadioListTile<T>(
                      value: entry.key,
                      title: Text(
                        entry.value.tr,
                        style: SettingsTileStyle.title(sheetContext),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}
