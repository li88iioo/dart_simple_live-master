import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/version_model.dart';

void main() {
  test('parseVersion handles semantic suffixes without collisions', () {
    expect(Utils.parseVersion('1.8.16'), 10816);
    expect(Utils.parseVersion('1.8.16+10819'), 10816);
    expect(Utils.parseVersion('1.8.16-beta.1'), 10816);
    expect(Utils.parseVersion('2.0'), 20000);
    expect(() => Utils.parseVersion('1.100.0'), throwsFormatException);
  });

  test('VersionModel accepts an optional remote build number', () {
    final withoutBuild = VersionModel.fromJson({
      'version': '1.8.16',
      'version_num': 10816,
      'version_desc': 'stable',
      'download_url': 'https://example.com',
    });
    final withBuild = VersionModel.fromJson({
      'version': '1.8.16',
      'version_num': 10816,
      'build_num': 10820,
      'version_desc': 'hotfix',
      'download_url': 'https://example.com',
    });

    expect(withoutBuild.buildNum, isNull);
    expect(withBuild.buildNum, 10820);
    expect(withBuild.toJson()['build_num'], 10820);
    expect(
      withoutBuild.isNewerThan(
        currentVersionNum: 10816,
        currentBuildNum: 10819,
      ),
      isFalse,
    );
    expect(
      withBuild.isNewerThan(
        currentVersionNum: 10816,
        currentBuildNum: 10819,
      ),
      isTrue,
    );
  });
}
