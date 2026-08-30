import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';

class SyncScanQRControlelr extends BaseController {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  StreamSubscription<Barcode>? barcodeStreamSubscription;
  bool pause = false;

  void onQRViewCreated(QRViewController controller) {
    qrController = controller;
    barcodeStreamSubscription = controller.scannedDataStream.listen((scanData) {
      if (pause) return;

      final code = scanData.code?.trim() ?? '';
      if (code.isEmpty) return;

      pause = true;
      controller.pauseCamera();
      Get.back(result: code);
    });
  }

  @override
  void onClose() {
    barcodeStreamSubscription?.cancel();
    super.onClose();
  }
}
