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
    this.coverMaxDecodeDensity = 3,
  });

  final Site site;
  final LiveRoomItem item;
  final Function()? onLongPress;
  final Function()? onFollowRemove;
  final double coverMaxDecodeDensity;

  static const double _outerHorizontalPadding = 5;
  static const double _outerTopPadding = 5;
  static const double _detailsTopPadding = 9;
  static const double _detailsBottomPadding = 10;
  static const double _titleFontSize = 13.5;
  static const double _titleLineHeight = 1.2;
  static const double _subtitleFontSize = 11.5;
  static const double _subtitleLineHeight = 1.25;
  static const double _textGap = 4;
  static const double _roundingSafety = 1;

  /// 首页固定高度网格使用的卡片高度。
  ///
  /// 文本段落会按设备像素比向上取整；若只使用理论字号乘行高，部分宽度与
  /// DPI 组合会出现 Debug 模式底部溢出 1px。这里逐行向上取整并保留 1 个
  /// 逻辑像素安全区，使占位尺寸与真实卡片结构保持一致。
  static double resolveMainAxisExtent({
    required double cardWidth,
    required TextScaler textScaler,
  }) {
    final coverWidth = (cardWidth - _outerHorizontalPadding * 2)
        .clamp(0.0, double.infinity)
        .toDouble();
    final coverHeight = coverWidth * 2 / 3;
    final titleHeight =
        (textScaler.scale(_titleFontSize) * _titleLineHeight).ceilToDouble();
    final subtitleHeight =
        (textScaler.scale(_subtitleFontSize) * _subtitleLineHeight)
            .ceilToDouble();
    final detailsHeight = _outerTopPadding +
        _detailsTopPadding +
        titleHeight +
        _textGap +
        subtitleHeight +
        _detailsBottomPadding +
        _roundingSafety;
    return coverHeight + detailsHeight;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    return SliveGlassSurface(
      variant: SliveGlassVariant.card,
      radius: SliveRadii.card,
      enableBackdropBlur: false,
      showShadow: false,
      clipBehavior: Clip.hardEdge,
      onTap: () {
        AppNavigator.toLiveRoomDetail(site: site, roomId: item.roomId);
      },
      onLongPress: onLongPress == null ? null : () => onLongPress?.call(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _outerHorizontalPadding,
          _outerTopPadding,
          _outerHorizontalPadding,
          0,
        ),
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
                    clipBehavior: Clip.hardEdge,
                    child: NetImage(
                      item.cover,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      maxDecodeDensity: coverMaxDecodeDensity,
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
              padding: const EdgeInsets.fromLTRB(
                7,
                _detailsTopPadding,
                5,
                _detailsBottomPadding,
              ),
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
                            fontSize: _titleFontSize,
                            height: _titleLineHeight,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.08,
                          ),
                        ),
                        const SizedBox(height: _textGap),
                        Text(
                          item.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            height: _subtitleLineHeight,
                            fontSize: _subtitleFontSize,
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
    // 列表滚动时每张卡片做 BackdropFilter 会反复采样封面纹理。
    // 使用高遮罩渐变模拟毛玻璃，保留层次同时避免 GPU 合成热点。
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withValues(alpha: 0.34),
            Colors.black.withValues(alpha: 0.48),
          ],
        ),
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
  }
}
