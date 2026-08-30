import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/settings/settings_tile_style.dart';

class SettingsNumber extends StatelessWidget {
  const SettingsNumber({
    required this.title,
    required this.value,
    required this.max,
    this.subtitle,
    this.onChanged,
    this.step = 1,
    this.min = 0,
    this.unit = '',
    this.displayValue,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String unit;
  final int value;
  final int step;
  final int min;
  final int max;
  final String? displayValue;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    return ListTile(
      minVerticalPadding: 10,
      title: Text(title, style: SettingsTileStyle.title(context)),
      shape: SettingsTileStyle.shape,
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: SettingsTileStyle.subtitle(context)),
      contentPadding: SettingsTileStyle.contentPadding,
      trailing: Container(
        height: 44,
        constraints: const BoxConstraints(minWidth: 126, maxWidth: 158),
        decoration: BoxDecoration(
          color: colors.glassStrong.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(SliveRadii.pill),
          border: Border.all(
            color: colors.glassBorder.withValues(alpha: 0.46),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(
              icon: Icons.remove_rounded,
              tooltip: '减少$title',
              enabled: onChanged != null && value > min,
              onPressed: () => onChanged?.call((value - step).clamp(min, max)),
            ),
            Expanded(
              child: Text(
                displayValue ?? '$value$unit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            _StepButton(
              icon: Icons.add_rounded,
              tooltip: '增加$title',
              enabled: onChanged != null && value < max,
              onPressed: () => onChanged?.call((value + step).clamp(min, max)),
            ),
          ],
        ),
      ),
      onTap: onChanged == null ? null : () => openSlider(context),
    );
  }

  Future<void> openSlider(BuildContext context) {
    var nextValue = value;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$nextValue$unit',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: context.sliveColors.textSecondary,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: nextValue.toDouble(),
                    min: min.toDouble(),
                    max: max.toDouble(),
                    onChanged: (rawValue) {
                      final stepped =
                          min + (((rawValue - min) / step).round() * step);
                      setModalState(() {
                        nextValue = stepped.clamp(min, max);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        onChanged?.call(nextValue);
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}
