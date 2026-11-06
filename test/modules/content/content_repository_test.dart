import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/modules/content/content.dart';

import '../../helpers/test_content.dart';

void main() {
  late ContentRepository content;

  setUpAll(() => content = loadTestContent());

  test('loads POIs, facilities, routes', () {
    expect(content.pois, isNotEmpty);
    expect(content.facilities, isNotEmpty);
    expect(content.routes.map((r) => r.id),
        containsAll(['santai', 'sedang', 'trekking']));
  });

  test('gate POI exists', () {
    expect(content.gate.id, content.park.gatePoiId);
  });

  test('every POI and facility points to an existing graph node', () {
    for (final p in content.pois) {
      expect(content.graph.nodes, contains(p.graphNode), reason: p.id);
    }
    for (final f in content.facilities) {
      expect(content.graph.nodes, contains(f.graphNode), reason: f.id);
    }
  });

  test('QR payload resolves cave POIs; unknown payload returns null (A02)', () {
    expect(content.poiByQr('jelajahtaman://poi/P05')?.id, 'P05');
    expect(content.poiByQr(' jelajahtaman://poi/P06/ ')?.id, 'P06');
    expect(content.poiByQr('https://example.com'), isNull);
  });

  test('park params are readable and typed', () {
    expect(content.park.param('cooldown_min'), 10);
    expect(content.park.recWeights.values.fold<double>(0, (a, b) => a + b),
        closeTo(1, 1e-9));
    expect(() => content.park.param('does_not_exist'), throwsStateError);
  });
}
