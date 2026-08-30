import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/requests/sync_client_request.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/sync_service.dart';

class LocalSyncController extends BaseController {
  LocalSyncController(this.address);

  final String? address;
  final TextEditingController addressController = TextEditingController();
  final TextEditingController pairingCodeController = TextEditingController();
  final SyncClientRequest request = SyncClientRequest();

  @override
  void onInit() {
    Future.delayed(Duration.zero, _initialize);
    super.onInit();
  }

  Future<void> _initialize() async {
    pageLoadding.value = true;
    try {
      await SyncService.instance.start();
      await SyncService.instance.refreshClients();
      await _applyInitialAddress();
    } catch (error) {
      handleError(error, showPageError: false);
    } finally {
      pageLoadding.value = false;
    }
  }

  Future<void> _applyInitialAddress() async {
    final value = address?.trim() ?? '';
    if (value.isEmpty) return;

    final target = await _parseConnectionInput(value);
    if (target == null) return;

    addressController.text = target.address;
    pairingCodeController.text = target.pairingCode;
    if (target.pairingCode.isNotEmpty) {
      await connect(port: target.port);
    }
  }

  Future<void> connect({int port = SyncService.httpPort}) async {
    var address = addressController.text.trim();
    if (address.isEmpty) {
      SmartDialog.showToast('请输入地址');
      return;
    }

    final uriTarget = await _parseConnectionInput(address);
    if (uriTarget != null && uriTarget.isSyncUri) {
      address = uriTarget.address;
      port = uriTarget.port;
      addressController.text = address;
      if (uriTarget.pairingCode.isNotEmpty) {
        pairingCodeController.text = uriTarget.pairingCode;
      }
    } else if (address.startsWith('http')) {
      final uri = Uri.tryParse(address);
      if (uri != null && uri.host.isNotEmpty) {
        address = uri.host;
        port = uri.hasPort ? uri.port : port;
      }
    } else if (address.contains(':') && !address.contains(';')) {
      final uri = Uri.tryParse('http://$address');
      if (uri != null && uri.host.isNotEmpty) {
        address = uri.host;
        port = uri.hasPort ? uri.port : port;
      }
    }

    final client = SyncClinet(
      id: 'manual',
      address: address,
      port: port,
      name: '手动输入',
      type: Platform.operatingSystem,
      pairingCode: pairingCodeController.text.trim(),
    );
    await connectClient(client);
  }

  Future<void> connectClient(SyncClinet client) async {
    var code = client.pairingCode.trim();
    if (!_isValidPairingCode(code)) {
      final result = await Utils.showEditTextDialog(
        '',
        title: '输入配对码',
        hintText: '请输入对方设备显示的 8 位配对码',
        validate: _isValidPairingCode,
      );
      if (result == null) return;
      code = result.trim();
    }

    final pairedClient = client.copyWith(pairingCode: code);
    try {
      SmartDialog.showLoading(msg: '连接中...');
      final info = await request.getClientInfo(pairedClient);
      await AppNavigator.toSyncDevice(pairedClient, info);
    } catch (error) {
      SmartDialog.showToast('连接失败，请检查地址和配对码');
    } finally {
      SmartDialog.dismiss();
    }
  }

  Future<void> toScanQr() async {
    final result = await Get.toNamed(RoutePath.kSyncScan);
    if (result is! String || result.trim().isEmpty) return;

    final target = await _parseConnectionInput(result.trim());
    if (target == null) {
      SmartDialog.showToast('二维码中没有有效的同步地址');
      return;
    }

    addressController.text = target.address;
    pairingCodeController.text = target.pairingCode;
    if (target.pairingCode.isNotEmpty) {
      await connect(port: target.port);
    }
  }

  Future<_SyncTarget?> _parseConnectionInput(String input) async {
    final uri = Uri.tryParse(input);
    if (uri != null && uri.scheme == 'simplelive' && uri.host == 'sync') {
      final addresses = (uri.queryParameters['addresses'] ?? '')
          .split(';')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (addresses.isEmpty) return null;

      final selectedAddress = addresses.length == 1
          ? addresses.first
          : await showPickerAddress(addresses);
      if (selectedAddress == null) return null;

      return _SyncTarget(
        address: selectedAddress,
        port: _parsePort(uri.queryParameters['port']),
        pairingCode: uri.queryParameters['code'] ?? '',
        isSyncUri: true,
      );
    }

    final addresses = input
        .split(';')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (addresses.length > 1) {
      final selectedAddress = await showPickerAddress(addresses);
      if (selectedAddress == null) return null;
      return _SyncTarget(address: selectedAddress);
    }

    return _SyncTarget(address: input);
  }

  Future<String?> showPickerAddress(List<String> addressList) async {
    SmartDialog.showToast('扫描到多个地址，请选择一个连接');
    final result = await Utils.showBottomSheet(
      title: '请选择地址',
      child: ListView.builder(
        itemCount: addressList.length,
        itemBuilder: (_, index) {
          return ListTile(
            title: Text(addressList[index]),
            onTap: () => Get.back(result: addressList[index]),
          );
        },
      ),
    );
    return result is String ? result : null;
  }

  Future<void> refreshClients() async {
    try {
      await SyncService.instance.refreshClients();
    } catch (error) {
      SmartDialog.showToast('刷新设备失败，请检查网络权限或端口占用');
    }
  }

  void showInfo() {
    Utils.showBottomSheet(
      title: '本机信息',
      child: Obx(
        () {
          final service = SyncService.instance;
          if (service.starting.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!service.httpRunning.value) {
            return Center(
              child: Padding(
                padding: AppStyle.edgeInsetsA24,
                child: Text(
                  service.httpErrorMsg.value.isEmpty
                      ? '局域网同步服务尚未启动'
                      : '局域网同步服务启动失败：${service.httpErrorMsg.value}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final addresses = service.ipAddress.value
              .split(';')
              .where((item) => item.isNotEmpty)
              .map((item) => '$item:${SyncService.httpPort}')
              .join('；');
          return ListView(
            padding: AppStyle.edgeInsetsA16,
            children: [
              Center(
                child: QrImageView(
                  data: service.connectionQrData,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                  padding: AppStyle.edgeInsetsA12,
                  size: 220,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '服务地址：$addresses',
                textAlign: TextAlign.center,
              ),
              AppStyle.vGap12,
              Text(
                '配对码  ${service.pairingCode.value}',
                textAlign: TextAlign.center,
                style: Get.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              AppStyle.vGap12,
              const Text(
                '服务仅在此页面打开期间运行。其他设备可扫码，或手动输入地址与配对码。',
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }

  int _parsePort(String? value) {
    final port = int.tryParse(value ?? '');
    if (port == null || port < 1 || port > 65535) {
      return SyncService.httpPort;
    }
    return port;
  }

  bool _isValidPairingCode(String value) {
    return RegExp(r'^\d{8}$').hasMatch(value.trim());
  }

  @override
  void onClose() {
    addressController.dispose();
    pairingCodeController.dispose();
    unawaited(SyncService.instance.stop());
    super.onClose();
  }
}

class _SyncTarget {
  const _SyncTarget({
    required this.address,
    this.port = SyncService.httpPort,
    this.pairingCode = '',
    this.isSyncUri = false,
  });

  final String address;
  final int port;
  final String pairingCode;
  final bool isSyncUri;
}
