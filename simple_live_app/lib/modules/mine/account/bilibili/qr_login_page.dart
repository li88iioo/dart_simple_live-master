import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/mine/account/bilibili/qr_login_controller.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_icon_button.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';

class BiliBiliQRLoginPage extends GetView<BiliBiliQRLoginController> {
  const BiliBiliQRLoginPage({super.key});

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight =
              constraints.maxHeight > 40 ? constraints.maxHeight - 40 : 0.0;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: availableHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SliveGlassSurface(
                    variant: SliveGlassVariant.overlay,
                    radius: SliveRadii.panel,
                    enableBackdropBlur: true,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: colors.bilibili.withValues(alpha: 0.11),
                                borderRadius: BorderRadius.circular(17),
                                border: Border.all(
                                  color:
                                      colors.bilibili.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/bilibili_2.png',
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '扫码登录',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: colors.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '使用哔哩哔哩客户端完成授权',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: colors.textTertiary,
                                          height: 1.3,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Obx(
                          () => _QRStatusContent(
                            status: controller.qrStatus.value,
                            data: controller.qrcodeUrl.value,
                            onReload: controller.loadQRCode,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '请使用哔哩哔哩手机客户端扫描二维码登录',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.textSecondary,
                                    height: 1.45,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QRStatusContent extends StatelessWidget {
  const _QRStatusContent({
    required this.status,
    required this.data,
    required this.onReload,
  });

  final QRStatus status;
  final String data;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;

    return Column(
      children: [
        SizedBox.square(
          dimension: 228,
          child: Center(child: _buildCodeArea(context)),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _statusColor(colors),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _statusColor(colors).withValues(alpha: 0.22),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _statusLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeArea(BuildContext context) {
    final colors = context.sliveColors;

    switch (status) {
      case QRStatus.loading:
        return _StatusPanel(
          icon: const SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          label: '正在生成安全二维码',
        );
      case QRStatus.failed:
        return _StatusPanel(
          icon: Icon(
            Icons.cloud_off_outlined,
            color: colors.danger,
            size: 34,
          ),
          label: '二维码加载失败',
          actionLabel: '重试',
          onPressed: onReload,
        );
      case QRStatus.expired:
        return _StatusPanel(
          icon: Icon(
            Icons.history_toggle_off_rounded,
            color: colors.ambientOrange,
            size: 34,
          ),
          label: '二维码已失效',
          actionLabel: '刷新二维码',
          onPressed: onReload,
        );
      case QRStatus.unscanned:
      case QRStatus.scanned:
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.82),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.bilibili.withValues(alpha: 0.10),
                blurRadius: 22,
                spreadRadius: -7,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              backgroundColor: Colors.white,
              size: 214,
              padding: const EdgeInsets.all(12),
            ),
          ),
        );
    }
  }

  String get _statusLabel => switch (status) {
        QRStatus.loading => '正在生成二维码',
        QRStatus.unscanned => '等待扫描',
        QRStatus.scanned => '已扫描，请在手机上确认登录',
        QRStatus.expired => '二维码已失效，请刷新',
        QRStatus.failed => '二维码加载失败',
      };

  Color _statusColor(SliveColorTokens colors) => switch (status) {
        QRStatus.loading => colors.ambientBlue,
        QRStatus.unscanned => colors.bilibili,
        QRStatus.scanned => colors.success,
        QRStatus.expired => colors.ambientOrange,
        QRStatus.failed => colors.danger,
      };
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.label,
    this.actionLabel,
    this.onPressed,
  });

  final Widget icon;
  final String label;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;

    return Container(
      width: 214,
      height: 214,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.glassStrong.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.42,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.glassBorder.withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(height: 14),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 14),
            SliveGlassSurface(
              variant: SliveGlassVariant.pill,
              radius: SliveRadii.pill,
              enableBackdropBlur: false,
              onTap: onPressed,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              child: Text(
                actionLabel!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
