/// F08 (b) / TC-12: steps from the phone's hardware step counter. Pure contracts + the
/// counting rules; the pedometer plugin adapter is in `src/data/` (R4, R5).
library;

/// The hardware step counter: total steps since the phone booted. The stream errors when
/// the phone has no step-counter sensor.
abstract interface class StepSource {
  Stream<int> cumulativeSteps();
}

/// ACTIVITY_RECOGNITION (Android 10+). Implemented in `shell` (permission_handler, R5);
/// prompting happens only when the shell asks (onboarding), never from this module.
abstract interface class StepPermissions {
  Future<bool> granted();
  Future<bool> request();
}

/// Why steps are (not) counted. The UI shows steps only when [counting].
enum StepStatus {
  /// No session, or not started yet.
  off,

  /// Waiting for the first reading from the sensor.
  starting,
  counting,

  /// "Aktivitas fisik" not allowed: distance and duration only (IMPLEMENTATION_PLAN §6.1).
  denied,

  /// The phone has no step counter (Risk R4): distance and duration only.
  noSensor,
}

/// Steps this session from cumulative sensor readings.
///
/// - The first reading after [start] is the baseline (the sensor counts since boot).
/// - A reading lower than the previous one means the phone rebooted mid-session: the count
///   restarted at 0, so those new steps are added and nothing is lost (plan F08 edge case).
/// - [toJson]/[restore] keep the count across an app restart (PB06). The sensor keeps
///   counting while the app is dead, so those steps are counted on the next reading too.
class StepCounter {
  int _steps = 0;
  int? _lastRaw;

  int get steps => _steps;

  /// A reading has arrived since [start] (or a restored baseline exists).
  bool get hasBaseline => _lastRaw != null;

  void start() {
    _steps = 0;
    _lastRaw = null;
  }

  void onReading(int raw) {
    final last = _lastRaw;
    _lastRaw = raw;
    if (last == null) return; // baseline
    final d = raw - last;
    _steps += d >= 0 ? d : raw; // d < 0: rebooted, the counter restarted from 0
  }

  Map<String, Object?> toJson() =>
      {'steps': _steps, if (_lastRaw != null) 'last_raw': _lastRaw};

  /// Restores what [toJson] wrote; malformed values start from zero.
  void restore(Map<String, Object?> json) {
    final s = json['steps'];
    final r = json['last_raw'];
    _steps = s is int && s >= 0 ? s : 0;
    _lastRaw = r is int && r >= 0 ? r : null;
  }
}
