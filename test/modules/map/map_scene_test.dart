import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/map/map.dart';

import '../../helpers/test_content.dart';

void main() {
  final content = loadTestContent();
  final scene = MapScene.fromContent(content);

  test('zone contains every POI, facility and graph node', () {
    for (final p in content.pois) {
      expect(scene.isInsideZone(p.position), isTrue, reason: p.id);
    }
    for (final f in content.facilities) {
      expect(scene.isInsideZone(f.position), isTrue, reason: f.id);
    }
    for (final n in content.graph.nodes.values) {
      expect(scene.isInsideZone(n.position), isTrue, reason: n.id);
    }
  });

  test('zone has the padding margin around the content', () {
    final tight = MapScene.fromContent(content, zonePaddingM: 0).zone;
    final gap = haversineM(
      GeoPoint(tight.south, tight.center.lng),
      GeoPoint(scene.zone.south, tight.center.lng),
    );
    expect(gap, closeTo(MapScene.defaultZonePaddingM, 1));
  });

  test('a point 1 km away is outside the zone', () {
    final far = GeoPoint(scene.zone.north + 0.01, scene.zone.center.lng);
    expect(scene.isInsideZone(far), isFalse);
  });

  test('one drawable polyline per trail-graph edge', () {
    expect(scene.trails, hasLength(content.graph.edges.length));
    for (final t in scene.trails) {
      expect(t.length, greaterThanOrEqualTo(2));
    }
  });

  test('approach margin comes from park.json', () {
    expect(scene.approachMarginM, content.park.param('approach_margin_m'));
  });
}
