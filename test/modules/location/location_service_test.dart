import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/location/location.dart';

class _Source implements LocationSource {
  final controller = StreamController<LocationFix>.broadcast();
  bool? lastBackground;
  Duration? lastInterval;
  int subscribes = 0;

  @override
  Stream<LocationFix> fixes(
      {required Duration interval, bool background = false}) {
    lastBackground = background;
    lastInterval = interval;
    subscribes++;
    return controller.stream;
  }
}

class _Perms implements LocationPermissions {
  LocationAccess access = LocationAccess.granted;
  Completer<LocationAccess>? pending;

  @override
  Future<LocationAccess> check() => pending?.future ?? Future.value(access);

  @override
  Future<LocationAccess> request() async => access;

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<void> openSettings() async {}
}

LocationFix fix(double acc, {double? heading}) => LocationFix(
      position: const GeoPoint(-6.85, 107.63),
      accuracyM: acc,
      at: DateTime(2026, 11, 12, 10),
      headingDeg: heading,
    );

void main() {
  test('quality: good ≤ 30 m, weak > 30 m, none after 10 s without a fix', () {
    fakeAsync((async) {
      final src = _Source();
      final s = LocationServiceImpl(source: src, permissions: _Perms());
      final seen = <GpsQuality>[];
      s.quality.listen(seen.add);
      s.start();
      async.flushMicrotasks();
      src.controller.add(fix(8));
      async.flushMicrotasks();
      expect(s.currentQuality, GpsQuality.good);
      expect(s.last!.accuracyM, 8);
      src.controller.add(fix(35));
      async.flushMicrotasks();
      expect(s.currentQuality, GpsQuality.weak);
      async.elapse(const Duration(seconds: 11));
      expect(s.currentQuality, GpsQuality.none);
      expect(seen, [GpsQuality.good, GpsQuality.weak, GpsQuality.none]);
      s.stop();
    });
  });

  test('no access → start does nothing', () async {
    final src = _Source();
    final perms = _Perms()..access = LocationAccess.denied;
    final s = LocationServiceImpl(source: src, permissions: perms);
    await s.start();
    expect(s.isRunning, isFalse);
    expect(src.lastBackground, isNull);
  });

  test('session switches the source to background updates and back', () async {
    final src = _Source();
    final s = LocationServiceImpl(source: src, permissions: _Perms());
    await s.start();
    expect(src.lastBackground, isFalse);
    await s.startSession();
    expect(src.lastBackground, isTrue);
    await s.stopSession();
    expect(src.lastBackground, isFalse);
    await s.stop();
  });

  test('heading falls back to GPS course without a compass', () async {
    final src = _Source();
    final s = LocationServiceImpl(source: src, permissions: _Perms());
    final headings = <double>[];
    s.headings.listen(headings.add);
    await s.start();
    src.controller.add(fix(5, heading: 42));
    await Future<void>.delayed(Duration.zero);
    expect(headings, [42]);
    await s.stop();
  });

  test('setInterval re-subscribes on change and stopSession resets to 3 s',
      () async {
    final src = _Source();
    final s = LocationServiceImpl(source: src, permissions: _Perms());
    await s.startSession();
    expect(src.lastInterval, const Duration(seconds: 3));
    expect(src.subscribes, 1);

    await s.setInterval(const Duration(seconds: 3));
    expect(src.subscribes, 1, reason: 'no-op when interval is unchanged');

    await s.setInterval(const Duration(seconds: 10));
    expect(s.currentInterval, const Duration(seconds: 10));
    expect(src.lastInterval, const Duration(seconds: 10));
    expect(src.lastBackground, isTrue);
    expect(src.subscribes, 2);

    await s.stopSession();
    expect(s.currentInterval, const Duration(seconds: 3));
    expect(src.lastInterval, const Duration(seconds: 3));
    expect(src.lastBackground, isFalse);
    await s.stop();
  });

  test('10 s stationary interval adapts no-fix timeout so quality stays good',
      () {
    fakeAsync((async) {
      final src = _Source();
      final s = LocationServiceImpl(source: src, permissions: _Perms());
      s.setInterval(const Duration(seconds: 10));
      s.startSession();
      async.flushMicrotasks();
      expect(src.lastInterval, const Duration(seconds: 10));
      src.controller.add(fix(6));
      async.flushMicrotasks();
      expect(s.currentQuality, GpsQuality.good);

      // 12 s would be GpsQuality.none at 3 s polling, but at 10 s polling it is normal.
      async.elapse(const Duration(seconds: 12));
      expect(s.currentQuality, GpsQuality.good);

      // Truly silent past 24 s → none.
      async.elapse(const Duration(seconds: 15));
      expect(s.currentQuality, GpsQuality.none);
      s.stop();
    });
  });

  test(
      'overlapping setInterval and stop never leaks or restarts foreground GPS (M1)',
      () async {
    final src = _Source();
    final perms = _Perms();
    final s = LocationServiceImpl(source: src, permissions: perms);
    await s.startSession();
    expect(src.subscribes, 1);
    expect(s.isRunning, isTrue);

    // Hold permission check open during setInterval, then stop before it finishes.
    perms.pending = Completer<LocationAccess>();
    final intervalCall = s.setInterval(const Duration(seconds: 10));
    final stopCall = s.stop();
    perms.pending!.complete(LocationAccess.granted);
    await Future.wait([intervalCall, stopCall]);

    expect(s.isRunning, isFalse);
    expect(s.currentInterval, const Duration(seconds: 3));
    expect(src.subscribes, 1,
        reason:
            'stale setInterval must not open a new subscription after stop');
  });

  test('currentInterval stays 3 s when permission is denied on setInterval',
      () async {
    final src = _Source();
    final perms = _Perms();
    final s = LocationServiceImpl(source: src, permissions: perms);
    await s.startSession();
    perms.access = LocationAccess.denied;
    await s.setInterval(const Duration(seconds: 10));
    expect(s.currentInterval, const Duration(seconds: 3));
    await s.stop();
  });
}
