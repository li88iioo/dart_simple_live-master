class LocalSyncProtocol {
  const LocalSyncProtocol._();

  static const int currentVersion = 2;
  static const int minimumSupportedVersion = 2;
  static const Set<String> requiredCapabilities = {
    'follow-tag-bundle',
    'follow-tombstones',
  };

  static const List<String> capabilities = [
    'pairing-code',
    'bounded-payload',
    'private-ipv4-only',
    'follow-tag-bundle',
    'follow-tombstones',
    'serialized-writes',
    'staged-overlay-write',
  ];

  static void ensureCompatible({
    required int peerVersion,
    required int peerMinimumVersion,
    required bool authRequired,
    required Iterable<String> capabilities,
  }) {
    if (peerVersion < minimumSupportedVersion) {
      throw LocalSyncProtocolException(
        '对方设备的局域网同步协议过旧，请先升级对方设备',
      );
    }
    if (peerMinimumVersion > currentVersion) {
      throw LocalSyncProtocolException(
        '当前设备的局域网同步协议过旧，请先升级当前应用',
      );
    }
    if (!authRequired) {
      throw LocalSyncProtocolException(
        '对方设备未启用安全配对，不支持继续同步',
      );
    }
    final missingCapabilities = requiredCapabilities.difference(
      capabilities.toSet(),
    );
    if (missingCapabilities.isNotEmpty) {
      throw LocalSyncProtocolException(
        '对方设备缺少必要的安全同步能力，请先升级对方设备',
      );
    }
  }
}

class LocalSyncProtocolException implements Exception {
  const LocalSyncProtocolException(this.message);

  final String message;

  @override
  String toString() => message;
}
