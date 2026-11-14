import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/location/location.dart';
import 'package:jelajah_taman/modules/trigger/trigger.dart';

import '../../helpers/test_content.dart';

const _origin = GeoPoint(-6.85, 107.63);
const _mPerDegLat = 111195.0;
final _mPerDegLng = 111195.0 * math.cos(_origin.lat * math.pi / 180);

/// A point [eastM] metres east and [northM] north of the origin.
GeoPoint at(double eastM, [double northM = 0]) => GeoPoint(
    _origin.lat + northM / _mPerDegLat, _origin.lng + eastM / _mPerDegLng);

/// POI A at the origin (r 20), POI B 50 m east (r 30).
GeofenceEngine engine({List<GeofenceTarget>? targets}) => GeofenceEngine(
      targets: targets ??
          [
            GeofenceTarget(id: 'A', position: _origin, radiusM: 20),
            GeofenceTarget(id: 'B', position: at(50), radiusM: 30),
          ],
    );

class Walk {
  Walk(this.e);
  final GeofenceEngine e;
  DateTime t = DateTime(2026, 11, 14, 10);
  final events = <DomainEvent>[];

  /// One fix [dt] after the previous one (default 3 s), at [eastM] west/east of A.
  List<DomainEvent> fix(double eastM,
      {double northM = 0,
      double acc = 8,
      Duration dt = const Duration(seconds: 3)}) {
    t = t.add(dt);
    final out = e.onFix(
        LocationFix(position: at(eastM, northM), accuracyM: acc, at: t), t);
    events.addAll(out);
    return out;
  }

  Iterable<T> of<T extends DomainEvent>() => events.whereType<T>();
}

void main() {
  test('1. walk-in → exactly one Approaching, then one Triggered', () {
    final w = Walk(engine(
        targets: [GeofenceTarget(id: 'A', position: _origin, radiusM: 20)]));
    for (final x in [-120.0, -80, -45, -35, -25, -15, -10, -5, 0]) {
      w.fix(x.toDouble());
    }
    expect(w.of<PoiApproached>().map((e) => e.poiId), ['A']);
    expect(w.of<PoiTriggered>().map((e) => e.poiId), ['A']);
    expect(w.e.stateOf('A'), PoiState.triggered);
  });

  test('2. single fix inside r then outside → no trigger (debounce)', () {
    final w = Walk(engine());
    w
      ..fix(-60)
      ..fix(-10)
      ..fix(-30)
      ..fix(-60);
    expect(w.of<PoiTriggered>(), isEmpty);
  });

  test('3. 3 min of jitter inside r → one trigger only (TC-03)', () {
    final w = Walk(engine());
    final rnd = math.Random(3);
    for (var i = 0; i < 60; i++) {
      w.fix(-12 + rnd.nextDouble() * 10, northM: rnd.nextDouble() * 10 - 5);
    }
    expect(w.of<PoiTriggered>().where((e) => e.poiId == 'A'), hasLength(1));
  });

  test(
      '4. exit > r+15 and back at minute 5 → no trigger; at minute 11 → trigger (D04)',
      () {
    final w = Walk(engine(
        targets: [GeofenceTarget(id: 'A', position: _origin, radiusM: 20)]));
    w
      ..fix(-5)
      ..fix(-5);
    expect(w.of<PoiTriggered>(), hasLength(1));
    w.fix(-60); // left > r+15
    expect(w.e.stateOf('A'), PoiState.cooldown);
    w
      ..fix(-5, dt: const Duration(minutes: 5))
      ..fix(-5)
      ..fix(-5);
    expect(w.of<PoiTriggered>(), hasLength(1));
    w
      ..fix(-60,
          dt: const Duration(minutes: 6)) // minute 11, outside again → eligible
      ..fix(-5)
      ..fix(-5);
    expect(w.of<PoiTriggered>(), hasLength(2));
  });

  test('5. overlapping POIs, A visited → B triggers (D01, issue #8)', () {
    final w = Walk(engine());
    w
      ..fix(10)
      ..fix(10); // inside A (r20) and B (r30, 40 m away → no)
    expect(w.of<PoiTriggered>().single.poiId, 'A');
    w.e.onEngaged('A', EngagementKind.opened, w.t);
    expect(w.e.isVisited('A'), isTrue);
    // stand where both radii overlap: 18 m from A, 32 m … move to 25 m east (A 25 > 20, B 25 ≤ 30)
    w
      ..fix(25, dt: const Duration(seconds: 31))
      ..fix(25);
    expect(w.of<PoiTriggered>().map((e) => e.poiId), ['A', 'B']);
  });

  test('5b. two candidates at once → nearest first, the other ≥ 30 s later',
      () {
    final w = Walk(engine(targets: [
      GeofenceTarget(id: 'A', position: _origin, radiusM: 30),
      GeofenceTarget(id: 'B', position: at(20), radiusM: 30),
    ]));
    w
      ..fix(5)
      ..fix(5);
    expect(w.of<PoiTriggered>().map((e) => e.poiId), ['A']);
    w.fix(5); // B still a candidate, but < 30 s
    expect(w.of<PoiTriggered>(), hasLength(1));
    w.fix(5, dt: const Duration(seconds: 30));
    expect(w.of<PoiTriggered>().map((e) => e.poiId), ['A', 'B']);
  });

  test(
      '6. visited POI walk-by → no approaching buzz, no trigger (D02, issue #9)',
      () {
    final w = Walk(engine(
        targets: [GeofenceTarget(id: 'A', position: _origin, radiusM: 20)]));
    w.e.qr('A', w.t);
    w.events.clear();
    for (final x in [-100.0, -45, -30, -10, 0, 10, 30, 45, 100]) {
      w.fix(x.toDouble(), dt: const Duration(minutes: 3));
    }
    expect(w.of<PoiApproached>(), isEmpty);
    expect(w.of<PoiTriggered>(), isEmpty);
  });

  test('7. boundary oscillation r+28 ↔ r+35 → one buzz only (D03, issue #4)',
      () {
    final w = Walk(engine(
        targets: [GeofenceTarget(id: 'A', position: _origin, radiusM: 20)]));
    for (var i = 0; i < 20; i++) {
      w.fix(i.isEven ? -48 : -55);
    }
    expect(w.of<PoiApproached>(), hasLength(1));
    w
      ..fix(-70) // > r+40 ends the episode
      ..fix(-45);
    expect(w.of<PoiApproached>(), hasLength(2));
  });

  test(
      '8. weak fixes are ignored; a weak fix between two good inside fixes still triggers',
      () {
    final w = Walk(engine(
        targets: [GeofenceTarget(id: 'A', position: _origin, radiusM: 20)]));
    w
      ..fix(0, acc: 45)
      ..fix(0, acc: 45);
    expect(w.of<PoiTriggered>(), isEmpty);
    w
      ..fix(-5)
      ..fix(200, acc: 60) // weak jump: neither counts nor resets
      ..fix(-5);
    expect(w.of<PoiTriggered>().single.poiId, 'A');
  });

  test('8b. 60 s of weak fixes → GPS-weak banner; a good fix hides it (D08)',
      () {
    final w = Walk(engine());
    for (var i = 0; i < 22; i++) {
      w.fix(-200, acc: 50);
    }
    expect(w.e.weakBanner, isTrue);
    w.fix(-200);
    expect(w.e.weakBanner, isFalse);
  });

  test('9. QR → Triggered(qr) + Visited regardless of GPS', () {
    final e = engine();
    final out = e.qr('B', DateTime(2026, 11, 14, 10));
    expect(
        out.first,
        isA<PoiTriggered>()
            .having((x) => x.source, 'source', TriggerSource.qr));
    expect(out.last, isA<PoiVisited>());
    expect(e.isVisited('B'), isTrue);
  });

  test(
      'disabled target (gate, D07) never approaches or triggers by GPS; manual still works',
      () {
    final w = Walk(engine(targets: [
      GeofenceTarget(id: 'G', position: _origin, radiusM: 30, enabled: false)
    ]));
    for (final x in [-50.0, -20, 0, 0, 0]) {
      w.fix(x.toDouble());
    }
    expect(w.events, isEmpty);
    expect(w.e.manual('G', w.t).single, isA<PoiTriggered>());
  });

  test(
      '"Nanti" on the approach banner ends the episode until the visitor leaves r+40',
      () {
    final w = Walk(engine(
        targets: [GeofenceTarget(id: 'A', position: _origin, radiusM: 20)]));
    w.fix(-40);
    expect(w.e.approaching?.id, 'A');
    w.e.dismissApproach('A');
    w
      ..fix(-38)
      ..fix(-42);
    expect(w.e.approaching, isNull);
    expect(w.of<PoiApproached>(), hasLength(1));
  });

  test('engagement only makes a triggered POI visited (D05)', () {
    final e = engine();
    expect(e.onEngaged('A', EngagementKind.opened, DateTime(2026)), isEmpty);
    e.manual('A', DateTime(2026));
    expect(e.onEngaged('A', EngagementKind.listened, DateTime(2026)).single,
        isA<PoiVisited>());
  });

  test('arrival visit (UI11): Visited(nav) without a trigger event (D06)', () {
    final e = engine();
    final out = e.visitOnArrival('A', DateTime(2026, 11, 14, 10));
    expect(out.single,
        isA<PoiVisited>().having((x) => x.how, 'how', EngagementKind.nav));
    expect(e.isVisited('A'), isTrue);
    expect(e.visitOnArrival('A', DateTime(2026, 11, 14, 10, 1)), isEmpty,
        reason: 'already visited: nothing new to log');
  });

  test('reset: a POI visited in one session can trigger in the next', () {
    final w = Walk(engine(
        targets: [GeofenceTarget(id: 'A', position: _origin, radiusM: 20)]));
    w
      ..fix(0)
      ..fix(0);
    w.e.onEngaged('A', EngagementKind.opened, w.t);
    expect(w.e.isVisited('A'), isTrue);
    w.e.reset();
    w.events.clear();
    w
      ..fix(0)
      ..fix(0);
    expect(w.of<PoiTriggered>(), hasLength(1));
  });

  test(
      'snapshot → restore keeps visited, and a triggered POI keeps its cooldown',
      () {
    final w = Walk(engine());
    // A: triggered + engaged → visited. B: triggered, "Nanti" → stays triggered.
    w
      ..fix(0)
      ..fix(0);
    w.e.onEngaged('A', EngagementKind.opened, w.t);
    w
      ..fix(50, dt: const Duration(seconds: 31))
      ..fix(50);
    expect(w.e.stateOf('B'), PoiState.triggered);

    final restored = engine()..restore(w.e.toJson());
    expect(restored.stateOf('A'), PoiState.visited);
    expect(restored.stateOf('B'), PoiState.triggered);
    final again = Walk(restored)..t = w.t;
    // Walk away and back within the 10 min cooldown: B must not trigger again.
    again
      ..fix(150)
      ..fix(50, dt: const Duration(minutes: 2))
      ..fix(50);
    expect(again.of<PoiTriggered>(), isEmpty);
    // A stays quiet too (visited for the session).
    again
      ..fix(0)
      ..fix(0);
    expect(again.of<PoiTriggered>(), isEmpty);
  });

  test('restore ignores unknown states and junk instead of throwing', () {
    final e = engine()
      ..restore({
        'pois': {
          'A': {'state': 'exploded'},
          'B': 'not a map',
        },
      });
    expect(e.stateOf('A'), PoiState.outside);
    expect(e.stateOf('B'), PoiState.outside);
  });

  test('targets from real content: gate disabled, Curug Omas only on Trekking',
      () {
    final content = loadTestContent();
    final santai = buildGeofenceTargets(content, activeRouteId: 'santai');
    final trek = buildGeofenceTargets(content, activeRouteId: 'trekking');
    bool on(List<GeofenceTarget> ts, String id) =>
        ts.firstWhere((t) => t.id == id).enabled;
    expect(on(santai, content.park.gatePoiId), isFalse);
    expect(on(santai, 'P11'), isFalse);
    expect(on(trek, 'P11'), isTrue);
    expect(on(santai, 'P05'), isTrue);
  });
}
