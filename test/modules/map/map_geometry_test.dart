import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/map/src/domain/map_geometry.dart';

void main() {
  const a = GeoPoint(-6.858, 107.633);
  const b = GeoPoint(-6.852, 107.640);

  group('GeoBounds', () {
    test('around() is the smallest box containing every point', () {
      final box = GeoBounds.around([a, b, const GeoPoint(-6.855, 107.636)]);
      expect(box.south, -6.858);
      expect(box.north, -6.852);
      expect(box.west, 107.633);
      expect(box.east, 107.640);
      expect(box.contains(a), isTrue);
      expect(box.contains(b), isTrue);
    });

    test('around() rejects an empty input', () {
      expect(() => GeoBounds.around(const []), throwsArgumentError);
    });

    test('contains() is false just outside the box', () {
      final box = GeoBounds.around([a, b]);
      expect(box.contains(const GeoPoint(-6.8581, 107.635)), isFalse);
      expect(box.contains(const GeoPoint(-6.855, 107.6401)), isFalse);
    });

    test('expandedBy() grows every side by about the given metres', () {
      final box = GeoBounds.around([a, b]);
      final big = box.expandedBy(100);
      final south =
          haversineM(GeoPoint(box.south, a.lng), GeoPoint(big.south, a.lng));
      final east =
          haversineM(GeoPoint(a.lat, box.east), GeoPoint(a.lat, big.east));
      expect(south, closeTo(100, 0.5));
      expect(east, closeTo(100, 0.5));
    });
  });

  group('circlePoints', () {
    test('is a closed ring with every point at the radius', () {
      final ring = circlePoints(a, 25, segments: 36);
      expect(ring, hasLength(37));
      expect(ring.first, ring.last);
      for (final p in ring) {
        expect(haversineM(a, p), closeTo(25, 0.1));
      }
    });
  });
}
