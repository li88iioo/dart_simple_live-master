import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/log.dart';

void main() {
  test('redacts common secrets without removing surrounding context', () {
    final value = Log.sanitize(
      'Cookie: sid=abc; token="top-secret" password=hunter2 room=123',
    );

    expect(value, contains('Cookie: <redacted>'));
    expect(value, contains('token=<redacted>'));
    expect(value, contains('password=<redacted>'));
    expect(value, contains('room=123'));
    expect(value, isNot(contains('top-secret')));
    expect(value, isNot(contains('hunter2')));
  });

  test('redacts credentials embedded in an http uri', () {
    expect(
      Log.sanitize('https://alice:secret@example.com/dav'),
      'https://<redacted>@example.com/dav',
    );
  });
}
