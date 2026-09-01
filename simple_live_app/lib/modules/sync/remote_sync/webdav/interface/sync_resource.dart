import 'package:archive/archive.dart';

abstract class SyncResource<T> {
  String get fileName;

  Future<T> loadLocal();

  /// 从下载后的 archive 中读取
  T? loadRemote(Archive archive);

  Future<void> saveLocal(T data);

  /// 写入待上传的 archive
  void saveRemote(Archive archive, T data);

  T merge(T local, T remote);
}

/// 只有带“本地待同步增量”的资源需要实现。远端首次不存在时，先把增量
/// 折叠进最终快照，避免首次上传后下次同步再次累加。
abstract interface class InitialBidirectionalSyncResource<T> {
  T prepareInitialBidirectional(T local);
}
