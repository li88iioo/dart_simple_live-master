class LocalSyncEndpoint {
  const LocalSyncEndpoint({
    required this.address,
    this.port = defaultPort,
  });

  static const int defaultPort = 23234;

  final String address;
  final int port;

  String get displayAddress => port == defaultPort ? address : '$address:$port';

  Uri uriFor(String path) {
    if (!path.startsWith('/') || path.contains('?') || path.contains('#')) {
      throw ArgumentError.value(path, 'path', '必须是单纯的绝对路径');
    }
    return Uri(
      scheme: 'http',
      host: address,
      port: port,
      path: path,
    );
  }

  static LocalSyncEndpoint parse(
    String input, {
    int defaultPort = LocalSyncEndpoint.defaultPort,
  }) {
    _validatePort(defaultPort);
    final value = input.trim();
    if (value.isEmpty) {
      throw const FormatException('同步地址不能为空');
    }
    if (RegExp(r'\s').hasMatch(value)) {
      throw const FormatException('同步地址不能包含空白字符');
    }

    if (value.contains('://')) {
      return _parseHttpUri(value, defaultPort: defaultPort);
    }

    if (value.contains('@') ||
        value.contains('/') ||
        value.contains('?') ||
        value.contains('#')) {
      throw const FormatException('同步地址格式无效');
    }

    final segments = value.split(':');
    if (segments.length > 2) {
      throw const FormatException('暂不支持 IPv6 同步地址');
    }

    final address = segments.first;
    final port =
        segments.length == 2 ? _parseRequiredPort(segments.last) : defaultPort;
    _validateAddress(address);
    return LocalSyncEndpoint(address: address, port: port);
  }

  static LocalSyncEndpoint? tryParse(
    String input, {
    int defaultPort = LocalSyncEndpoint.defaultPort,
  }) {
    try {
      return parse(input, defaultPort: defaultPort);
    } on FormatException {
      return null;
    }
  }

  static bool isAllowedAddress(String address) {
    final octets = _parseIpv4(address);
    if (octets == null) return false;

    final first = octets[0];
    final second = octets[1];
    return first == 10 ||
        first == 127 ||
        (first == 100 && second >= 64 && second <= 127) ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }

  static LocalSyncEndpoint _parseHttpUri(
    String value, {
    required int defaultPort,
  }) {
    final Uri uri;
    try {
      uri = Uri.parse(value);
    } on FormatException {
      throw const FormatException('同步地址格式无效');
    }

    if (uri.scheme.toLowerCase() != 'http' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('仅支持无路径、无参数的局域网 HTTP 地址');
    }

    final int port;
    try {
      port = uri.hasPort ? uri.port : defaultPort;
    } on FormatException {
      throw const FormatException('同步端口无效');
    }
    _validatePort(port);
    _validateAddress(uri.host);
    return LocalSyncEndpoint(address: uri.host, port: port);
  }

  static void _validateAddress(String address) {
    if (!isAllowedAddress(address)) {
      throw const FormatException('仅允许连接局域网 IPv4 地址');
    }
  }

  static int _parseRequiredPort(String value) {
    if (value.isEmpty || !RegExp(r'^\d+$').hasMatch(value)) {
      throw const FormatException('同步端口无效');
    }
    final port = int.tryParse(value);
    _validatePort(port);
    return port!;
  }

  static void _validatePort(int? port) {
    if (port == null || port < 1 || port > 65535) {
      throw const FormatException('同步端口必须在 1 到 65535 之间');
    }
  }

  static List<int>? _parseIpv4(String address) {
    final segments = address.split('.');
    if (segments.length != 4) return null;

    final octets = <int>[];
    for (final segment in segments) {
      if (!RegExp(r'^\d{1,3}$').hasMatch(segment)) return null;
      final value = int.tryParse(segment);
      if (value == null || value > 255) return null;
      octets.add(value);
    }
    return octets;
  }
}

class LocalSyncConnectionInput {
  const LocalSyncConnectionInput({
    required this.endpoints,
    this.pairingCode = '',
  });

  final List<LocalSyncEndpoint> endpoints;
  final String pairingCode;

  static LocalSyncConnectionInput parse(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      throw const FormatException('同步地址不能为空');
    }

    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme.toLowerCase() == 'simplelive') {
      return _parseSyncUri(uri);
    }

    final endpoints = _parseEndpointList(value);
    return LocalSyncConnectionInput(endpoints: endpoints);
  }

  static LocalSyncConnectionInput? tryParse(String input) {
    try {
      return parse(input);
    } on FormatException {
      return null;
    }
  }

  static LocalSyncConnectionInput _parseSyncUri(Uri uri) {
    if (uri.host.toLowerCase() != 'sync' ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasFragment) {
      throw const FormatException('同步二维码格式无效');
    }

    final addressValue = uri.queryParameters['addresses']?.trim() ?? '';
    if (addressValue.isEmpty) {
      throw const FormatException('同步二维码中没有地址');
    }

    final int defaultPort;
    if (uri.queryParameters.containsKey('port')) {
      final portValue = uri.queryParameters['port'] ?? '';
      defaultPort = LocalSyncEndpoint._parseRequiredPort(portValue);
    } else {
      defaultPort = LocalSyncEndpoint.defaultPort;
    }

    final pairingCode = uri.queryParameters['code']?.trim() ?? '';
    if (pairingCode.isNotEmpty && !RegExp(r'^\d{8}$').hasMatch(pairingCode)) {
      throw const FormatException('同步二维码中的配对码无效');
    }

    return LocalSyncConnectionInput(
      endpoints: _parseEndpointList(
        addressValue,
        defaultPort: defaultPort,
      ),
      pairingCode: pairingCode,
    );
  }

  static List<LocalSyncEndpoint> _parseEndpointList(
    String value, {
    int defaultPort = LocalSyncEndpoint.defaultPort,
  }) {
    final parts = value
        .split(';')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      throw const FormatException('同步地址不能为空');
    }

    final endpoints = parts
        .map(
          (item) => LocalSyncEndpoint.parse(
            item,
            defaultPort: defaultPort,
          ),
        )
        .toList(growable: false);

    final unique = <String, LocalSyncEndpoint>{};
    for (final endpoint in endpoints) {
      unique['${endpoint.address}:${endpoint.port}'] = endpoint;
    }
    return List.unmodifiable(unique.values);
  }
}
