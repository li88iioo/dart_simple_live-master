import 'dart:convert';

class SyncClientInfoModel {
  const SyncClientInfoModel({
    required this.name,
    required this.version,
    required this.address,
    required this.port,
    required this.type,
    this.protocolVersion = 1,
    this.minimumProtocolVersion = 1,
    this.authRequired = false,
    this.capabilities = const [],
  });

  factory SyncClientInfoModel.fromJson(Map<String, dynamic> json) {
    return SyncClientInfoModel(
      type: _requiredString(json, 'type'),
      name: _requiredString(json, 'name'),
      version: _requiredString(json, 'version'),
      address: _requiredString(json, 'address'),
      port: _requiredInt(json, 'port'),
      protocolVersion: _optionalInt(json['protocolVersion'], fallback: 1),
      minimumProtocolVersion: _optionalInt(
        json['minimumProtocolVersion'],
        fallback: 1,
      ),
      authRequired: json['authRequired'] == true,
      capabilities: _stringList(json['capabilities']),
    );
  }

  final String type;
  final String name;
  final String version;
  final String address;
  final int port;
  final int protocolVersion;
  final int minimumProtocolVersion;
  final bool authRequired;
  final List<String> capabilities;

  @override
  String toString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'version': version,
        'address': address,
        'port': port,
        'type': type,
        'protocolVersion': protocolVersion,
        'minimumProtocolVersion': minimumProtocolVersion,
        'authRequired': authRequired,
        'capabilities': capabilities,
      };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('设备信息缺少字段：$key');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('设备信息缺少字段：$key');
}

int _optionalInt(dynamic value, {required int fallback}) {
  return value is int ? value : fallback;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return List.unmodifiable(value.whereType<String>());
}
