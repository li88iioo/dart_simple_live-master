import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_core/simple_live_core.dart';

class LiveRoomCard extends StatelessWidget {
  const LiveRoomCard(
    this.site,
    this.item, {
    super.key,
    this.onLongPress,
    this.onFollowRemove,
  });

  final Site site;
  final LiveRoomItem item;
  final Function()? onLongPress;
  final Function()? onFollowRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    return SliveGlassSurface(
      variant: SliveGlassVariant.card,
      radius: SliveRadii.card,
      onTap: () {
        AppNavigator.toLiveRoomDetail(site: site, roomId: item.roomId);
      },
      onLongPress: onLongPress == null ? null : () => onLongPress?.call(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(SliveRadii.cover),
                    child: NetImage(
                      item.cover,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    right: 7,
                    bottom: 7,
                    child: _HeatBadge(
                      icon: site.iconData,
                      text: Utils.onlineToString(item.online),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 9, 5, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.08,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            height: 1.25,
                            fontSize: 11.5,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onFollowRemove != null) ...[
                    const SizedBox(width: 4),
                    SizedBox.square(
                      dimension: 36,
                      child: IconButton(
                        tooltip: '取消关注',
                        onPressed: () => onFollowRemove?.call(),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Remix.dislike_line,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatBadge extends StatelessWidget {
  const _HeatBadge({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final blurEnabled = context.sliveMaterials.mode == SliveGlassMode.clear;
    Widget badge = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(SliveRadii.pill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.7,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 11),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    if (blurEnabled) {
      badge = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: badge,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(SliveRadii.pill),
      child: badge,
    );
  }
}
