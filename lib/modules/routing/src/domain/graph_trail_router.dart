import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/content/content.dart';

import 'trail_network.dart';
import 'trail_router.dart';
import 'turn_instructions.dart';

/// The real router (T14): snap to the trail, Dijkstra on walking time, ETA with slope (D09),
/// turn instructions at junctions. Works on any `trail_graph.json` (dummy or surveyed).
///
/// Errors: unknown node → [route] returns null, the other methods throw [ArgumentError].
/// Unreachable node → [route] returns null, the others throw [StateError]. Unreachable can't
/// ship: `tools/validate_content.py` fails CI on a disconnected graph.
class GraphTrailRouter implements TrailRouter {
  GraphTrailRouter(
    TrailGraph graph, {
    required double walkSpeedMPerMin,
    required double ascentMinPer10m,
    Map<String, String> nodeNames = const {},
  })  : _net = TrailNetwork(
          graph,
          walkSpeedMPerMin: walkSpeedMPerMin,
          ascentMinPer10m: ascentMinPer10m,
        ),
        _names = nodeNames;

  factory GraphTrailRouter.fromContent(ContentRepository content) =>
      GraphTrailRouter(
        content.graph,
        walkSpeedMPerMin: content.park.param('walk_speed_m_per_min'),
        ascentMinPer10m: content.park.param('ascent_min_per_10m'),
        nodeNames: {
          for (final p in content.pois) p.graphNode: p.name,
          for (final f in content.facilities) f.graphNode: f.name,
        },
      );

  final TrailNetwork _net;
  final Map<String, String> _names;

  void _requireNode(String id) {
    if (!_net.graph.nodes.containsKey(id)) {
      throw ArgumentError.value(id, 'nodeId', 'unknown graph node');
    }
  }

  Duration _duration(double minutes) =>
      Duration(seconds: (minutes * 60).round());

  /// Off-trail leg + trail path, as (metres, minutes).
  ({double metres, double minutes}) _cost(GeoPoint from, String toNodeId) {
    _requireNode(toNodeId);
    final (:snap, :tree) = _net.fromPosition(from);
    final m = tree.metres[toNodeId];
    if (m == null) {
      throw StateError('$toNodeId is not reachable on the trail graph');
    }
    return (
      metres: snap.offTrailM + m,
      minutes: _net.minutesFor(snap.offTrailM, 0) + tree.minutes[toNodeId]!,
    );
  }

  @override
  double walkingDistanceM(GeoPoint from, String toNodeId) =>
      _cost(from, toNodeId).metres;

  @override
  Duration walkingTime(GeoPoint from, String toNodeId) =>
      _duration(_cost(from, toNodeId).minutes);

  @override
  Duration walkingTimeBetween(String fromNodeId, String toNodeId) {
    _requireNode(fromNodeId);
    _requireNode(toNodeId);
    final minutes = _net.fromNode(fromNodeId).minutes[toNodeId];
    if (minutes == null) {
      throw StateError('$toNodeId is not reachable from $fromNodeId');
    }
    return _duration(minutes);
  }

  @override
  RouteResult? route(GeoPoint from, String toNodeId) {
    if (!_net.graph.nodes.containsKey(toNodeId)) return null;
    final (:snap, :tree) = _net.fromPosition(from);
    if (!tree.metres.containsKey(toNodeId)) return null;

    // Walk the tree back from the destination to the start.
    final arcs = <({String from, Arc arc})>[];
    for (var n = toNodeId; n != tree.source;) {
      final step = tree.via[n]!;
      arcs.add(step);
      n = step.from;
    }
    final ordered = arcs.reversed.toList();

    final polyline = <GeoPoint>[snap.point];
    final steps = <RouteStep>[];
    var walked = snap.offTrailM;
    for (final (from: f, :arc) in ordered) {
      final e = _net.graph.edges[arc.edge];
      final List<GeoPoint> geom;
      if (f == TrailNetwork.start) {
        // first, partial edge from the snap point to one of its ends
        geom =
            _net.partialGeometry(arc.edge, snap.fraction, arc.forward ? 1 : 0);
      } else {
        final g = _net.geometry(arc.edge);
        geom = arc.forward ? g : g.reversed.toList();
      }
      polyline.addAll(geom.skip(1));
      walked += arc.lengthM;
      final share = e.lengthM == 0 ? 0.0 : arc.lengthM / e.lengthM;
      steps.add(
        RouteStep(
          geometry: geom,
          lengthM: arc.lengthM,
          ascentM: (arc.forward ? e.ascentM : e.descentM) * share,
          descentM: (arc.forward ? e.descentM : e.ascentM) * share,
          endNodeId: arc.to,
          endDistanceM: walked,
        ),
      );
    }

    final name = _names[toNodeId];
    final cost = _cost(from, toNodeId);
    return RouteResult(
      polyline: polyline,
      nodeIds: [
        if (snap.nodeId != null) snap.nodeId!,
        for (final s in steps) s.endNodeId,
      ],
      distanceM: cost.metres,
      eta: _duration(cost.minutes),
      turns: buildTurns(
        steps,
        degree: _net.degree,
        arrivalText:
            name == null ? 'Anda tiba di tujuan.' : 'Anda tiba di $name.',
        destinationNodeId: toNodeId,
        startDistanceM: snap.offTrailM,
      ),
    );
  }
}
