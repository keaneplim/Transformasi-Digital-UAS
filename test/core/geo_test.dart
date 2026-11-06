import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';

void main() {
  const origin = GeoPoint(-6.858, 107.633);

  test('haversine: 0.001° latitude is about 111.2 m', () {
    expect(haversineM(origin, const GeoPoint(-6.857, 107.633)),
        closeTo(111.19, 0.5));
  });

  test('haversine: same point is 0', () {
    expect(haversineM(origin, origin), 0);
  });

  test('bearing: north is 0°, east is 90°', () {
    expect(
        bearingDeg(origin, const GeoPoint(-6.857, 107.633)), closeTo(0, 0.01));
    expect(
        bearingDeg(origin, const GeoPoint(-6.858, 107.634)), closeTo(90, 0.01));
  });
}
