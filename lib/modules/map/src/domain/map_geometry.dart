import 'dart:math' as math;

import 'package:jelajah_taman/core/core.dart';

/// Axis-aligned lat/lng box. Our own type so the map maths is testable without flutter_map.
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  /// Smallest box containing every point. Throws on an empty input: a map with no content is a bug.
  factory GeoBounds.around(Iterable<GeoPoint> points) {
    final it = points.iterator;
    if (!it.moveNext()) {
      throw ArgumentError('GeoBounds.around needs at least one point');
    }
    var s = it.current.lat, n = it.current.lat;
    var w = it.current.lng, e = it.current.lng;
    while (it.moveNext()) {
      final p = it.current;
      s = math.min(s, p.lat);
      n = math.max(n, p.lat);
      w = math.min(w, p.lng);
      e = math.max(e, p.lng);
    }
    return GeoBounds(south: s, west: w, north: n, east: e);
  }

  final double south;
  final double west;
  final double north;
  final double east;

  GeoPoint get southWest => GeoPoint(south, west);
  GeoPoint get northEast => GeoPoint(north, east);
  GeoPoint get center => GeoPoint((south + north) / 2, (west + east) / 2);

  bool contains(GeoPoint p) =>
      p.lat >= south && p.lat <= north && p.lng >= west && p.lng <= east;

  /// Grows the box by [metres] on every side (flat-earth approximation, fine for a ~2 km zone).
  GeoBounds expandedBy(double metres) {
    final dLat = _degLat(metres);
    final dLng = _degLng(metres, center.lat);
    return GeoBounds(
      south: south - dLat,
      west: west - dLng,
      north: north + dLat,
      east: east + dLng,
    );
  }

  @override
  String toString() => 'GeoBounds(S $south, W $west, N $north, E $east)';
}

double _degLat(double metres) => metres / earthRadiusM * 180 / math.pi;

double _degLng(double metres, double atLat) =>
    _degLat(metres) / math.cos(atLat * math.pi / 180);

/// A closed ring of [segments] + 1 points at [radiusM] around [center] (first == last).
/// Used for dashed geofence rings, which flutter_map's CircleMarker can't draw.
List<GeoPoint> circlePoints(
  GeoPoint center,
  double radiusM, {
  int segments = 48,
}) {
  final dLat = _degLat(radiusM);
  final dLng = _degLng(radiusM, center.lat);
  return [
    for (var i = 0; i <= segments; i++)
      GeoPoint(
        center.lat + dLat * math.cos(2 * math.pi * (i % segments) / segments),
        center.lng + dLng * math.sin(2 * math.pi * (i % segments) / segments),
      ),
  ];
}
