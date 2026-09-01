import 'dart:convert';

T? asT<T>(dynamic value) {
  if (value is T) {
    return value;
  }
  return null;
}

class VersionModel {
  VersionModel({
    required this.version,
    required this.versionNum,
    this.buildNum,
    required this.versionDesc,
    required this.downloadUrl,
  });

  factory VersionModel.fromJson(Map<String, dynamic> json) => VersionModel(
        version: asT<String>(json['version'])!,
        versionNum: asT<int>(json['version_num'])!,
        buildNum: asT<int>(json['build_num']),
        versionDesc: asT<String>(json['version_desc'])!,
        downloadUrl: asT<String>(json['download_url'])!,
      );

  String version;
  int versionNum;
  int? buildNum;
  String versionDesc;
  String downloadUrl;

  bool isNewerThan({
    required int currentVersionNum,
    required int currentBuildNum,
  }) {
    if (versionNum != currentVersionNum) {
      return versionNum > currentVersionNum;
    }
    return (buildNum ?? 0) > currentBuildNum;
  }

  @override
  String toString() {
    return jsonEncode(this);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'version_num': versionNum,
        if (buildNum != null) 'build_num': buildNum,
        'version_desc': versionDesc,
        'download_url': downloadUrl,
      };
}
