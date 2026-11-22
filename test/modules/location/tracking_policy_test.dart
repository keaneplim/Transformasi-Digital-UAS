import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/location/location.dart';

import '../../helpers/test_content.dart';

/// T25 / A06 battery-aware tracking policy tests (pure Dart, no device).
void main() {
  final t0 = DateTime(2026, 11, 22, 10);
  const origin = GeoPoint(-6.858, 107.630);
  // ~10 m north of origin
  const north10m = GeoPoint(-6.85791, 107.630);

  LocationFix fix(DateTime at,
          {GeoPoint pos = origin, double acc = 6, double? speed}) =>
      LocationFix(position: pos, accuracyM: acc, at: at, speedMps: speed);

  /// Feeds continuous low-motion fixes every 10 s from [start] through [seconds].
  void standStill(TrackingPolicy p, DateTime start, int seconds,
      {double? speed = 0.0}) {
    for (var s = 0; s <= seconds; s += 10) {
      final at = start.add(Duration(seconds: s));
      p.onFix(fix(at, speed: speed), at);
    }
  }

  test('stays 3 s while moving, switches to 10 s after 60 s continuous still',
      () {
    final p = TrackingPolicy();
    expect(p.interval, const Duration(seconds: 3));
    expect(p.mode, TrackingMode.moving);

    standStill(p, t0, 50, speed: 0.1);
    p.onFix(fix(t0.add(const Duration(seconds: 59)), speed: 0.2),
        t0.add(const Duration(seconds: 59)));
    expect(p.interval, const Duration(seconds: 3), reason: 'not yet 60 s');

    p.onFix(fix(t0.add(const Duration(seconds: 60)), speed: 0.1),
        t0.add(const Duration(seconds: 60)));
    expect(p.interval, const Duration(seconds: 10));
    expect(p.isStationary, isTrue);
  });

  test('first pedometer step wakes back to 3 s immediately', () {
    final p = TrackingPolicy();
    standStill(p, t0, 60);
    expect(p.isStationary, isTrue);

    final interval = p.onStep(t0.add(const Duration(seconds: 61)));
    expect(interval, const Duration(seconds: 3));
    expect(p.mode, TrackingMode.moving);
  });

  test('speed > 0.5 m/s wakes back to 3 s immediately', () {
    final p = TrackingPolicy();
    standStill(p, t0, 60);
    expect(p.isStationary, isTrue);

    p.onFix(fix(t0.add(const Duration(seconds: 65)), speed: 0.8),
        t0.add(const Duration(seconds: 65)));
    expect(p.interval, const Duration(seconds: 3));
  });

  test('displacement ≥ 5 m wakes when speed is unavailable (no pedometer)', () {
    final p = TrackingPolicy();
    standStill(p, t0, 60, speed: null);
    expect(p.isStationary, isTrue);

    p.onFix(fix(t0.add(const Duration(seconds: 70)), pos: north10m),
        t0.add(const Duration(seconds: 70)));
    expect(p.interval, const Duration(seconds: 3));
  });

  test('approaching POI or active navigation keeps 3 s and wakes stationary',
      () {
    final p = TrackingPolicy();
    for (var s = 0; s <= 120; s += 10) {
      final at = t0.add(Duration(seconds: s));
      p.onFix(fix(at, speed: 0.0), at, keepFast: true);
    }
    expect(p.interval, const Duration(seconds: 3),
        reason: 'never slow down near a POI or while navigating');

    // Now allow slowing down, then approach a POI.
    final t1 = t0.add(const Duration(minutes: 6));
    standStill(p, t1, 60);
    expect(p.isStationary, isTrue);

    p.tick(t1.add(const Duration(seconds: 65)), keepFast: true);
    expect(p.interval, const Duration(seconds: 3));
  });

  test(
      'deadband speed (0.4 m/s) resets partial still window while moving, keeps hysteresis once stationary',
      () {
    final p = TrackingPolicy();
    // Start with a slow fix, then move at 0.4 m/s (slow walk): must NOT become stationary.
    p.onFix(fix(t0, speed: 0.1), t0);
    for (var s = 10; s <= 90; s += 10) {
      final at = t0.add(Duration(seconds: s));
      p.onFix(fix(at, speed: 0.4), at);
      p.tick(at);
    }
    expect(p.mode, TrackingMode.moving);

    // Truly stand still for 60 s → stationary.
    final t1 = t0.add(const Duration(minutes: 3));
    standStill(p, t1, 60);
    expect(p.isStationary, isTrue);

    // Once stationary, a 0.4 m/s deadband fix keeps stationary hysteresis.
    p.onFix(fix(t1.add(const Duration(seconds: 70)), speed: 0.4),
        t1.add(const Duration(seconds: 70)));
    expect(p.isStationary, isTrue);
  });

  test('GPS outage after one slow fix never throttles to 10 s (stale fix)', () {
    final p = TrackingPolicy();
    p.onFix(fix(t0, speed: 0.0), t0);
    // No fixes arrive for 60 s (e.g. cave/canopy): heartbeat must not switch to stationary.
    p.tick(t0.add(const Duration(seconds: 30)));
    p.tick(t0.add(const Duration(seconds: 60)));
    expect(p.mode, TrackingMode.moving);
    expect(p.interval, const Duration(seconds: 3));

    // A slow fix after a 60 s gap starts a brand-new 60 s window instead of firing at once.
    p.onFix(fix(t0.add(const Duration(seconds: 65)), speed: 0.0),
        t0.add(const Duration(seconds: 65)));
    expect(p.mode, TrackingMode.moving);
  });

  test('reset restores moving 3 s state; params load from park.json', () {
    final content = loadTestContent();
    final params = TrackingPolicyParams.fromPark(content.park);
    expect(params.movingInterval, const Duration(seconds: 3));
    expect(params.stationaryInterval, const Duration(seconds: 10));
    expect(params.stationaryAfter, const Duration(seconds: 60));

    final p = TrackingPolicy(params: params);
    standStill(p, t0, 60);
    expect(p.isStationary, isTrue);
    p.reset();
    expect(p.mode, TrackingMode.moving);
    expect(p.interval, const Duration(seconds: 3));
  });
}
