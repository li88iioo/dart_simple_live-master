import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/common/webdav_endpoint_policy.dart';

void main() {
  test('accepts HTTPS endpoints and trims surrounding whitespace', () {
    expect(
      WebDavEndpointPolicy.parse('  https://dav.example.com/root  ').toString(),
      'https://dav.example.com/root',
    );
  });

  test('allows cleartext only for private or local endpoints', () {
    for (final value in [
      'http://127.0.0.1:8080/dav',
      'http://192.168.1.8/dav',
      'http://10.0.0.3/dav',
      'http://172.20.0.2/dav',
      'http://nas.local/dav',
      'http://[::1]/dav',
      'http://[fd00::2]/dav',
    ]) {
      expect(WebDavEndpointPolicy.parse(value), isA<Uri>(), reason: value);
    }
  });

  test('rejects public HTTP and credentials embedded in urls', () {
    expect(
      () => WebDavEndpointPolicy.parse('http://dav.example.com/root'),
      throwsFormatException,
    );
    expect(
      () => WebDavEndpointPolicy.parse(
        'https://alice:secret@dav.example.com/root',
      ),
      throwsFormatException,
    );
  });
}
