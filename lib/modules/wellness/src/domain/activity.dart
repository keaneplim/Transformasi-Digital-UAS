import 'dart:math' as math;

import 'package:jelajah_taman/core/core.dart';

/// F08 (b, c) / T27 / D11: walked distance, active time and the kcal estimate from positions.
///
/// - **Distance** (UC-F08-2): a position counts only when its accuracy is ≤ [maxAccuracyM] and
///   it lies more than max([minStepM], accuracy / 2) from the last counted one, so a visitor
///   standing still under trees doesn't "walk" on GPS jitter. Jumps faster than
///   [maxSpeedMps] (a glitch, a car) move the anchor without counting.
/// - **Active time**: the time between two counted positions, at most the time the step takes
///   at [minActiveSpeedMps] (standing for five minutes and then taking a step is not five
///   minutes of walking).
/// - **kcal** (D11): `MET × kg × hours`, MET [metFlat] on flat or gentle ground and [metClimb]
///   on a climb steeper than [climbGrade]. The slope comes from the trail graph's heights
///   ([elevationAt]), not from the GPS altitude, which jumps by metres. Weight from Settings,
///   default [defaultWeightKg]. Always an estimate.
///
/// Pure: positions and times come in, numbers go out. The guide feeds it real fixes (real
/// mode) or the simulated walk (demo mode).
class ActivityMeter {
  ActivityMeter({double? Function(GeoPoint p)? elevationAt})
      : _elevationAt = elevationAt ?? _noElevation;

  static double? _noElevation(GeoPoint _) => null;

  static const maxAccuracyM = 20.0;
  static const minStepM = 3.0;
  static const maxSpeedMps = 3.5;
  static const minActiveSpeedMps = 0.3;
  static const climbGrade = 0.08;
  static const metFlat = 3.5;
  static const metClimb = 6.0;
  static const defaultWeightKg = 60.0;

  /// Base walking speed (D09, 3 km/h) for a distance known without its times.
  static const baseSpeedMps = 50 / 60;

  final double? Function(GeoPoint p) _elevationAt;

  double _distanceM = 0;
  double _flatS = 0;
  double _climbS = 0;
  ({GeoPoint at, DateTime time, double? ele})? _last;

  double get distanceM => _distanceM;

  /// A distance known without positions (a record written before the meter, previews):
  /// counted as flat walking at [baseSpeedMps].
  set distanceM(double m) {
    _distanceM = math.max(0, m);
    _flatS = _distanceM / baseSpeedMps;
    _climbS = 0;
  }

  Duration get activeTime => _duration(_flatS + _climbS);
  Duration get climbTime => _duration(_climbS);

  static Duration _duration(double s) =>
      Duration(milliseconds: (s * 1000).round());

  /// `MET × kg × hours` over the active time (D11).
  double kcal({double? weightKg}) =>
      (metFlat * _flatS + metClimb * _climbS) /
      3600 *
      (weightKg ?? defaultWeightKg);

  /// New session: nothing walked; the next accepted position is the starting point.
  void start() {
    _distanceM = 0;
    _flatS = 0;
    _climbS = 0;
    _last = null;
  }

  /// The visitor is at [p] without having walked there (demo teleport, session start).
  void anchor(GeoPoint p, DateTime time) =>
      _last = (at: p, time: time, ele: _elevationAt(p));

  /// One position. True when it counted as a step (the trail on the map grows then).
  bool add(GeoPoint p, DateTime time, {double accuracyM = 0}) {
    if (accuracyM > maxAccuracyM) return false;
    final last = _last;
    if (last == null) {
      anchor(p, time);
      return false;
    }
    final d = haversineM(last.at, p);
    if (d <= math.max(minStepM, accuracyM / 2)) return false;
    final dt = math.max(1, time.difference(last.time).inMilliseconds) / 1000;
    if (d / dt > maxSpeedMps) {
      anchor(p, time);
      return false;
    }
    final ele = _elevationAt(p);
    final active = math.min(dt, d / minActiveSpeedMps);
    final grade =
        (ele != null && last.ele != null) ? (ele - last.ele!) / d : 0.0;
    if (grade > climbGrade) {
      _climbS += active;
    } else {
      _flatS += active;
    }
    _distanceM += d;
    _last = (at: p, time: time, ele: ele);
    return true;
  }

  /// Snapshot for the session record (restore after an app restart). The anchor isn't kept:
  /// after a restart the next position starts a new stretch.
  Map<String, Object?> toJson() => {
        'distance_m': double.parse(_distanceM.toStringAsFixed(1)),
        'flat_s': _flatS.round(),
        'climb_s': _climbS.round(),
      };

  /// Restores what [toJson] wrote; [walkedM] is used for a record written before the meter
  /// existed (distance only: see [distanceM]).
  void restore(Map<String, Object?>? json, {double walkedM = 0}) {
    start();
    if (json == null) {
      distanceM = walkedM;
      return;
    }
    double num0(Object? v) => v is num && v >= 0 ? v.toDouble() : 0;
    _distanceM = num0(json['distance_m']);
    _flatS = num0(json['flat_s']);
    _climbS = num0(json['climb_s']);
  }
}
