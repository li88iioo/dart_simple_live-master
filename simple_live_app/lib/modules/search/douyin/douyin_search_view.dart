import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/search/douyin/douyin_search_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';

class DouyinSearchView extends StatelessWidget {
  const DouyinSearchView({super.key});

  DouyinSearchController get controller => Get.find<DouyinSearchController>();

  @override
  Widget build(BuildContext context) {
    final supportsWebView = Platform.isAndroid || Platform.isIOS;

    return KeepAliveWrapper(
      child: Stack(
        children: [
          Positioned.fill(child: _BrowserFallback(controller: controller)),
          if (supportsWebView)
            Positioned.fill(
              child: InAppWebView(
                onWebViewCreated: controller.onWebViewCreated,
                onLoadStop: controller.onLoadStop,
                onLoadStart: controller.onLoadStart,
                initialSettings: InAppWebViewSettings(
                  useOnLoadResource: true,
                  userAgent:
                      'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/118.0.0.0',
                  useShouldOverrideUrlLoading: true,
                ),
                onCreateWindow: controller.onCreateWindow,
                shouldOverrideUrlLoading:
                    (webController, navigationAction) async {
                  final uri = navigationAction.request.url;
                  if (uri == null) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  if (uri.host == 'live.douyin.com') {
                    final regExp = RegExp(r'live\.douyin\.com/([\d|\w]+)');
                    final id =
                        regExp.firstMatch(uri.toString())?.group(1) ?? '';
                    AppNavigator.toLiveRoomDetail(
                      site: controller.site,
                      roomId: id,
                    );
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
              ),
            ),
          Obx(
            () => controller.pageLoadding.value
                ? Positioned.fill(
                    child: ColoredBox(
                      color: context.sliveColors.backgroundBase.withValues(
                        alpha: 0.34,
                      ),
                      child: Center(
                        child: SliveGlassSurface(
                          variant: SliveGlassVariant.overlay,
                          enableBackdropBlur: true,
                          radius: SliveRadii.pill,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '正在载入抖音搜索',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: context.sliveColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _BrowserFallback extends StatelessWidget {
  const _BrowserFallback({required this.controller});

  final DouyinSearchController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SliveGlassSurface(
            variant: SliveGlassVariant.panel,
            enableBackdropBlur: true,
            radius: SliveRadii.panel,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: colors.douyin.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.douyin.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Icon(
                    Icons.open_in_browser_rounded,
                    color: colors.douyin,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '暂不支持抖音站内搜索',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请在浏览器中搜索直播间，复制直播链接后回到 Slive 使用链接解析。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 18),
                SliveGlassSurface(
                  variant: SliveGlassVariant.pill,
                  enableBackdropBlur: false,
                  radius: SliveRadii.pill,
                  onTap: controller.openBrowser,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_new_rounded,
                        color: colors.textPrimary,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '打开浏览器',
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
