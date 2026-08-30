import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/modules/sync/local_sync/scan_qr/sync_scan_qr_controller.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';

class SyncScanQRPage extends GetView<SyncScanQRControlelr> {
  const SyncScanQRPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SlivePageScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 72,
        foregroundColor: Colors.white,
        title: const Text(
          '扫描二维码',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: _ScannerActionButton(
              icon: Icons.arrow_back_rounded,
              tooltip: '返回',
              onPressed: Get.back,
            ),
          ),
        ),
        actions: [
          _ScannerActionButton(
            icon: Icons.flash_on_rounded,
            tooltip: '切换闪光灯',
            onPressed: () => controller.qrController?.toggleFlash(),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ScannerActionButton(
              icon: Icons.flip_camera_android_rounded,
              tooltip: '切换摄像头',
              onPressed: () => controller.qrController?.flipCamera(),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          QRView(
            key: controller.qrKey,
            onQRViewCreated: controller.onQRViewCreated,
          ),
          const IgnorePointer(child: _ScannerScrim()),
          const IgnorePointer(child: ScanRectangle()),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: SliveGlassSurface(
                    variant: SliveGlassVariant.overlay,
                    enableBackdropBlur: true,
                    radius: SliveRadii.pill,
                    color: Colors.black,
                    borderColor: Colors.white.withValues(alpha: 0.24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.center_focus_strong_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '将另一台设备的同步二维码置于框内',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerActionButton extends StatelessWidget {
  const _ScannerActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SliveGlassSurface(
        variant: SliveGlassVariant.pill,
        enableBackdropBlur: false,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        color: Colors.black,
        borderColor: Colors.white.withValues(alpha: 0.24),
        onTap: onPressed,
        child: Center(
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}

class _ScannerScrim extends StatelessWidget {
  const _ScannerScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.56),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.56),
          ],
          stops: const [0, 0.24, 0.70, 1],
        ),
      ),
    );
  }
}

class ScanRectangle extends StatefulWidget {
  const ScanRectangle({super.key});

  @override
  State<ScanRectangle> createState() => _ScanRectangleState();
}

class _ScanRectangleState extends State<ScanRectangle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;
  bool? _motionEnabled;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldAnimate = !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (shouldAnimate == _motionEnabled) return;

    _motionEnabled = shouldAnimate;
    if (shouldAnimate) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.max(132.0, constraints.maxWidth - 48);
        final availableHeight = math.max(132.0, constraints.maxHeight * 0.48);
        final side = math.min(280.0, math.min(availableWidth, availableHeight));
        final travel = math.max(0.0, side - 40);

        return Center(
          child: SizedBox.square(
            dimension: side,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: const _ScannerFramePainter(),
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 18,
                  right: 18,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, travel * _animation.value),
                      child: child,
                    ),
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xFF9CF5C4),
                            Colors.white,
                            Color(0xFF9CF5C4),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF83E7B0).withValues(alpha: 0.72),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class _ScannerFramePainter extends CustomPainter {
  const _ScannerFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const length = 34.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.94)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, length)
      ..lineTo(0, 12)
      ..quadraticBezierTo(0, 0, 12, 0)
      ..lineTo(length, 0)
      ..moveTo(size.width - length, 0)
      ..lineTo(size.width - 12, 0)
      ..quadraticBezierTo(size.width, 0, size.width, 12)
      ..lineTo(size.width, length)
      ..moveTo(size.width, size.height - length)
      ..lineTo(size.width, size.height - 12)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - 12,
        size.height,
      )
      ..lineTo(size.width - length, size.height)
      ..moveTo(length, size.height)
      ..lineTo(12, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - 12)
      ..lineTo(0, size.height - length);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) => false;
}
