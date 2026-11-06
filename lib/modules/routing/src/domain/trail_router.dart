import 'package:jelajah_taman/core/core.dart';

/// Named `TrailRouter` (not `Router`) to avoid clashing with Flutter's `Router` widget.
abstract interface class TrailRouter {
  /// Shortest walkable route from a position to a graph node, or null if unreachable.
  RouteResult? route(GeoPoint from, String toNodeId);

  double walkingDistanceM(GeoPoint from, String toNodeId);

  /// Includes the slope correction (decision D09).
  Duration walkingTime(GeoPoint from, String toNodeId);

  Duration walkingTimeBetween(String fromNodeId, String toNodeId);
}

class RouteResult {
  const RouteResult({
    required this.polyline,
    required this.nodeIds,
    required this.distanceM,
    required this.eta,
    required this.turns,
  });

  final List<GeoPoint> polyline;
  final List<String> nodeIds;
  final double distanceM;
  final Duration eta;
  final List<TurnInstruction> turns;
}

enum TurnDirection { straight, left, right, arrive }

class TurnInstruction {
  const TurnInstruction({
    required this.nodeId,
    required this.direction,
    required this.distanceFromStartM,
    required this.text,
  });

  final String nodeId;
  final TurnDirection direction;

  /// Along the route from where it was computed; navigation (T19) speaks it ~20 m ahead.
  final double distanceFromStartM;

  /// Spoken/display text, e.g. "Di pertigaan, ambil jalur kiri menurun."
  final String text;
}
