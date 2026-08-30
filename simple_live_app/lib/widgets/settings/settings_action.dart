import 'package:flutter/material.dart';
import 'package:simple_live_app/widgets/settings/settings_tile_style.dart';

class SettingsAction extends StatelessWidget {
  const SettingsAction({
    required this.title,
    this.value,
    this.onTap,
    this.subtitle,
    this.leading,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? value;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 10,
      leading: leading,
      title: Text(title, style: SettingsTileStyle.title(context)),
      shape: SettingsTileStyle.shape,
      contentPadding: SettingsTileStyle.contentPadding,
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: SettingsTileStyle.subtitle(context)),
      trailing: SettingsTileStyle.trailing(context, value: value),
      onTap: onTap,
    );
  }
}
