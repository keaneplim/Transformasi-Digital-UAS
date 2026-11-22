import 'package:jelajah_taman/modules/content/content.dart';

/// Why a candidate is recommended (UI08 reason chips). Copy lives in shell.
enum RecReason {
  /// Shortest walk of all candidates.
  nearest,

  /// Category is one of the visitor's interests.
  interest,

  /// On the active Wellness Trail route.
  onRoute,

  /// Not harder than the active route.
  difficulty,
}

/// One POI that passed the filter, with its walking distance from the visitor.
class RecCandidate {
  const RecCandidate(this.poi, this.walkM);

  final Poi poi;
  final double walkM;
}

/// What the factors may look at: the visitor's choices and the candidate set.
class ScoreContext {
  const ScoreContext({
    required this.interests,
    required this.route,
    required this.maxWalkM,
  });

  final Set<String> interests;
  final TrailRoute? route;

  /// Longest walk over the candidates (not over all POIs), for the distance factor.
  final double maxWalkM;
}

/// One term of the score (ARCHITECTURE §6 extension point). [key] names its weight in
/// `park.json` `rec_weights`; a value of 1 adds [reason] to the chips.
abstract interface class ScoreFactor {
  String get key;
  RecReason? get reason;

  /// 0..1.
  double value(RecCandidate c, ScoreContext ctx);
}

/// dist = 1 − walk / longest candidate walk (the farthest scores 0).
class DistanceFactor implements ScoreFactor {
  const DistanceFactor();
  @override
  String get key => 'dist';
  @override
  RecReason? get reason =>
      null; // "Terdekat" is the shortest walk, see Recommender
  @override
  double value(RecCandidate c, ScoreContext ctx) =>
      ctx.maxWalkM <= 0 ? 1 : (1 - c.walkM / ctx.maxWalkM).clamp(0.0, 1.0);
}

class InterestFactor implements ScoreFactor {
  const InterestFactor();
  @override
  String get key => 'interest';
  @override
  RecReason get reason => RecReason.interest;
  @override
  double value(RecCandidate c, ScoreContext ctx) =>
      ctx.interests.contains(c.poi.category) ? 1 : 0;
}

/// 1 when the POI is in the active route's `poi_sequence`.
class RouteFactor implements ScoreFactor {
  const RouteFactor();
  @override
  String get key => 'route';
  @override
  RecReason get reason => RecReason.onRoute;
  @override
  double value(RecCandidate c, ScoreContext ctx) {
    final r = ctx.route;
    return r != null && r.poiSequence.contains(c.poi.id) ? 1 : 0;
  }
}

/// 1 when the POI is not harder than the active route (or there is no route).
class DifficultyFactor implements ScoreFactor {
  const DifficultyFactor();
  @override
  String get key => 'difficulty';
  @override
  RecReason get reason => RecReason.difficulty;
  @override
  double value(RecCandidate c, ScoreContext ctx) {
    final r = ctx.route;
    return r == null || c.poi.difficulty <= r.difficulty ? 1 : 0;
  }
}

class RecItem {
  const RecItem({
    required this.poi,
    required this.walkM,
    required this.score,
    required this.reasons,
  });

  final Poi poi;
  final double walkM;
  final double score;
  final List<RecReason> reasons;
}

/// 1 main + up to 2 alternatives, or back to the gate.
class RecResult {
  const RecResult(this.items) : allVisited = false;
  const RecResult.backToGate({this.allVisited = false}) : items = const [];

  final List<RecItem> items;

  /// Back to the gate because nothing is left (UC-F07-3), not because time ran out (UC-F07-2).
  final bool allVisited;
  bool get backToGate => items.isEmpty;
}

/// F07 (IMPLEMENTATION_PLAN "Algorithm", D10). Pure: walking distance and the closing-time
/// fit are passed in, so it is tested without a graph or a clock.
class Recommender {
  Recommender({
    Map<String, double> weights = defaultWeights,
    this.factors = defaultFactors,
  }) : _weights = {...defaultWeights, ...weights};

  /// D10: 0.50·dist + 0.25·interest + 0.15·route + 0.10·difficulty.
  static const defaultWeights = {
    'dist': 0.5,
    'interest': 0.25,
    'route': 0.15,
    'difficulty': 0.1,
  };

  static const defaultFactors = <ScoreFactor>[
    DistanceFactor(),
    InterestFactor(),
    RouteFactor(),
    DifficultyFactor(),
  ];

  final Map<String, double> _weights;
  final List<ScoreFactor> factors;

  /// A POI that only the Trekking route has (P11 Curug Omas) is a candidate only on Trekking,
  /// the same rule as its geofence (`buildGeofenceTargets`).
  static bool offRoute(Poi p, TrailRoute? route) =>
      p.routes.length == 1 &&
      p.routes.first == 'trekking' &&
      route?.id != 'trekking';

  RecResult recommend({
    required Iterable<Poi> pois,
    required Set<String> visited,
    required String gateId,
    required Set<String> interests,
    required TrailRoute? route,
    required double Function(Poi p) walkM,
    required bool Function(Poi p) fits,
    int count = 3,
  }) {
    // D05: only visited POIs drop out; "Nanti" (triggered) stays a candidate.
    final open = [
      for (final p in pois)
        if (p.id != gateId && !visited.contains(p.id) && !offRoute(p, route)) p
    ];
    if (open.isEmpty) return const RecResult.backToGate(allVisited: true);
    final candidates = [
      for (final p in open)
        if (fits(p)) RecCandidate(p, walkM(p))
    ];
    if (candidates.isEmpty) return const RecResult.backToGate();

    var maxW = 0.0;
    var minW = double.infinity;
    for (final c in candidates) {
      if (c.walkM > maxW) maxW = c.walkM;
      if (c.walkM < minW) minW = c.walkM;
    }
    final ctx =
        ScoreContext(interests: interests, route: route, maxWalkM: maxW);
    final scored = <RecItem>[];
    for (final c in candidates) {
      var score = 0.0;
      final reasons = <RecReason>[if (c.walkM == minW) RecReason.nearest];
      for (final f in factors) {
        final v = f.value(c, ctx);
        score += (_weights[f.key] ?? 0) * v;
        final r = f.reason;
        if (r != null && v >= 1) reasons.add(r);
      }
      scored.add(
          RecItem(poi: c.poi, walkM: c.walkM, score: score, reasons: reasons));
    }
    scored.sort((a, b) {
      // Equal within float noise (0.15 + 0.10 vs 0.25) counts as a tie.
      if ((a.score - b.score).abs() > 1e-9) return b.score.compareTo(a.score);
      final w = a.walkM.compareTo(b.walkM); // tie → shorter walk
      return w != 0 ? w : a.poi.id.compareTo(b.poi.id);
    });
    return RecResult(scored.take(count).toList(growable: false));
  }
}
