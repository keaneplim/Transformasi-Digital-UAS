import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/trigger/trigger.dart';

import '../../helpers/test_content.dart';

/// A02 / plan "Acceptance criteria ↔ tests": valid, wrong scheme, unknown ID, lowercase ID,
/// trailing slash.
void main() {
  group('poiIdFromQr', () {
    test('a board payload gives its POI ID', () {
      expect(poiIdFromQr('jelajahtaman://poi/P05'), 'P05');
      expect(poiIdFromQr('jelajahtaman://poi/P06'), 'P06');
    });

    test(
        'lowercase ID, upper-case scheme, spaces and trailing slashes are tolerated',
        () {
      expect(poiIdFromQr('jelajahtaman://poi/p05'), 'P05');
      expect(poiIdFromQr('JELAJAHTAMAN://POI/P05'), 'P05');
      expect(poiIdFromQr('  jelajahtaman://poi/P06/ \n'), 'P06');
      expect(poiIdFromQr('jelajahtaman://poi/P06//'), 'P06');
    });

    test('anything else is not a board', () {
      for (final raw in [
        '',
        'P05',
        'https://example.com/poi/P05',
        'https://jelajahtaman.id/poi/P05',
        'jelajahtaman://poi/',
        'jelajahtaman://place/P05',
        'jelajahtaman://poi/P05/extra',
        'jelajahtaman://poi/P05?x=1',
        'xjelajahtaman://poi/P05',
      ]) {
        expect(poiIdFromQr(raw), isNull, reason: raw);
      }
    });
  });

  group('resolveQr on the bundled content (offline)', () {
    late ContentRepository content;
    setUp(() => content = loadTestContent());

    test('both cave boards open their POI', () {
      for (final id in ['P05', 'P06']) {
        final scan = resolveQr('jelajahtaman://poi/$id', content);
        expect(scan, isA<QrPoi>());
        expect((scan as QrPoi).poi.id, id);
      }
    });

    test('every printed board payload in pois.json resolves to its own POI',
        () {
      for (final p in content.pois.where((p) => p.qrCode != null)) {
        final scan = resolveQr(p.qrCode!, content);
        expect((scan as QrPoi).poi.id, p.id, reason: p.qrCode);
      }
    });

    test('an unknown ID and a foreign code are told apart', () {
      expect(resolveQr('jelajahtaman://poi/P99', content), isA<QrUnknownPoi>());
      expect((resolveQr('jelajahtaman://poi/p99', content) as QrUnknownPoi).id,
          'P99');
      expect(resolveQr('https://example.com', content), isA<QrForeign>());
    });
  });
}
