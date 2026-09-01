class WebDavEndpointPolicy {
  const WebDavEndpointPolicy._();

  static Uri parse(String value) {
    final normalized = value.trim();
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      throw const FormatException('请输入完整的 WebDAV 服务器地址');
    }
    if (uri.userInfo.isNotEmpty) {
      throw const FormatException('请勿把账号密码写入 WebDAV 地址');
    }
    if (uri.fragment.isNotEmpty) {
      throw const FormatException('WebDAV 地址不能包含 #fragment');
    }
    if (uri.scheme == 'https') return uri;
    if (uri.scheme != 'http') {
      throw const FormatException('WebDAV 仅支持 https://，局域网可使用 http://');
    }
    if (!_isPrivateOrLocalHost(uri.host)) {
      throw const FormatException('公网 WebDAV 必须使用 HTTPS，HTTP 仅允许局域网地址');
    }
    return uri;
  }

  static bool _isPrivateOrLocalHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' || normalized.endsWith('.local')) return true;

    final address = Uri.tryParse('http://[$normalized]')?.host;
    if (normalized.contains(':')) {
      final ipv6 = address ?? normalized;
      return ipv6 == '::1' ||
          ipv6.startsWith('fe80:') ||
          ipv6.startsWith('fc') ||
          ipv6.startsWith('fd');
    }

    final parts = normalized.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList(growable: false);
    if (octets.any((part) => part == null || part < 0 || part > 255)) {
      return false;
    }
    final first = octets[0]!;
    final second = octets[1]!;
    return first == 10 ||
        first == 127 ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }
}
