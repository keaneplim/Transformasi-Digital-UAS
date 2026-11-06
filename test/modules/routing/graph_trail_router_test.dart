import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/routing/routing.dart';

import '../../helpers/test_content.dart';

// Fixture graphs in metres east/north of an origin near Dago Pakar. Speed 50 m/min, +1 min per
// 10 m ascent (D09, the park.json defaults).
const origin = GeoPoint(-6.858, 107.633);
const k = earthRadiusM * math.pi / 180;

GeoPoint at(double east, double north) => GeoPoint(
      origin.lat + north / k,
      origin.lng + east / (k * math.cos(origin.lat * math.pi / 180)),
    );

class Fixture {
  final nodes = <GraphNode>[];
  final edges = <GraphEdge>[];

  void node(String id, double east, double north, {String? ref}) => nodes.add(
      GraphNode(id: id, position: at(east, north), elevationM: 0, ref: ref));

  /// Edge along the given way points (metres), length from the geometry.
  void edge(String from, String to,
      {double ascent = 0,
      double descent = 0,
      List<(double, double)> via = const []}) {
    final pos = {for (final n in nodes) n.id: n.position};
    final geom = [pos[from]!, for (final (e, n) in via) at(e, n), pos[to]!];
    var length = 0.0;
    for (var i = 1; i < geom.length; i++) {
      length += haversineM(geom[i - 1], geom[i]);
    }
    edges.add(GraphEdge(
      from: from,
      to: to,
      lengthM: length,
      ascentM: ascent,
      descentM: descent,
      geometry: geom,
    ));
  }

  GraphTrailRouter router({Map<String, String> names = const {}}) =>
      GraphTrailRouter(
        TrailGraph(nodes: nodes, edges: edges),
        walkSpeedMPerMin: 50,
        ascentMinPer10m: 1,
        nodeNames: names,
      );
}

/// A ─100 m north─ J; from J: L 100 m west (climbs 20 m), R 100 m east (drops 20 m),
/// S 100 m north (flat), and a bend B → C (degree-2) further north of S.
Fixture crossroads() => Fixture()
  ..node('A', 0, 0)
  ..node('J', 0, 100)
  ..node('L', -100, 100)
  ..node('R', 100, 100)
  ..node('S', 0, 200)
  ..node('C', 100, 300, ref: 'P99')
  ..edge('A', 'J')
  ..edge('J', 'L', ascent: 20)
  ..edge('J', 'R', descent: 20)
  ..edge('J', 'S')
  ..edge('S', 'C', via: [(0, 300)]);

void main() {
  group('path choice and ETA', () {
    test('route follows the trail: expected node list (F06 AC1)', () {
      final r = crossroads().router().route(at(0, 0), 'C')!;
      expect(r.nodeIds, ['A', 'J', 'S', 'C']);
      expect(r.distanceM, closeTo(100 + 100 + 100 + 100, 0.5));
      expect(r.polyline.first, at(0, 0));
      expect(r.polyline.last.lat, closeTo(at(100, 300).lat, 1e-9));
    });

    test('cost is time: a flat detour beats a shorter path over a hill', () {
      // P → Q direct over hill H: 2 × 250 m, up 60 m then down: 10 + 6 = 16 min.
      // Around via M: 2 × 390.5 m flat = 15.6 min. Length-only routing would take the hill.
      final f = Fixture()
        ..node('P', 0, 0)
        ..node('H', 0, 250)
        ..node('Q', 0, 500)
        ..node('M', 300, 250)
        ..edge('P', 'H', ascent: 60)
        ..edge('H', 'Q', descent: 60)
        ..edge('P', 'M')
        ..edge('M', 'Q');
      final r = f.router().route(at(0, 0), 'Q')!;
      expect(r.nodeIds, ['P', 'M', 'Q']);
      expect(r.eta.inSeconds, closeTo(781 / 50 * 60, 2));
    });

    test('D09: 500 m with 20 m ascent = 12 min uphill, 10 min downhill', () {
      final f = Fixture()
        ..node('Low', 0, 0)
        ..node('High', 0, 500)
        ..edge('Low', 'High', ascent: 20);
      final router = f.router();
      expect(router.walkingTimeBetween('Low', 'High').inSeconds,
          closeTo(12 * 60, 1));
      expect(router.walkingTimeBetween('High', 'Low').inSeconds,
          closeTo(10 * 60, 1));
    });

    test('walkingTimeBetween agrees with route() from the node position', () {
      final router = crossroads().router();
      final r = router.route(at(0, 0), 'L')!;
      expect(router.walkingTimeBetween('A', 'L'), r.eta);
      expect(router.walkingTime(at(0, 0), 'L'), r.eta);
    });
  });

  group('snapping', () {
    test('10 m off the middle of an edge: off-trail leg + partial edge', () {
      final router = crossroads().router();
      expect(router.walkingDistanceM(at(10, 50), 'J'), closeTo(10 + 50, 0.5));
      expect(router.walkingDistanceM(at(10, 50), 'A'), closeTo(10 + 50, 0.5));
      final r = router.route(at(10, 50), 'S')!;
      expect(r.nodeIds, ['J', 'S']);
      expect(r.polyline.first.lat, closeTo(at(0, 50).lat, 1e-9));
    });

    test('within 3 m of a node: starts at that node', () {
      final r = crossroads().router().route(at(2, 100), 'L')!;
      expect(r.nodeIds, ['J', 'L']);
      expect(r.distanceM, closeTo(2 + 100, 0.5));
    });

    test('off-trail leg costs time without slope', () {
      final router = crossroads().router();
      // 30 m off the trail next to A, then 100 m flat to J: 130 m / 50 = 2.6 min.
      expect(router.walkingTime(at(-30, 0), 'J').inSeconds, closeTo(156, 1));
    });

    test('repeated questions from one position give the same answers', () {
      final router = crossroads().router();
      final a = router.walkingDistanceM(at(10, 50), 'C');
      router.walkingDistanceM(at(-50, 100), 'C'); // another position in between
      expect(router.walkingDistanceM(at(10, 50), 'C'), a);
    });
  });

  group('turn instructions', () {
    String text(GraphTrailRouter r, String to) =>
        r.route(at(0, 0), to)!.turns.first.text;

    test('left / right / straight at a crossroads, with slope', () {
      final router = crossroads().router();
      expect(router.route(at(0, 0), 'L')!.turns.first.direction,
          TurnDirection.left);
      expect(text(router, 'L'), 'Di perempatan, ambil jalur kiri menanjak.');
      expect(router.route(at(0, 0), 'R')!.turns.first.direction,
          TurnDirection.right);
      expect(text(router, 'R'), 'Di perempatan, ambil jalur kanan menurun.');
      expect(router.route(at(0, 0), 'S')!.turns.first.direction,
          TurnDirection.straight);
      expect(text(router, 'S'), 'Di perempatan, lurus terus.');
    });

    test('a bend in one trail gives no instruction; last one is arrival', () {
      final r =
          crossroads().router(names: {'C': 'Gua Contoh'}).route(at(0, 0), 'C')!;
      expect(r.turns.map((t) => t.nodeId), ['J', 'C']); // S is degree 2
      expect(r.turns.last.direction, TurnDirection.arrive);
      expect(r.turns.last.text, 'Anda tiba di Gua Contoh.');
    });

    test('distances along the route increase and end at the total', () {
      final r = crossroads().router().route(at(0, 0), 'C')!;
      expect(r.turns.first.distanceFromStartM, closeTo(100, 0.5));
      expect(r.turns.last.distanceFromStartM, closeTo(r.distanceM, 0.5));
    });

    test('pertigaan at a three-way junction', () {
      final f = Fixture()
        ..node('A', 0, 0)
        ..node('J', 0, 100)
        ..node('L', -100, 100)
        ..node('S', 0, 200)
        ..edge('A', 'J')
        ..edge('J', 'L')
        ..edge('J', 'S');
      expect(f.router().route(at(0, 0), 'L')!.turns.first.text,
          'Di pertigaan, ambil jalur kiri.');
    });

    test('already at the destination: only the arrival', () {
      final r = crossroads().router().route(at(1, 100), 'J')!;
      expect(r.nodeIds, ['J']);
      expect(r.turns.single.direction, TurnDirection.arrive);
    });
  });

  group('errors', () {
    test('unknown node: route is null, the others throw ArgumentError', () {
      final router = crossroads().router();
      expect(router.route(at(0, 0), 'NOPE'), isNull);
      expect(
          () => router.walkingDistanceM(at(0, 0), 'NOPE'), throwsArgumentError);
      expect(() => router.walkingTimeBetween('A', 'NOPE'), throwsArgumentError);
    });

    test('unreachable node: route is null, the others throw StateError', () {
      final f = crossroads()
        ..node('Y', 2000, 2000)
        ..node('Z', 2100, 2000)
        ..edge('Y', 'Z');
      final router = f.router();
      expect(router.route(at(0, 0), 'Z'), isNull);
      expect(() => router.walkingDistanceM(at(0, 0), 'Z'),
          throwsA(isA<StateError>()));
      expect(() => router.walkingTimeBetween('A', 'Z'),
          throwsA(isA<StateError>()));
    });
  });

  group('real content (dummy now, survey graph later)', () {
    final content = loadTestContent();
    final router = GraphTrailRouter.fromContent(content);
    final gate = content.gate;
    final targets = <(String, GeoPoint, String)>[
      for (final p in content.pois) (p.id, p.position, p.graphNode),
      for (final f in content.facilities) (f.id, f.position, f.graphNode),
    ];

    test('every POI and facility is reachable from the gate along the trails',
        () {
      for (final (id, pos, node) in targets) {
        final r = router.route(gate.position, node);
        expect(r, isNotNull, reason: id);
        expect(r!.distanceM,
            greaterThanOrEqualTo(haversineM(gate.position, pos) * 0.99),
            reason: '$id: a route is never shorter than the straight line');
        final end = content.graph.nodes[node]!.position;
        expect(haversineM(r.polyline.last, end), lessThan(0.5), reason: id);
        expect(r.turns.last.direction, TurnDirection.arrive, reason: id);
      }
    });

    test('node-to-node time matches route time from the gate node', () {
      for (final (id, _, node) in targets) {
        expect(router.walkingTimeBetween(gate.graphNode, node),
            router.route(gate.position, node)!.eta,
            reason: id);
      }
    });
  });
}
