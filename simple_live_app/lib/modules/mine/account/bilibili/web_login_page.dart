import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/mine/account/bilibili/web_login_controller.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_icon_button.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';

class BiliBiliWebLoginPage extends GetView<BiliBiliWebLoginController> {
  const BiliBiliWebLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;

    return SlivePageScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 68,
        leadingWidth: 68,
        leading: Align(
          child: SliveGlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: '返回',
            onPressed: () => Get.back(),
          ),
        ),
        titleSpacing: 0,
        title: Text(
          '哔哩哔哩账号登录',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.28,
              ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: SliveGlassSurface(
              variant: SliveGlassVariant.pill,
              radius: SliveRadii.pill,
              enableBackdropBlur: true,
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: colors.bilibili.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/images/bilibili_2.png',
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '网页登录',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        Text(
                          '登录成功后将自动保存状态并返回',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.textTertiary,
                                    height: 1.25,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SliveGlassIconButton(
                    icon: Icons.qr_code_rounded,
                    tooltip: '切换到二维码登录',
                    onPressed: controller.toQRLogin,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: InAppWebView(
              onWebViewCreated: controller.onWebViewCreated,
              onLoadStop: controller.onLoadStop,
              initialSettings: InAppWebViewSettings(
                userAgent:
                    'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/118.0.0.0',
                useShouldOverrideUrlLoading: true,
              ),
              shouldOverrideUrlLoading:
                  (webController, navigationAction) async {
                final uri = navigationAction.request.url;
                if (uri == null) {
                  return NavigationActionPolicy.ALLOW;
                }
                if (uri.host == 'm.bilibili.com' ||
                    uri.host == 'www.bilibili.com') {
                  await controller.logined();
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
            ),
          ),
        ],
      ),
    );
  }
}
