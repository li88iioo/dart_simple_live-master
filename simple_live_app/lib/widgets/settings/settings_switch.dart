import 'package:flutter/material.dart';
import 'package:simple_live_app/widgets/settings/settings_tile_style.dart';

class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    required this.value,
    required this.title,
    this.subtitle,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final String title;
  final String? subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      minVerticalPadding: 10,
      title: Text(title, style: SettingsTileStyle.title(context)),
      shape: SettingsTileStyle.shape,
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      contentPadding: SettingsTileStyle.contentPadding,
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: SettingsTileStyle.subtitle(context)),
      value: value,
      onChanged: onChanged,
    );
  }
}
