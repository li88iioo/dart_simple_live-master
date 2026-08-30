typedef LocalSyncClock = DateTime Function();

class LocalSyncPairingGuard {
  LocalSyncPairingGuard({
    this.maxFailures = 5,
    this.maxTrackedClients = 256,
    this.failureWindow = const Duration(minutes: 1),
    this.blockDuration = const Duration(seconds: 30),
    LocalSyncClock? now,
  })  : assert(maxFailures > 0),
        assert(maxTrackedClients > 0),
        _now = now ?? DateTime.now;

  final int maxFailures;
  final int maxTrackedClients;
  final Duration failureWindow;
  final Duration blockDuration;
  final LocalSyncClock _now;
  final Map<String, _PairingAttemptState> _attempts = {};

  int get trackedClientCount => _attempts.length;

  Duration? blockedFor(String clientKey) {
    final now = _now();
    _removeExpired(now);
    final state = _attempts[clientKey];
    if (state == null || state.blockedUntil == null) return null;
    return state.blockedUntil!.difference(now);
  }

  void registerFailure(String clientKey) {
    final now = _now();
    _removeExpired(now);

    final blockedUntil = _attempts[clientKey]?.blockedUntil;
    if (blockedUntil != null && blockedUntil.isAfter(now)) return;

    var state = _attempts[clientKey];
    if (state == null) {
      _ensureCapacity();
      state = _PairingAttemptState(windowStart: now, lastSeen: now);
      _attempts[clientKey] = state;
    }

    state.lastSeen = now;
    state.failures++;
    if (state.failures >= maxFailures) {
      state.blockedUntil = now.add(blockDuration);
    }
  }

  void registerSuccess(String clientKey) {
    _attempts.remove(clientKey);
  }

  void clear() {
    _attempts.clear();
  }

  void _removeExpired(DateTime now) {
    _attempts.removeWhere((_, state) {
      final blockedUntil = state.blockedUntil;
      if (blockedUntil != null) {
        return !blockedUntil.isAfter(now);
      }
      return now.difference(state.windowStart) >= failureWindow;
    });
  }

  void _ensureCapacity() {
    if (_attempts.length < maxTrackedClients) return;

    String? oldestKey;
    DateTime? oldestSeen;
    for (final entry in _attempts.entries) {
      if (oldestSeen == null || entry.value.lastSeen.isBefore(oldestSeen)) {
        oldestKey = entry.key;
        oldestSeen = entry.value.lastSeen;
      }
    }
    if (oldestKey != null) {
      _attempts.remove(oldestKey);
    }
  }
}

class _PairingAttemptState {
  _PairingAttemptState({
    required this.windowStart,
    required this.lastSeen,
  });

  final DateTime windowStart;
  DateTime lastSeen;
  int failures = 0;
  DateTime? blockedUntil;
}
