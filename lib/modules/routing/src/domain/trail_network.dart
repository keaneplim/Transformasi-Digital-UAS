import 'dart:math' as math;

import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/content/content.dart';

/// One directed traversal of a graph edge (edges are undirected; cost depends on direction).
class Arc {
  const Arc({
    required this.edge,
    required this.forward,
    required this.to,
    required this.lengthM,
    required this.minutes,
  });

  /// Index into [TrailGraph.edges].
  final int edge;

  /// True when walked from `edge.from` to `edge.to`.
  final bool forward;
  final String to;
  final double lengthM;
  final double minutes;
}

/// Where a position lands on the trail network.
class EdgeSnap {
  const EdgeSnap({
    required this.edge,
    required this.fraction,
    required this.point,
    required this.offTrailM,
    this.nodeId,
  });

  final int edge;

  /// 0 at `edge.from`, 1 at `edge.to`.
  final double fraction;
  final GeoPoint point;

  /// Straight-line distance from the position to [point] (walked without slope cost).
  final double offTrailM;

  /// Set when the snap point is within [TrailNetwork.nodeSnapM] of a node: start there.
  final String? nodeId;
}

/// Result of one Dijkstra run: cost/length to every reachable node and the tree to rebuild paths.
class PathTree {
  const PathTree({
    required this.source,
    required this.minutes,
    required this.metres,
    required this.via,
  });

  final String source;
  final Map<String, double> minutes;
  final Map<String, double> metres;

  /// node → the arc that reached it.
  final Map<String, ({String from, Arc arc})> via;
}

/// The trail graph as a weighted network (F06 "Routing & ETA").
///
/// Edge cost is TIME (decision D09): `length / walk speed + ascent / 10 m × min per 10 m`, with
/// ascent taken in the walking direction (descent adds nothing). Parameters come from park.json.
class TrailNetwork {
  TrailNetwork(
    this.graph, {
    required this.walkSpeedMPerMin,
    required this.ascentMinPer10m,
  }) {
    for (var i = 0; i < graph.edges.length; i++) {
      final e = graph.edges[i];
      final geom = e.geometry.length >= 2
          ? e.geometry
          : [graph.nodes[e.from]!.position, graph.nodes[e.to]!.position];
      _geometry.add(geom);
      final cum = <double>[0];
      for (var k = 1; k < geom.length; k++) {
        cum.add(cum.last + haversineM(geom[k - 1], geom[k]));
      }
      _cumulative.add(cum);
      (_adj[e.from] ??= []).add(arcOf(i, forward: true));
      (_adj[e.to] ??= []).add(arcOf(i, forward: false));
    }
  }

  /// Virtual node id for "the user's position" in a [PathTree].
  static const start = '__start__';

  /// A snap point this close to a node starts from that node (F06 edge case).
  static const nodeSnapM = 3.0;

  final TrailGraph graph;
  final double walkSpeedMPerMin;
  final double ascentMinPer10m;

  final _adj = <String, List<Arc>>{};
  final _geometry = <List<GeoPoint>>[];
  final _cumulative = <List<double>>[];
  final _treeFromNode = <String, PathTree>{};
  ({GeoPoint at, EdgeSnap snap, PathTree tree})? _lastFromPosition;

  /// Number of trail edges meeting at [nodeId] (3 = pertigaan, 4 = perempatan).
  int degree(String nodeId) => _adj[nodeId]?.length ?? 0;

  /// Edge geometry, oriented from `edge.from` to `edge.to`.
  List<GeoPoint> geometry(int edge) => _geometry[edge];

  double minutesFor(double lengthM, double ascentM) =>
      lengthM / walkSpeedMPerMin + ascentM / 10 * ascentMinPer10m;

  Arc arcOf(int edge, {required bool forward, double fraction = 1}) {
    final e = graph.edges[edge];
    final length = e.lengthM * fraction;
    final ascent = (forward ? e.ascentM : e.descentM) * fraction;
    return Arc(
      edge: edge,
      forward: forward,
      to: forward ? e.to : e.from,
      lengthM: length,
      minutes: minutesFor(length, ascent),
    );
  }

  /// Nearest point on any edge. Uses a local flat projection around [p] (exact enough < 5 km).
  EdgeSnap snap(GeoPoint p) {
    const k = earthRadiusM * math.pi / 180;
    final kx = k * math.cos(p.lat * math.pi / 180);
    ({double x, double y}) xy(GeoPoint q) =>
        (x: (q.lng - p.lng) * kx, y: (q.lat - p.lat) * k);

    var best = double.infinity;
    var bestEdge = 0, bestSeg = 0;
    var bestT = 0.0;
    for (var i = 0; i < _geometry.length; i++) {
      final g = _geometry[i];
      for (var s = 0; s + 1 < g.length; s++) {
        final a = xy(g[s]), b = xy(g[s + 1]);
        final dx = b.x - a.x, dy = b.y - a.y;
        final l2 = dx * dx + dy * dy;
        final t = l2 == 0 ? 0.0 : ((-a.x * dx - a.y * dy) / l2).clamp(0.0, 1.0);
        final px = a.x + dx * t, py = a.y + dy * t;
        final d = math.sqrt(px * px + py * py);
        if (d < best) {
          best = d;
          bestEdge = i;
          bestSeg = s;
          bestT = t;
        }
      }
    }
    final g = _geometry[bestEdge];
    final cum = _cumulative[bestEdge];
    final a = g[bestSeg], b = g[bestSeg + 1];
    final point = GeoPoint(
      a.lat + (b.lat - a.lat) * bestT,
      a.lng + (b.lng - a.lng) * bestT,
    );
    final total = cum.last;
    final fraction = total == 0
        ? 0.0
        : (cum[bestSeg] + (cum[bestSeg + 1] - cum[bestSeg]) * bestT) / total;
    final e = graph.edges[bestEdge];
    String? node;
    if (fraction * e.lengthM <= nodeSnapM) {
      node = e.from;
    } else if ((1 - fraction) * e.lengthM <= nodeSnapM) {
      node = e.to;
    }
    if (node != null) {
      final pos = graph.nodes[node]!.position;
      return EdgeSnap(
        edge: bestEdge,
        fraction: node == e.from ? 0 : 1,
        point: pos,
        offTrailM: haversineM(p, pos),
        nodeId: node,
      );
    }
    return EdgeSnap(
      edge: bestEdge,
      fraction: fraction,
      point: point,
      offTrailM: haversineM(p, point),
    );
  }

  /// Shortest-time tree from a node. Memoized: recommendation and search ask many times.
  PathTree fromNode(String nodeId) =>
      _treeFromNode[nodeId] ??= _dijkstra(nodeId, _adj[nodeId] ?? const []);

  /// Shortest-time tree from a free position (snap + virtual start node). The last call is
  /// cached, so sorting many search results from one position costs one Dijkstra.
  ({EdgeSnap snap, PathTree tree}) fromPosition(GeoPoint p) {
    final last = _lastFromPosition;
    if (last != null && last.at == p) return (snap: last.snap, tree: last.tree);
    final s = snap(p);
    final tree = s.nodeId != null
        ? fromNode(s.nodeId!)
        : _dijkstra(start, [
            arcOf(s.edge, forward: false, fraction: s.fraction),
            arcOf(s.edge, forward: true, fraction: 1 - s.fraction),
          ]);
    _lastFromPosition = (at: p, snap: s, tree: tree);
    return (snap: s, tree: tree);
  }

  /// O(V²) Dijkstra: the park graph has at most a few hundred nodes, so a heap isn't worth a
  /// dependency.
  PathTree _dijkstra(String source, List<Arc> sourceArcs) {
    final minutes = <String, double>{source: 0};
    final metres = <String, double>{source: 0};
    final via = <String, ({String from, Arc arc})>{};
    final done = <String>{};
    while (true) {
      String? u;
      var best = double.infinity;
      for (final entry in minutes.entries) {
        if (entry.value < best && !done.contains(entry.key)) {
          best = entry.value;
          u = entry.key;
        }
      }
      if (u == null) break;
      done.add(u);
      for (final arc in u == source ? sourceArcs : (_adj[u] ?? const <Arc>[])) {
        final candidate = best + arc.minutes;
        if (candidate < (minutes[arc.to] ?? double.infinity)) {
          minutes[arc.to] = candidate;
          metres[arc.to] = metres[u]! + arc.lengthM;
          via[arc.to] = (from: u, arc: arc);
        }
      }
    }
    return PathTree(source: source, minutes: minutes, metres: metres, via: via);
  }

  /// The part of edge geometry between two fractions, in walking order (f0 → f1).
  List<GeoPoint> partialGeometry(int edge, double f0, double f1) {
    final g = _geometry[edge];
    final cum = _cumulative[edge];
    final total = cum.last;
    GeoPoint at(double f) {
      if (total == 0) return g.first;
      final target = f * total;
      for (var s = 0; s + 1 < g.length; s++) {
        if (cum[s + 1] >= target) {
          final len = cum[s + 1] - cum[s];
          final t = len == 0 ? 0.0 : (target - cum[s]) / len;
          return GeoPoint(
            g[s].lat + (g[s + 1].lat - g[s].lat) * t,
            g[s].lng + (g[s + 1].lng - g[s].lng) * t,
          );
        }
      }
      return g.last;
    }

    final lo = math.min(f0, f1), hi = math.max(f0, f1);
    final inside = [
      for (var s = 1; s + 1 < g.length; s++)
        if (total > 0 && cum[s] / total > lo && cum[s] / total < hi) g[s],
    ];
    final pts = [at(lo), ...inside, at(hi)];
    return f0 <= f1 ? pts : pts.reversed.toList();
  }
}
