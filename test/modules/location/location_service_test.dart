import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/location/location.dart';

class _Source implements LocationSource {
  final controller = StreamController<LocationFix>.broadcast();
  bool? lastBackground;

  @override
  Stream<LocationFix> fixes(
      {required Duration interval, bool background = false}) {
    lastBackground = background;
    return controller.stream;
  }
}

class _Perms implements LocationPermissions {
  LocationAccess access = LocationAccess.granted;

  @override
  Future<LocationAccess> check() async => access;

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
}
