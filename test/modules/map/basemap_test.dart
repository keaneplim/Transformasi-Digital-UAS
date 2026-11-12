import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/modules/map/map.dart';

import '../../helpers/test_content.dart';

void main() {
  final bm = loadTestBasemap();
  final content = loadTestContent();

  test('bundled basemap parses and covers every POI and facility', () {
    expect(bm.landcover, isNotEmpty);
    expect(bm.boundary, isNotEmpty);
    expect(bm.contours, isNotEmpty);
    for (final p in content.pois) {
      expect(bm.bounds.contains(p.position), isTrue, reason: p.id);
    }
    for (final f in content.facilities) {
      expect(bm.bounds.contains(f.position), isTrue, reason: f.id);
    }
  });

  test('index contours fall on the index step, sources credit OpenStreetMap',
      () {
    final index = bm.contours.where(bm.isIndexContour).toList();
    expect(index, isNotEmpty);
    for (final c in index) {
      expect(c.elevationM! % bm.indexStepM, 0);
    }
    expect(bm.sources.join(' '), contains('OpenStreetMap'));
    expect(bm.hillshadeFile, 'hillshade.png');
  });

  test('scene extent is the basemap bounds', () {
    final scene = MapScene.fromContent(content, basemap: bm);
    expect(scene.extent, same(bm.bounds));
  });
}
