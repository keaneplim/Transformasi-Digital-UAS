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

  test('stays 3 s while moving, switches to 10 s after 60 s stationary', () {
    final p = TrackingPolicy();
    expect(p.interval, const Duration(seconds: 3));
    expect(p.mode, TrackingMode.moving);

    p.onFix(fix(t0, speed: 0.1), t0);
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
    p.onFix(fix(t0, speed: 0.0), t0);
    p.tick(t0.add(const Duration(seconds: 60)));
    expect(p.isStationary, isTrue);

    final interval = p.onStep(t0.add(const Duration(seconds: 61)));
    expect(interval, const Duration(seconds: 3));
    expect(p.mode, TrackingMode.moving);
  });

  test('speed > 0.5 m/s wakes back to 3 s immediately', () {
    final p = TrackingPolicy();
    p.onFix(fix(t0, speed: 0.0), t0);
    p.tick(t0.add(const Duration(seconds: 60)));
    expect(p.isStationary, isTrue);

    p.onFix(fix(t0.add(const Duration(seconds: 65)), speed: 0.8),
        t0.add(const Duration(seconds: 65)));
    expect(p.interval, const Duration(seconds: 3));
  });

  test('displacement ≥ 5 m wakes when speed is unavailable (no pedometer)', () {
    final p = TrackingPolicy();
    p.onFix(fix(t0), t0);
    p.tick(t0.add(const Duration(seconds: 60)));
    expect(p.isStationary, isTrue);

    p.onFix(fix(t0.add(const Duration(seconds: 70)), pos: north10m),
        t0.add(const Duration(seconds: 70)));
    expect(p.interval, const Duration(seconds: 3));
  });

  test('approaching POI or active navigation keeps 3 s and wakes stationary',
      () {
    final p = TrackingPolicy();
    p.onFix(fix(t0, speed: 0.0), t0, keepFast: true);
    p.tick(t0.add(const Duration(minutes: 5)), keepFast: true);
    expect(p.interval, const Duration(seconds: 3),
        reason: 'never slow down near a POI or while navigating');

    // Now allow slowing down, then approach a POI.
    p.onFix(fix(t0.add(const Duration(minutes: 6)), speed: 0.0),
        t0.add(const Duration(minutes: 6)));
    p.tick(t0.add(const Duration(minutes: 7)));
    expect(p.isStationary, isTrue);

    p.tick(t0.add(const Duration(minutes: 7, seconds: 5)), keepFast: true);
    expect(p.interval, const Duration(seconds: 3));
  });

  test('deadband speed (0.3–0.5 m/s) preserves current mode without flapping',
      () {
    final p = TrackingPolicy();
    p.onFix(fix(t0, speed: 0.4), t0);
    p.tick(t0.add(const Duration(minutes: 2)));
    expect(p.mode, TrackingMode.moving);

    p.onFix(fix(t0.add(const Duration(minutes: 3)), speed: 0.0),
        t0.add(const Duration(minutes: 3)));
    p.tick(t0.add(const Duration(minutes: 4)));
    expect(p.isStationary, isTrue);

    p.onFix(fix(t0.add(const Duration(minutes: 4, seconds: 10)), speed: 0.4),
        t0.add(const Duration(minutes: 4, seconds: 10)));
    expect(p.isStationary, isTrue);
  });

  test('reset restores moving 3 s state; params load from park.json', () {
    final content = loadTestContent();
    final params = TrackingPolicyParams.fromPark(content.park);
    expect(params.movingInterval, const Duration(seconds: 3));
    expect(params.stationaryInterval, const Duration(seconds: 10));
    expect(params.stationaryAfter, const Duration(seconds: 60));

    final p = TrackingPolicy(params: params);
    p.onFix(fix(t0, speed: 0.0), t0);
    p.tick(t0.add(const Duration(seconds: 60)));
    expect(p.isStationary, isTrue);
    p.reset();
    expect(p.mode, TrackingMode.moving);
    expect(p.interval, const Duration(seconds: 3));
  });
}
