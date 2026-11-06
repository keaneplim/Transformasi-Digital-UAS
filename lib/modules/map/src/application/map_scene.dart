import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/content/content.dart';

import '../domain/map_geometry.dart';

/// Everything static the Explore map draws, derived once from the content (A01).
class MapScene {
  MapScene({
    required this.zone,
    required List<List<GeoPoint>> trails,
    required List<Poi> pois,
    required List<Facility> facilities,
    required this.approachMarginM,
  })  : trails = List.unmodifiable(trails),
        pois = List.unmodifiable(pois),
        facilities = List.unmodifiable(facilities);

  factory MapScene.fromContent(
    ContentRepository content, {
    double zonePaddingM = defaultZonePaddingM,
  }) {
    final graph = content.graph;
    final trails = <List<GeoPoint>>[
      for (final e in graph.edges)
        if (e.geometry.length >= 2)
          e.geometry
        else if (graph.nodes[e.from] case final from?)
          if (graph.nodes[e.to] case final to?) [from.position, to.position],
    ];
    final zone = GeoBounds.around([
      for (final n in graph.nodes.values) n.position,
      for (final p in content.pois) p.position,
      for (final f in content.facilities) f.position,
    ]).expandedBy(zonePaddingM);
    return MapScene(
      zone: zone,
      trails: trails,
      pois: content.pois,
      facilities: content.facilities,
      approachMarginM: content.park.param('approach_margin_m'),
    );
  }

  /// Margin around the content so markers at the edge aren't glued to the screen border.
  static const defaultZonePaddingM = 150.0;

  /// The Dago Pakar zone: camera is clamped to it; a user outside it gets the "di luar zona" chip.
  final GeoBounds zone;

  /// One polyline per trail-graph edge (surveyed trails, drawn on top of the tiles).
  final List<List<GeoPoint>> trails;
  final List<Poi> pois;
  final List<Facility> facilities;

  /// "Approaching" ring = radius + this (park.json `approach_margin_m`, F02).
  final double approachMarginM;

  bool isInsideZone(GeoPoint p) => zone.contains(p);
}
