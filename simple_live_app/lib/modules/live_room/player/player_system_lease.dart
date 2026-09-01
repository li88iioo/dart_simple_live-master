class PlayerSystemResetSnapshot {
  const PlayerSystemResetSnapshot({
    required this.systemUiChanged,
    required this.orientationChanged,
    required this.brightnessChanged,
  });

  final bool systemUiChanged;
  final bool orientationChanged;
  final bool brightnessChanged;
}

/// 串联多个直播间控制器对进程级系统状态的所有权。
///
/// 路由返回时播放器的重资源清理会延后执行。新直播间在旧清理到达前取得
/// lease 后，旧控制器不能再恢复系统栏、方向或亮度；未恢复的脏状态会由
/// 当前 lease 的最终持有者统一恢复。
class PlayerSystemLeaseCoordinator {
  int _nextId = 0;
  int _activeId = 0;
  bool _systemUiChanged = false;
  bool _orientationChanged = false;
  bool _brightnessChanged = false;

  int acquire() {
    final id = ++_nextId;
    _activeId = id;
    return id;
  }

  bool owns(int id) => id != 0 && id == _activeId;

  void markSystemUiChanged(int id) {
    if (owns(id)) _systemUiChanged = true;
  }

  void markOrientationChanged(int id) {
    if (owns(id)) _orientationChanged = true;
  }

  void markBrightnessChanged(int id) {
    if (owns(id)) _brightnessChanged = true;
  }

  void clearSystemUiChanged(int id) {
    if (owns(id)) _systemUiChanged = false;
  }

  void clearOrientationChanged(int id) {
    if (owns(id)) _orientationChanged = false;
  }

  PlayerSystemResetSnapshot? takeForReset(int id) {
    if (!owns(id)) return null;
    _activeId = 0;
    final snapshot = PlayerSystemResetSnapshot(
      systemUiChanged: _systemUiChanged,
      orientationChanged: _orientationChanged,
      brightnessChanged: _brightnessChanged,
    );
    _systemUiChanged = false;
    _orientationChanged = false;
    _brightnessChanged = false;
    return snapshot;
  }
}

final PlayerSystemLeaseCoordinator playerSystemLeaseCoordinator =
    PlayerSystemLeaseCoordinator();
