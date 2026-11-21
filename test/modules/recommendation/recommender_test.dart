import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/recommendation/recommendation.dart';

import '../../helpers/test_content.dart';

Poi poi(String id,
        {String category = 'alam',
        int difficulty = 1,
        List<String> routes = const ['santai', 'sedang', 'trekking']}) =>
    Poi(
      id: id,
      name: id,
      category: category,
      position: const GeoPoint(0, 0),
      isDummyCoordinate: false,
      radiusM: 25,
      triggers: const ['gps'],
      qrCode: null,
      visitMinutes: 10,
      difficulty: difficulty,
      graphNode: 'N_$id',
      keywords: const [],
      text: '',
      keyFacts: const [],
      images: const [],
      audio: null,
      audioSeconds: null,
      routes: routes,
      safetyNote: null,
      sources: const [],
    );

TrailRoute route(String id, int difficulty, List<String> seq) => TrailRoute(
      id: id,
      name: id,
      difficulty: difficulty,
      distanceM: 1000,
      ascentM: 0,
      durationMin: 60,
      poiSequence: seq,
      nodePath: const [],
    );

void main() {
  final santai = route('santai', 1, ['P01', 'P02', 'P03', 'P01']);
  final sedang = route('sedang', 2, ['P01', 'P02', 'P03', 'P04', 'P01']);
  final trekking = route('trekking', 3, ['P01', 'P11', 'P01']);

  /// Walking distances by id; [fits] = ids that make it back to the gate in time (all by default).
  RecResult run(
    List<Poi> pois,
    Map<String, double> walk, {
    Set<String> visited = const {},
    Set<String> interests = const {},
    TrailRoute? on,
    Set<String>? fits,
    Recommender? r,
  }) =>
      (r ?? Recommender()).recommend(
        pois: pois,
        visited: visited,
        gateId: 'P01',
        interests: interests,
        route: on ?? santai,
        walkM: (p) => walk[p.id]!,
        fits: (p) => fits == null || fits.contains(p.id),
      );

  List<String> ids(RecResult r) => [for (final i in r.items) i.poi.id];

  group('filter (F07, D05, AC1, AC3)', () {
    final pois = [poi('P01'), poi('P02'), poi('P03'), poi('P04')];
    final walk = {'P01': 0.0, 'P02': 100.0, 'P03': 200.0, 'P04': 300.0};

    test('never the gate, never a visited POI; 1 main + 2 alternatives', () {
      final r = run(pois, walk, visited: {'P02'});
      expect(ids(r), ['P03', 'P04']);
      expect(run(pois, walk).items, hasLength(3));
    });

    test('"Nanti" (triggered, not visited) stays a candidate', () {
      // The guide passes only visited ids; a triggered-only POI is simply not in the set.
      expect(ids(run(pois, walk, visited: {'P03', 'P04'})), ['P02']);
    });

    test(
        'not back at the gate by closing − 15 min → left out; none left → gate',
        () {
      expect(ids(run(pois, walk, fits: {'P04'})), ['P04']);
      final none = run(pois, walk, fits: {});
      expect(none.backToGate, isTrue);
      expect(none.allVisited, isFalse, reason: 'UC-F07-2, not UC-F07-3');
    });

    test('everything visited → back to the gate, "all visited"', () {
      final r = run(pois, walk, visited: {'P02', 'P03', 'P04'});
      expect(r.backToGate, isTrue);
      expect(r.allVisited, isTrue);
    });

    test('a Trekking-only POI (P11) only on the Trekking route', () {
      final withP11 = [
        ...pois,
        poi('P11', routes: const ['trekking'])
      ];
      final w = {...walk, 'P11': 10.0}; // the nearest of all
      expect(ids(run(withP11, w)), isNot(contains('P11')));
      expect(ids(run(withP11, w, on: trekking)).first, 'P11');
      // Only P11 left off Trekking: nothing left to recommend.
      expect(
          run(withP11, w, visited: {'P02', 'P03', 'P04'}).allVisited, isTrue);
    });
  });

  group('score (D10)', () {
    test(
        'AC4: changing interests swaps the top recommendation (fixed distances)',
        () {
      final pois = [
        poi('P01'),
        poi('P02', category: 'sejarah'),
        poi('P03', category: 'alam'),
      ];
      final walk = {'P01': 0.0, 'P02': 300.0, 'P03': 330.0};
      expect(ids(run(pois, walk, interests: {'sejarah'})).first, 'P02');
      expect(ids(run(pois, walk, interests: {'alam'})).first, 'P03');
    });

    test('distance is relative to the candidates, not to every unvisited POI',
        () {
      final pois = [poi('P01'), poi('P02'), poi('P03'), poi('P04')];
      final walk = {'P01': 0.0, 'P02': 100.0, 'P03': 200.0, 'P04': 2000.0};
      // P04 is too far for the time left: it must not flatten the others' distance scores.
      final r = run(pois, walk, fits: {'P02', 'P03'});
      expect(r.items.first.score, closeTo(0.5 * 0.5 + 0.15 + 0.1, 1e-9));
      expect(r.items.last.score, closeTo(0 + 0.15 + 0.1, 1e-9));
    });

    test('route factor: in the active route\'s poi_sequence', () {
      final pois = [poi('P01'), poi('P03'), poi('P04')];
      final walk = {'P01': 0.0, 'P03': 300.0, 'P04': 300.0};
      final r = run(pois, walk);
      expect(ids(r).first, 'P03', reason: 'P04 is not on Santai');
      expect(r.items.first.reasons, contains(RecReason.onRoute));
      expect(r.items.last.reasons, isNot(contains(RecReason.onRoute)));
    });

    test('difficulty factor: not harder than the active route', () {
      final pois = [poi('P01'), poi('P02', difficulty: 2), poi('P03')];
      final walk = {'P01': 0.0, 'P02': 300.0, 'P03': 300.0};
      final onSantai = run(pois, walk);
      expect(ids(onSantai).first, 'P03');
      expect(
          onSantai.items.last.reasons, isNot(contains(RecReason.difficulty)));
      final onSedang = run(pois, walk, on: sedang);
      expect(
          onSedang.items.every((i) => i.reasons.contains(RecReason.difficulty)),
          isTrue);
    });

    test('a tie goes to the shorter walk', () {
      final pois = [poi('P01'), poi('P02'), poi('P03')];
      final walk = {'P01': 0.0, 'P02': 400.0, 'P03': 250.0};
      final noDistance = Recommender(weights: const {'dist': 0});
      expect(ids(run(pois, walk, r: noDistance)), ['P03', 'P02']);
    });

    test('reasons: "nearest" only for the shortest walk; factors that are 1',
        () {
      final pois = [
        poi('P01'),
        poi('P02', category: 'sejarah'),
        poi('P03', category: 'alam', difficulty: 3),
      ];
      final walk = {'P01': 0.0, 'P02': 120.0, 'P03': 500.0};
      final r = run(pois, walk, interests: {'sejarah'});
      expect(r.items.first.reasons, [
        RecReason.nearest,
        RecReason.interest,
        RecReason.onRoute,
        RecReason.difficulty,
      ]);
      expect(r.items.last.reasons, [RecReason.onRoute]);
    });

    test('weights come from park.json (D10 values today)', () {
      final w = loadTestContent().park.recWeights;
      expect(w, Recommender.defaultWeights);
    });
  });
}
