import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/widgets/net_image.dart';

class FollowUserItem extends StatelessWidget {
  const FollowUserItem({
    required this.item,
    this.onRemove,
    this.onTap,
    this.onLongPress,
    this.playing = false,
    super.key,
  });

  final FollowUser item;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final site = Sites.allSites[item.siteId]!;
    final colors = context.sliveColors;
    final platformColor = colors.platform(site.id);

    return ListTile(
      minVerticalPadding: 9,
      contentPadding: const EdgeInsets.fromLTRB(14, 7, 6, 7),
      leading: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: platformColor.withValues(alpha: 0.12),
          border: Border.all(color: platformColor.withValues(alpha: 0.22)),
        ),
        child: NetImage(
          item.face,
          width: 46,
          height: 46,
          borderRadius: 23,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.remark?.isNotEmpty == true ? item.remark! : item.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Obx(
            () => _FollowStatusPill(
              status: item.liveStatus.value,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Image.asset(
              site.logo,
              width: 17,
              height: 17,
              filterQuality: FilterQuality.medium,
            ),
            Text(
              site.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (item.watchDuration?.isNotEmpty == true)
              Text(
                item.watchDuration!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                    ),
              ),
            if (item.tag.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  item.tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                ),
              ),
          ],
        ),
      ),
      trailing: playing
          ? Container(
              width: 42,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(SliveRadii.pill),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : onRemove == null
              ? null
              : IconButton(
                  tooltip: '取消关注',
                  onPressed: onRemove,
                  icon: Icon(
                    Remix.dislike_line,
                    color: colors.textSecondary,
                    size: 19,
                  ),
                ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _FollowStatusPill extends StatelessWidget {
  const _FollowStatusPill({required this.status});

  final int status;

  @override
  Widget build(BuildContext context) {
    if (status == 0) return const SizedBox.shrink();
    final colors = context.sliveColors;
    final isLive = status == 2;
    final color = isLive ? colors.success : colors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SliveRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isLive ? '直播中' : '未开播',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
