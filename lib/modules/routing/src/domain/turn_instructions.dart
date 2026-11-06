import 'package:jelajah_taman/core/core.dart';

import 'trail_router.dart';

/// One walked piece of a route, ending at a graph node.
class RouteStep {
  const RouteStep({
    required this.geometry,
    required this.lengthM,
    required this.ascentM,
    required this.descentM,
    required this.endNodeId,
    required this.endDistanceM,
  });

  /// In walking order; last point = the end node.
  final List<GeoPoint> geometry;
  final double lengthM;

  /// In the walking direction.
  final double ascentM;
  final double descentM;
  final String endNodeId;

  /// Distance from the user's position to the end node along the route.
  final double endDistanceM;
}

/// F06 "Turn instructions": one instruction per junction (degree ≥ 3) on the route, plus arrival.
abstract final class TurnRules {
  /// Bearings are measured over this much trail on each side of the junction.
  static const lookM = 15.0;

  /// |Δbearing| below this = straight on.
  static const straightDeg = 30.0;

  /// "menanjak"/"menurun" when the next [slopeLookM] climbs/descends more than [slopeM].
  static const slopeLookM = 50.0;
  static const slopeM = 5.0;
}

List<TurnInstruction> buildTurns(
  List<RouteStep> steps, {
  required int Function(String nodeId) degree,
  required String arrivalText,
  String? destinationNodeId,
  double startDistanceM = 0,
}) {
  final turns = <TurnInstruction>[];
  for (var i = 0; i + 1 < steps.length; i++) {
    final node = steps[i].endNodeId;
    final deg = degree(node);
    if (deg < 3) continue; // a bend in one trail: nothing to decide
    final direction = classifyTurn(steps[i].geometry, steps[i + 1].geometry);
    turns.add(
      TurnInstruction(
        nodeId: node,
        direction: direction,
        distanceFromStartM: steps[i].endDistanceM,
        text: turnText(deg, direction, slopeWord(steps[i + 1])),
      ),
    );
  }
  final end = steps.isEmpty ? destinationNodeId : steps.last.endNodeId;
  if (end != null) {
    turns.add(
      TurnInstruction(
        nodeId: end,
        direction: TurnDirection.arrive,
        distanceFromStartM:
            steps.isEmpty ? startDistanceM : steps.last.endDistanceM,
        text: arrivalText,
      ),
    );
  }
  return turns;
}

/// Bearing change from the incoming to the outgoing trail at their shared node.
TurnDirection classifyTurn(List<GeoPoint> incoming, List<GeoPoint> outgoing) {
  final node = incoming.last;
  final before = pointAlong(incoming.reversed.toList(), TurnRules.lookM);
  final after = pointAlong(outgoing, TurnRules.lookM);
  if (before == node || after == node) return TurnDirection.straight;
  final delta = signedDelta(bearingDeg(before, node), bearingDeg(node, after));
  if (delta.abs() < TurnRules.straightDeg) return TurnDirection.straight;
  return delta < 0 ? TurnDirection.left : TurnDirection.right;
}

/// Δ from bearing [a] to bearing [b] in (−180, 180]; negative = turning left.
double signedDelta(double a, double b) {
  var d = (b - a) % 360;
  if (d > 180) d -= 360;
  return d;
}

/// The point [metres] along [pts] from its start (or its end if shorter).
GeoPoint pointAlong(List<GeoPoint> pts, double metres) {
  var left = metres;
  for (var i = 1; i < pts.length; i++) {
    final seg = haversineM(pts[i - 1], pts[i]);
    if (seg >= left && seg > 0) {
      final t = left / seg;
      return GeoPoint(
        pts[i - 1].lat + (pts[i].lat - pts[i - 1].lat) * t,
        pts[i - 1].lng + (pts[i].lng - pts[i - 1].lng) * t,
      );
    }
    left -= seg;
  }
  return pts.last;
}

/// "menanjak" / "menurun" / null, from the net climb over the first 50 m of [next].
String? slopeWord(RouteStep next) {
  if (next.lengthM <= 0) return null;
  final share = next.lengthM <= TurnRules.slopeLookM
      ? 1.0
      : TurnRules.slopeLookM / next.lengthM;
  final climb = (next.ascentM - next.descentM) * share;
  if (climb > TurnRules.slopeM) return 'menanjak';
  if (climb < -TurnRules.slopeM) return 'menurun';
  return null;
}

String junctionWord(int degree) => switch (degree) {
      3 => 'pertigaan',
      4 => 'perempatan',
      _ => 'persimpangan',
    };

/// e.g. "Di pertigaan, ambil jalur kiri menurun." / "Di perempatan, lurus terus."
String turnText(int degree, TurnDirection direction, String? slope) {
  final where = 'Di ${junctionWord(degree)}';
  final tail = slope == null ? '' : ' $slope';
  return switch (direction) {
    TurnDirection.left => '$where, ambil jalur kiri$tail.',
    TurnDirection.right => '$where, ambil jalur kanan$tail.',
    _ => '$where, lurus terus$tail.',
  };
}
