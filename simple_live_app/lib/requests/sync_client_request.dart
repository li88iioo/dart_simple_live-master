import 'package:simple_live_app/models/sync_client_info_model.dart';
import 'package:simple_live_app/requests/http_client.dart';
import 'package:simple_live_app/services/sync_service.dart';

class SyncClientRequest {
  Future<SyncClientInfoModel> getClientInfo(SyncClinet client) async {
    final url = 'http://${client.address}:${client.port}/info';
    final data = await HttpClient.instance.getJson(
      url,
      header: _authHeaders(client),
    );
    return SyncClientInfoModel.fromJson(data);
  }

  Future<bool> syncFollow(
    SyncClinet client,
    dynamic body, {
    bool overlay = false,
  }) {
    return _syncList(
      client,
      path: '/sync/follow',
      body: body,
      overlay: overlay,
    );
  }

  Future<bool> syncTag(
    SyncClinet client,
    dynamic body, {
    bool overlay = false,
  }) {
    return _syncList(
      client,
      path: '/sync/tag',
      body: body,
      overlay: overlay,
    );
  }

  Future<bool> syncHistory(
    SyncClinet client,
    dynamic body, {
    bool overlay = false,
  }) {
    return _syncList(
      client,
      path: '/sync/history',
      body: body,
      overlay: overlay,
    );
  }

  Future<bool> syncBlockedWord(
    SyncClinet client,
    dynamic body, {
    bool overlay = false,
  }) {
    return _syncList(
      client,
      path: '/sync/blocked_word',
      body: body,
      overlay: overlay,
    );
  }

  Future<bool> _syncList(
    SyncClinet client, {
    required String path,
    required dynamic body,
    required bool overlay,
  }) async {
    final url = 'http://${client.address}:${client.port}$path';
    final data = await HttpClient.instance.postJson(
      url,
      data: body,
      queryParameters: {
        'overlay': overlay ? '1' : '0',
      },
      header: _authHeaders(client),
    );

    if (data['status'] == true) {
      return true;
    }
    throw data['message'] ?? '同步失败';
  }

  Map<String, dynamic> _authHeaders(SyncClinet client) {
    return {
      SyncService.pairingCodeHeader: client.pairingCode,
    };
  }
}
