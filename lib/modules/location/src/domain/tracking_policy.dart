import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/content/content.dart';

import 'location_contracts.dart';

/// Current adaptive tracking state (A06 / T25).
enum TrackingMode {
  /// Walking, approaching a POI, or actively navigating: 3 s updates.
  moving,

  /// No steps and speed < 0.3 m/s for 60 s: 10 s updates to save battery.
  stationary,
}

/// Tunables for battery-aware tracking (A06, park.json). Defaults = IMPLEMENTATION_PLAN A06.
class TrackingPolicyParams {
  const TrackingPolicyParams({
    this.movingInterval = const Duration(seconds: 3),
    this.stationaryInterval = const Duration(seconds: 10),
    this.stationaryAfter = const Duration(seconds: 60),
    this.stationarySpeedMps = 0.3,
    this.movingSpeedMps = 0.5,
    this.wakeDisplacementM = 5.0,
    this.weakAccuracyM = 30.0,
  });

  factory TrackingPolicyParams.fromPark(ParkConfig park) {
    double p(String k, double fallback) {
      try {
        return park.param(k);
      } on StateError {
        return fallback;
      }
    }

    return TrackingPolicyParams(
      movingInterval: Duration(seconds: p('gps_interval_s', 3).round()),
      stationaryInterval:
          Duration(seconds: p('gps_stationary_interval_s', 10).round()),
      stationaryAfter:
          Duration(seconds: p('gps_stationary_after_s', 60).round()),
      weakAccuracyM: p('gps_weak_accuracy_m', 30),
    );
  }

  final Duration movingInterval;
  final Duration stationaryInterval;
  final Duration stationaryAfter;
  final double stationarySpeedMps;
  final double movingSpeedMps;

  /// Fallback wake-up distance when the phone has no pedometer or reports no GPS speed.
  final double wakeDisplacementM;
  final double weakAccuracyM;
}

/// Pure Dart adaptive GPS interval policy (A06 / T25).
///
/// Rules (IMPLEMENTATION_PLAN A06):
/// - Moving (new step, speed > 0.5 m/s, or displacement ≥ 5 m) → 3 s.
/// - Stationary (no new steps and speed < 0.3 m/s for 60 s) → 10 s.
/// - Approaching any POI or actively navigating ([keepFast]) → always 3 s.
/// - First new step from the pedometer wakes back to 3 s immediately.
class TrackingPolicy {
  TrackingPolicy({this.params = const TrackingPolicyParams()});

  final TrackingPolicyParams params;

  TrackingMode _mode = TrackingMode.moving;
  DateTime? _stillSince;
  GeoPoint? _stillAnchor;

  TrackingMode get mode => _mode;
  bool get isStationary => _mode == TrackingMode.stationary;
  Duration get interval =>
      isStationary ? params.stationaryInterval : params.movingInterval;

  /// Pedometer reported a new step: wake back to 3 s immediately.
  Duration onStep(DateTime now) {
    _stillSince = null;
    _stillAnchor = null;
    _mode = TrackingMode.moving;
    return interval;
  }

  /// Evaluate a new GPS fix. [keepFast] must be true when approaching a POI or navigating.
  Duration onFix(LocationFix fix, DateTime now, {bool keepFast = false}) {
    if (keepFast) return _wake(fix.position);
    final good = !fix.isWeak(params.weakAccuracyM);
    final speed = fix.speedMps;
    final movedM = good && _stillAnchor != null
        ? haversineM(_stillAnchor!, fix.position)
        : 0.0;

    if ((speed != null && speed > params.movingSpeedMps) ||
        movedM >= params.wakeDisplacementM) {
      return _wake(good ? fix.position : null);
    }

    final isSlow = speed == null || speed < params.stationarySpeedMps;
    if (isSlow) {
      if (good) _stillAnchor ??= fix.position;
      _stillSince ??= now;
      if (now.difference(_stillSince!) >= params.stationaryAfter) {
        _mode = TrackingMode.stationary;
      }
    }
    return interval;
  }

  /// Periodic heartbeat evaluation (keeps the 60 s timer moving and wakes on [keepFast]).
  Duration tick(DateTime now, {bool keepFast = false}) {
    if (keepFast) return _wake(null);
    if (_stillSince != null &&
        now.difference(_stillSince!) >= params.stationaryAfter) {
      _mode = TrackingMode.stationary;
    }
    return interval;
  }

  Duration _wake(GeoPoint? anchor) {
    _stillSince = null;
    _stillAnchor = anchor;
    _mode = TrackingMode.moving;
    return interval;
  }

  /// Session boundary: start fresh in moving mode (3 s).
  void reset() {
    _mode = TrackingMode.moving;
    _stillSince = null;
    _stillAnchor = null;
  }
}
