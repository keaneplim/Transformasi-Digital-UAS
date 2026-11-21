import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/modules/location/location.dart';
import 'package:jelajah_taman/modules/session/session.dart';
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

  /// The app is killed and opened again: a fresh controller on the same device storage.
  GuideController relaunch() {
    c.dispose(); // the killed app stops listening to the GPS
    c = ProviderContainer(overrides: [
      ...buildOverrides(
          content: loadTestContent(), clock: clock, basemap: loadTestBasemap()),
      locationServiceProvider.overrideWithValue(gps),
      keyValueStoreProvider.overrideWithValue(store),
    ]);
    return c.read(guideProvider);
  }

  /// Two good fixes on [p]: enough for a trigger (debounce 2). The first one comes [s]
  /// seconds later; ≥ 30 s keeps clear of the D01 spacing after a previous trigger.
  void standAt(GeoPoint p, {int s = 31}) {
    walk(p, s: s);
    walk(p);
  }

  test('PB06: a POI visited in one session triggers again in the next session',
      () async {
    final g = guide()..startSession();
    final p05 = g.place('P05')!;
    standAt(p05.position);
    expect(g.pendingTrigger?.id, 'P05');
    g.resolveTrigger(engaged: true);
    g.endSession();
    await pumpEventQueue();

    g.startSession();
    expect(g.stateOf(p05), PoiState.outside);
    standAt(p05.position);
    expect(g.pendingTrigger?.id, 'P05',
        reason: 'the engine must start each session fresh');
  });

  test(
      'PB06: the visit log records triggers and visits apart, with their source',
      () {
    final g = guide()..startSession();
    standAt(g.place('P05')!.position);
    g.resolveTrigger(engaged: false); // "Nanti"
    standAt(g.place('P06')!.position);
    g.resolveTrigger(engaged: true); // "Lihat"
    g.triggerNow(g.place('P07')!, viaQr: true);
    expect(g.visitLog.map((e) => (e.poiId, e.kind, e.how)), [
      ('P05', VisitKind.triggered, 'gps'),
      ('P06', VisitKind.triggered, 'gps'),
      ('P06', VisitKind.visited, 'opened'),
      ('P07', VisitKind.triggered, 'qr'),
      ('P07', VisitKind.visited, 'qr'),
    ]);
    expect(SessionStore(store).loadCurrent()?.events, hasLength(5),
        reason: 'every log entry is saved at once');
  });

  test('PB06: after the app is killed, the session continues where it was',
      () async {
    final g = guide();
    final gate = g.content.gate.position;
    final p05 = g.place('P05')!;
    walk(gate);
    g.startSession();
    // walk to Gua Jepang in ten steps, slow enough to count as walking (< 3.5 m/s)
    for (var i = 1; i <= 10; i++) {
      walk(lerp(gate, p05.position, i / 10), s: 120);
    }
    walk(p05.position);
    expect(g.pendingTrigger?.id, 'P05');
    g.resolveTrigger(engaged: true);
    final walked = g.walkedM;
    expect(walked, greaterThan(0));
    await pumpEventQueue();

    final again = relaunch();
    expect(again.sessionActive, isTrue);
    expect(again.onboarded, isTrue, reason: 'opens on Home, not onboarding');
    expect(again.sessionStart, g.sessionStart);
    expect(again.visited, {'P05'});
    expect(again.walkedM, closeTo(walked, 0.1));
    expect(again.visitLog, hasLength(2));
    await pumpEventQueue();
    expect(gps.sessions, greaterThanOrEqualTo(2),
        reason: 'background tracking restarts for the restored session');

    standAt(p05.position);
    expect(again.pendingTrigger, isNull,
        reason: 'still visited in this session: no second trigger');
  });

  group('T23 closing time', () {
    DateTime today(int h, int m) => DateTime(2026, 11, 14, h, m);

    test(
        'TC-10 at P06: reminder at 16.00 − walk to gate − 15 min, back to gate at 15.30',
        () {
      final g = guide();
      final p06 = g.place('P06')!.position;
      walk(p06);
      g
        ..hydrationMin = 0 // only the closing reminder in this test
        ..startSession();
      final walkToGate = g.router.walkingTime(p06, g.content.gate.graphNode);
      final threshold = today(16, 0)
          .subtract(walkToGate)
          .subtract(const Duration(minutes: 15));
      expect(g.closingReminderAt, threshold);

      clock.setNow(threshold.subtract(const Duration(minutes: 1)));
      gps.push(p06, clock.now());
      expect(g.reminder, isNull, reason: 'a minute early');
      clock.setNow(threshold);
      gps.push(p06, clock.now());
      expect(g.reminder, GuideReminder.closing);

      clock.setNow(today(15, 30));
      expect(g.recommend().backToGate, isTrue,
          reason: 'nothing can be visited and walked back by 15.45');
    });

    test('a restored session does not show the closing reminder again',
        () async {
      final g = guide();
      final gate = g.content.gate.position;
      walk(gate);
      g.startSession();
      clock.setNow(today(15, 50)); // past the threshold anywhere in the park
      walk(gate);
      expect(g.reminder, GuideReminder.closing);
      g.dismissReminder();
      await pumpEventQueue();

      final again = relaunch()..hydrationMin = 0; // only the closing reminder
      expect(again.sessionActive, isTrue);
      walk(gate);
      walk(gate);
      expect(again.reminder, isNull, reason: 'already shown in this session');
    });

    test('Home and the route chooser use one rule: done by closing − 15 min',
        () {
      final g = guide();
      final santai = g.content.routes.firstWhere((r) => r.id == 'santai');
      final latest =
          today(15, 45).subtract(Duration(minutes: santai.durationMin));
      clock.setNow(latest);
      expect(g.routeFits(santai), isTrue);
      clock.setNow(latest.add(const Duration(minutes: 1)));
      expect(g.routeFits(santai), isFalse,
          reason: 'ends before 16.00 but inside the 15 min buffer');
    });
  });

  test('PB06: an ended session is not resumed but kept as the last session',
      () async {
    final g = guide()..startSession();
    standAt(g.place('P05')!.position);
    g
      ..resolveTrigger(engaged: true)
      ..endSession();
    await pumpEventQueue();

    final again = relaunch();
    expect(again.sessionActive, isFalse);
    expect(SessionStore(store).loadLast()?.visitedIds, {'P05'});
  });

  test('PB06: a session from yesterday is archived instead of resumed',
      () async {
    guide().startSession();
    await pumpEventQueue();
    clock.advance(const Duration(days: 1));

    final again = relaunch();
    expect(again.sessionActive, isFalse);
    await pumpEventQueue();
    expect(SessionStore(store).loadCurrent(), isNull);
    expect(SessionStore(store).loadLast()?.isEnded, isTrue);
  });

  test('D06: arrival marks the POI visited (nav) without logging a trigger',
      () {
    final g = guide()..startSession();
    g.markVisited(g.place('P06')!);
    expect(g.visited, contains('P06'));
    expect(g.visitLog.map((e) => (e.poiId, e.kind, e.how)), [
      ('P06', VisitKind.visited, 'nav'),
    ]);
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

  test(
      '#31: before a session, good fixes at a POI move the dot but never trigger',
      () {
    final g = guide();
    final p05 = g.place('P05')!;
    for (var i = 0; i < 4; i++) {
      walk(p05.position);
    }
    expect(g.showUser, isTrue);
    expect(g.pendingTrigger, isNull);
    expect(g.triggered, isEmpty);
    g.startSession();
    walk(p05.position);
    walk(p05.position);
    expect(g.pendingTrigger?.id, 'P05', reason: 'in a session it does');
  });

  group('D08 GPS-weak banner', () {
    test('no fixes at all for 60 s (cave) → banner; a good fix hides it',
        () async {
      final g = guide();
      await pumpEventQueue(); // access() resolves
      g.startSession();
      final p05 = g.place('P05')!;
      walk(p05.position); // last good fix at the cave mouth, then silence
      for (var i = 0; i < 11; i++) {
        clock.advance(const Duration(seconds: 5));
        g.heartbeat();
      }
      expect(g.gpsWeakBanner, isFalse, reason: '55 s: not yet');
      clock.advance(const Duration(seconds: 5));
      g.heartbeat();
      expect(g.gpsWeakBanner, isTrue);
      walk(p05.position);
      expect(g.gpsWeakBanner, isFalse);
    });

    test('never a fix since the session started → banner after 60 s', () async {
      final g = guide();
      await pumpEventQueue();
      g.startSession();
      g.heartbeat();
      clock.advance(const Duration(seconds: 60));
      g.heartbeat();
      expect(g.gpsWeakBanner, isTrue);
    });

    test('not outside a session, not without permission', () async {
      gps.granted = LocationAccess.denied;
      final g = guide();
      await pumpEventQueue();
      g.startSession();
      g.heartbeat();
      clock.advance(const Duration(seconds: 90));
      g.heartbeat();
      expect(g.gpsWeakBanner, isFalse,
          reason: 'denied has its own card (Aktifkan lokasi / Pilih manual)');
      g.endSession();
      expect(g.gpsWeakBanner, isFalse);
    });
  });

  group('UC-A02-3 Pilih manual', () {
    test('logs a manual trigger + opened visit, starts a session, no card', () {
      final g = guide();
      final p05 = g.place('P05')!;
      g.manualPick(p05);
      expect(g.sessionActive, isTrue);
      expect(g.pendingTrigger, isNull, reason: 'Detail opens directly');
      expect(g.visited, contains('P05'));
      expect(g.visitLog.map((e) => (e.poiId, e.kind, e.how)), [
        ('P05', VisitKind.triggered, 'manual'),
        ('P05', VisitKind.visited, 'opened'),
      ]);
    });

    test('list: A–Z without a position, nearest first with one, never the gate',
        () {
      final g = guide();
      final az = g.manualPickList.map((p) => p.name).toList();
      expect(az, [...az]..sort());
      expect(g.manualPickList.any((p) => p.isGate), isFalse);
      final p06 = g.place('P06')!;
      walk(p06.position);
      expect(g.manualPickList.first.id, 'P06');
      expect(g.manualPickList.any((p) => p.isGate), isFalse);
    });
  });
}
