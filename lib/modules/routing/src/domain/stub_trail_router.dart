import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/content/content.dart';

import 'trail_router.dart';

/// Day-1 stub so other coders never wait for Dijkstra (IMPLEMENTATION_PLAN §0.3).
///
/// Distance = straight line × 1.3; time = distance / walking speed; no slope, no turns.
/// Replaced by the graph-based router (owner B, PB12/PB14) behind the same interface.
class StubTrailRouter implements TrailRouter {
  StubTrailRouter(this._content);

  final ContentRepository _content;

  static const double detourFactor = 1.3;

  GeoPoint _node(String id) {
    final node = _content.graph.nodes[id];
    if (node == null) {
      throw ArgumentError.value(id, 'nodeId', 'unknown graph node');
    }
    return node.position;
  }

  Duration _timeFor(double metres) {
    final speed = _content.park.param('walk_speed_m_per_min');
    return Duration(seconds: (metres / speed * 60).round());
  }

  @override
  double walkingDistanceM(GeoPoint from, String toNodeId) =>
      haversineM(from, _node(toNodeId)) * detourFactor;

  @override
  Duration walkingTime(GeoPoint from, String toNodeId) =>
      _timeFor(walkingDistanceM(from, toNodeId));

  @override
  Duration walkingTimeBetween(String fromNodeId, String toNodeId) =>
      walkingTime(_node(fromNodeId), toNodeId);

  @override
  RouteResult? route(GeoPoint from, String toNodeId) {
    if (!_content.graph.nodes.containsKey(toNodeId)) return null;
    final distance = walkingDistanceM(from, toNodeId);
    return RouteResult(
      polyline: [from, _node(toNodeId)],
      nodeIds: [toNodeId],
      distanceM: distance,
      eta: _timeFor(distance),
      turns: const [],
    );
  }
}
