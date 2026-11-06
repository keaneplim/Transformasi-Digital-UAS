import 'dart:math' as math;

/// A WGS84 coordinate. Our own type so domain code doesn't depend on a map package.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

const double earthRadiusM = 6371000.0;

double _rad(double deg) => deg * math.pi / 180.0;

/// Great-circle distance in metres (haversine). Accurate enough for a ~2 km zone.
double haversineM(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final sinLat = math.sin(dLat / 2);
  final sinLng = math.sin(dLng / 2);
  final h = sinLat * sinLat +
      math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * sinLng * sinLng;
  return 2 * earthRadiusM * math.asin(math.sqrt(h));
}

/// Initial bearing from [a] to [b] in degrees, 0 = north, 90 = east.
double bearingDeg(GeoPoint a, GeoPoint b) {
  final lat1 = _rad(a.lat);
  final lat2 = _rad(b.lat);
  final dLng = _rad(b.lng - a.lng);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}
