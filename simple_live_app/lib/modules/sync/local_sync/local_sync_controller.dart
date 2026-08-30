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
import 'package:simple_live_app/services/local_sync_endpoint.dart';
import 'package:simple_live_app/services/sync_service.dart';

class LocalSyncController extends BaseController {
  LocalSyncController(this.address);

  final String? address;
  final TextEditingController addressController = TextEditingController();
  final TextEditingController pairingCodeController = TextEditingController();
  final SyncClientRequest request = SyncClientRequest();

  bool _active = true;

  @override
  void onInit() {
    super.onInit();
    unawaited(Future<void>.delayed(Duration.zero, _initialize));
  }

  Future<void> _initialize() async {
    if (!_active) return;

    pageLoadding.value = true;
    try {
      await SyncService.instance.start();
      if (!_active) return;

      await SyncService.instance.refreshClients(ensureStarted: false);
      if (!_active) return;

      await _applyInitialAddress();
    } catch (error) {
      if (_active) {
        handleError(error, showPageError: false);
      }
    } finally {
      if (_active) {
        pageLoadding.value = false;
      }
    }
  }

  Future<void> _applyInitialAddress() async {
    if (!_active) return;

    final value = address?.trim() ?? '';
    if (value.isEmpty) return;

    final target = await _selectConnectionTarget(value);
    if (!_active || target == null) return;

    _applyTarget(target);
    if (target.pairingCode.isNotEmpty) {
      await _connectEndpoint(target.endpoint);
    }
  }

  Future<void> connect() async {
    if (!_active) return;

    final input = addressController.text.trim();
    if (input.isEmpty) {
      SmartDialog.showToast('请输入地址');
      return;
    }

    final target = await _selectConnectionTarget(input);
    if (!_active || target == null) return;

    _applyTarget(target);
    await _connectEndpoint(target.endpoint);
  }

  Future<void> _connectEndpoint(LocalSyncEndpoint endpoint) async {
    if (!_active) return;

    final client = SyncClinet(
      id: 'manual',
      address: endpoint.address,
      port: endpoint.port,
      name: '手动输入',
      type: Platform.operatingSystem,
      pairingCode: pairingCodeController.text.trim(),
    );
    await connectClient(client);
  }

  Future<void> connectClient(SyncClinet client) async {
    if (!_active) return;

    final endpoint = LocalSyncEndpoint.tryParse(
      '${client.address}:${client.port}',
    );
    if (endpoint == null) {
      SmartDialog.showToast('仅支持连接局域网 IPv4 地址');
      return;
    }

    var code = client.pairingCode.trim();
    if (!_isValidPairingCode(code)) {
      final result = await Utils.showEditTextDialog(
        '',
        title: '输入配对码',
        hintText: '请输入对方设备显示的 8 位配对码',
        validate: _isValidPairingCode,
      );
      if (!_active || result == null) return;
      code = result.trim();
    }

    final pairedClient = client.copyWith(
      address: endpoint.address,
      port: endpoint.port,
      pairingCode: code,
    );
    try {
      SmartDialog.showLoading(msg: '连接中...');
      final info = await request.getClientInfo(pairedClient);
      if (!_active) return;

      await AppNavigator.toSyncDevice(pairedClient, info);
    } catch (error) {
      if (_active) {
        SmartDialog.showToast('连接失败，请检查地址和配对码');
      }
    } finally {
      SmartDialog.dismiss();
    }
  }

  Future<void> toScanQr() async {
    if (!_active) return;

    final result = await Get.toNamed(RoutePath.kSyncScan);
    if (!_active || result is! String || result.trim().isEmpty) return;

    final target = await _selectConnectionTarget(result.trim());
    if (!_active || target == null) return;

    _applyTarget(target);
    if (target.pairingCode.isNotEmpty) {
      await _connectEndpoint(target.endpoint);
    }
  }

  Future<_SelectedSyncTarget?> _selectConnectionTarget(String input) async {
    final LocalSyncConnectionInput parsed;
    try {
      parsed = LocalSyncConnectionInput.parse(input);
    } on FormatException catch (error) {
      if (_active) {
        SmartDialog.showToast(error.message.toString());
      }
      return null;
    }

    if (!_active) return null;

    final endpoint = parsed.endpoints.length == 1
        ? parsed.endpoints.first
        : await showPickerAddress(parsed.endpoints);
    if (!_active || endpoint == null) return null;

    return _SelectedSyncTarget(
      endpoint: endpoint,
      pairingCode: parsed.pairingCode,
    );
  }

  void _applyTarget(_SelectedSyncTarget target) {
    if (!_active) return;

    addressController.text = target.endpoint.displayAddress;
    if (target.pairingCode.isNotEmpty) {
      pairingCodeController.text = target.pairingCode;
    }
  }

  Future<LocalSyncEndpoint?> showPickerAddress(
    List<LocalSyncEndpoint> addressList,
  ) async {
    if (!_active) return null;

    SmartDialog.showToast('扫描到多个地址，请选择一个连接');
    final result = await Utils.showBottomSheet(
      title: '请选择地址',
      child: ListView.builder(
        itemCount: addressList.length,
        itemBuilder: (_, index) {
          final endpoint = addressList[index];
          return ListTile(
            title: Text(endpoint.displayAddress),
            onTap: () => Get.back(result: endpoint),
          );
        },
      ),
    );
    if (!_active) return null;
    return result is LocalSyncEndpoint ? result : null;
  }

  Future<void> refreshClients() async {
    if (!_active) return;

    try {
      await SyncService.instance.refreshClients();
    } catch (error) {
      if (_active) {
        SmartDialog.showToast('刷新设备失败，请检查网络权限或端口占用');
      }
    }
  }

  void showInfo() {
    if (!_active) return;

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

  bool _isValidPairingCode(String value) {
    return RegExp(r'^\d{8}$').hasMatch(value.trim());
  }

  @override
  void onClose() {
    _active = false;
    addressController.dispose();
    pairingCodeController.dispose();
    unawaited(SyncService.instance.stop());
    super.onClose();
  }
}

class _SelectedSyncTarget {
  const _SelectedSyncTarget({
    required this.endpoint,
    this.pairingCode = '',
  });

  final LocalSyncEndpoint endpoint;
  final String pairingCode;
}
