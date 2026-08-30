import 'package:flutter/material.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_core/simple_live_core.dart';

class SuperChatCard extends StatelessWidget {
  const SuperChatCard(this.message, {super.key});

  final LiveSuperChatMessage message;

  int get _remainSeconds {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final end = message.endTime.millisecondsSinceEpoch ~/ 1000;
    return (end - now).clamp(0, 7200);
  }

  @override
  Widget build(BuildContext context) {
    final topColor = Utils.convertHexColor(message.backgroundColor);
    final bottomColor = Utils.convertHexColor(message.backgroundBottomColor);
    final topTextColor =
        ThemeData.estimateBrightnessForColor(topColor) == Brightness.dark
            ? Colors.white
            : const Color(0xFF2B2623);
    final bottomTextColor =
        ThemeData.estimateBrightnessForColor(bottomColor) == Brightness.dark
            ? Colors.white
            : const Color(0xFF2B2623);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: bottomColor.withValues(alpha: 0.14),
            blurRadius: 18,
            spreadRadius: -7,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                Colors.white.withValues(alpha: 0.16),
                topColor,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  NetImage(
                    message.face,
                    width: 44,
                    height: 44,
                    borderRadius: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          message.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: topTextColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '￥${message.price}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: topTextColor.withValues(alpha: 0.72),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: topTextColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(SliveRadii.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: topTextColor.withValues(alpha: 0.72),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_remainSeconds}s',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: topTextColor.withValues(alpha: 0.78),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                Colors.white.withValues(alpha: 0.08),
                bottomColor,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
              child: SelectableText(
                message.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: bottomTextColor,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
