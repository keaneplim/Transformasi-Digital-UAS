import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/modules/location/location.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/trigger/trigger.dart';
import 'package:jelajah_taman/modules/shell/src/state/guide_controller.dart';

import '../../helpers/test_content.dart';

/// GPS stand-in: the test pushes fixes.
class FakeLocation implements LocationService {
  final _fixes = StreamController<LocationFix>.broadcast(sync: true);
  LocationAccess granted = LocationAccess.granted;
  int sessions = 0;

  void push(GeoPoint p, DateTime at, {double acc = 6}) =>
      _fixes.add(LocationFix(position: p, accuracyM: acc, at: at));

  @override
  Stream<LocationFix> get fixes => _fixes.stream;
  @override
  Stream<GpsQuality> get quality => const Stream.empty();
  @override
  Stream<double> get headings => const Stream.empty();
  @override
  LocationFix? get last => null;
  @override
  GpsQuality get currentQuality => GpsQuality.good;
  @override
  bool get isRunning => true;
  @override
  Future<LocationAccess> access() async => granted;
  @override
  Future<LocationAccess> requestAccess() async => granted;
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> start() async {}
  @override
  Future<void> startSession() async => sessions++;
  @override
  Future<void> stopSession() async {}
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding
      .ensureInitialized(); // haptics go through a platform channel
  late FakeLocation gps;
  late FakeClock clock;
  late ProviderContainer c;
  late MemoryKeyValueStore store;
  GuideController guide() => c.read(guideProvider);

  setUp(() {
    gps = FakeLocation();
    clock = FakeClock(DateTime(2026, 11, 14, 10));
    store = MemoryKeyValueStore();
    c = ProviderContainer(overrides: [
      ...buildOverrides(
          content: loadTestContent(), clock: clock, basemap: loadTestBasemap()),
      locationServiceProvider.overrideWithValue(gps),
      keyValueStoreProvider.overrideWithValue(store),
    ]);
  });
  tearDown(() => c.dispose());

  /// One fix [s] seconds after the previous one.
  void walk(GeoPoint p, {int s = 3, double acc = 6}) {
    clock.advance(Duration(seconds: s));
    gps.push(p, clock.now(), acc: acc);
  }

  GeoPoint lerp(GeoPoint a, GeoPoint b, double t) =>
      GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);

  test('real mode is the default; without a fix distances start at the gate',
      () {
    final g = guide();
    expect(g.mode, AppMode.real);
    expect(g.noPosition, isTrue);
    expect(g.showUser, isFalse);
    expect(g.origin, g.content.gate.position);
  });

  test(
      'two good fixes inside Gua Jepang trigger it (real engine), detail makes it visited',
      () {
    final g = guide()..startSession();
    final p05 = g.place('P05')!;
    walk(lerp(g.content.gate.position, p05.position, 0.6));
    walk(p05.position);
    expect(g.pendingTrigger, isNull,
        reason: 'one fix is not enough (debounce)');
    walk(p05.position);
    expect(g.pendingTrigger?.id, 'P05');
    expect(g.visited, isEmpty);
    g.resolveTrigger(engaged: true);
    expect(g.visited, contains('P05'));
  });

  test('weak fixes move the dot but never trigger', () {
    final g = guide();
    final p05 = g.place('P05')!;
    for (var i = 0; i < 4; i++) {
      walk(p05.position, acc: 45);
    }
    expect(g.showUser, isTrue);
    expect(g.gpsWeak, isTrue);
    expect(g.pendingTrigger, isNull);
  });

  test('walked distance counts good steps and skips GPS jumps', () {
    final g = guide();
    final a = g.content.gate.position;
    final b = g.place('P05')!.position;
    walk(a);
    g.startSession();
    expect(gps.sessions, 1);
    for (var i = 1; i <= 10; i++) {
      walk(lerp(a, b, i / 10 * 0.5), s: 10); // ~13 m per 10 s
    }
    final walked = g.walkedM;
    expect(walked, closeTo(haversineM(a, lerp(a, b, 0.5)), 5));
    walk(const GeoPoint(-6.80, 107.60)); // 7 km in 3 s: a glitch
    expect(g.walkedM, walked);
  });

  test('outside the park: chip state, distances from the gate', () {
    final g = guide();
    walk(const GeoPoint(-6.8915, 107.6107)); // ITB
    expect(g.outsideZone, isTrue);
    expect(g.origin, g.content.gate.position);
    expect(g.distanceToGateM, greaterThan(3000));
  });

  test(
      'navigation: progress follows the fix, leaving the route reroutes, arrival ends it',
      () {
    final g = guide();
    final gate = g.content.gate.position;
    walk(gate);
    expect(g.startNavigation(g.place('P06')!), isTrue);
    final line = g.navigation!.route.polyline;
    walk(line[line.length ~/ 3]);
    expect(g.navProgressM, greaterThan(0));
    // 80 m off the trail for two readings
    final off = GeoPoint(
        line[line.length ~/ 3].lat + 0.0007, line[line.length ~/ 3].lng);
    walk(off);
    walk(off);
    expect(g.reroutes, 1);
    walk(g.place('P06')!.position);
    expect(g.arrivedAt?.id, 'P06');
  });

  test('switching to demo is remembered and resets the session', () {
    final g = guide()..startSession();
    g.setMode(AppMode.demo);
    expect(store.getString('app_mode'), 'demo');
    expect(g.sessionActive, isFalse);
    expect(g.showUser, isTrue);
    expect(g.origin, g.content.gate.position);
  });

  test(
      'demo walk also goes through the engine: walking to Gua Jepang triggers it',
      () async {
    final g = guide()..setMode(AppMode.demo);
    g.teleportTo(g.place('P05')!);
    g.teleportTo(g.place('P05')!);
    expect(g.pendingTrigger?.id, 'P05');
    expect(g.stateOf(g.place('P05')!), PoiState.triggered);
  });
}
