import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/shell/src/state/places.dart';
import 'package:jelajah_taman/modules/shell/src/state/search.dart';
import 'package:jelajah_taman/modules/shell/src/ui/widgets.dart';

import '../../helpers/test_content.dart';

void main() {
  final content = loadTestContent();
  final places = [
    for (final p in content.pois) Place.poi(p),
    for (final f in content.facilities) Place.facility(f),
  ];
  Place byId(String id) => places.firstWhere((p) => p.id == id);
  List<String> ids(String q) =>
      [for (final h in searchPlaces(places, q)) h.place.id];

  group('matchPlace (F05)', () {
    test('an empty query matches everything with score 0', () {
      expect(searchPlaces(places, '  '), hasLength(places.length));
      expect(matchPlace(byId('P05'), '')!.score, 0);
    });

    test('ranks the start of a name above a word inside it', () {
      final cave = matchPlace(byId('P05'), 'gua')!; // Gua Jepang
      final toilet =
          matchPlace(byId('FS06'), 'gua')!; // Toilet dekat Gua Belanda
      expect(cave.score, greaterThan(toilet.score));
      expect(cave.via, isNull);
    });

    test('reads "goa" as "gua" and ignores case and punctuation', () {
      expect(ids('GOA'), containsAll(['P05', 'P06']));
      expect(ids('gua-jepang'), contains('P05'));
    });

    test('a synonym matches and says which one', () {
      final hit = matchPlace(byId('FS01'), 'wc')!;
      expect(hit.via, 'wc');
      expect(hit.fuzzy, isFalse);
      expect(ids('wc'), unorderedEquals(['FS01', 'FS06']));
      expect(ids('masjid'), unorderedEquals(['FS02', 'FS07']));
    });

    test('tolerates one slip in a short word, a swapped pair included', () {
      final hit = matchPlace(byId('P08'), 'pinsu')!; // Kawasan Hutan Pinus
      expect(hit.fuzzy, isTrue);
      expect(hit.corrected, 'pinus');
      expect(ids('toliet'), containsAll(['FS01', 'FS06']));
      expect(ids('rsa'), isNot(contains('P07')),
          reason: 'words under 4 letters get no typo budget');
    });

    test('every word of the query has to match', () {
      expect(ids('gua belanda'), contains('P06'));
      expect(ids('gua belanda'), isNot(contains('P05')));
      expect(ids('kolam renang'), isEmpty);
    });

    test('a literal match is ranked above a typo-tolerant one', () {
      final exact = matchPlace(byId('P08'), 'pinus')!;
      final typo = matchPlace(byId('P08'), 'pinsu')!;
      expect(exact.score, greaterThan(typo.score));
    });
  });

  group('didYouMean', () {
    test('is the reading the typo-tolerant hits agree on', () {
      final hits = searchPlaces(places, 'pinsu');
      expect(didYouMean(hits), 'pinus');
      expect(
          [for (final h in hits) h.place.id], unorderedEquals(['P08', 'FS05']),
          reason: 'a misspelt synonym ("pintu") loses to a misspelt name');
    });

    test('is null when something matched literally or nothing matched', () {
      expect(didYouMean(searchPlaces(places, 'pinus')), isNull);
      expect(didYouMean(searchPlaces(places, 'kolam renang')), isNull);
    });
  });

  group('sortHits', () {
    double far(Place p) => p.id == 'P06' ? 10 : 500;

    test('relevance: score first, then distance', () {
      final hits = searchPlaces(places, 'gua');
      sortHits(hits, SearchSort.relevance, far);
      expect(hits.first.place.id, 'P06');
      expect(hits[1].place.id, 'P05');
    });

    test('nearest and A–Z', () {
      final hits = searchPlaces(places, 'gua');
      sortHits(hits, SearchSort.nearest, far);
      expect(hits.first.place.id, 'P06');
      sortHits(hits, SearchSort.name, far);
      final names = [for (final h in hits) h.place.name.toLowerCase()];
      expect(names, [...names]..sort());
    });
  });

  group('RecentSearches', () {
    test('keeps the newest first, without duplicates, at most six', () {
      final recents = RecentSearches(MemoryKeyValueStore());
      for (final q in ['gua', 'toilet', 'Gua', 'a', ' rusa ']) {
        recents.add(q);
      }
      expect(recents.items, ['rusa', 'Gua', 'toilet']);
      for (var i = 0; i < 10; i++) {
        recents.add('kata $i');
      }
      expect(recents.items, hasLength(RecentSearches.max));
      expect(recents.items.first, 'kata 9');
    });

    test('survives a restart and can be cleared', () {
      final store = MemoryKeyValueStore();
      RecentSearches(store)
        ..add('gua')
        ..add('saung');
      final again = RecentSearches(store);
      expect(again.items, ['saung', 'gua']);
      again.remove('saung');
      expect(RecentSearches(store).items, ['gua']);
      again.clear();
      expect(RecentSearches(store).items, isEmpty);
    });

    test('drops unreadable stored history', () {
      final store = MemoryKeyValueStore({'recent_searches': 'not json'});
      expect(RecentSearches(store).items, isEmpty);
    });
  });

  group('MatchText.ranges', () {
    test('marks the whole phrase when it occurs', () {
      expect(MatchText.ranges('Gua Belanda', 'gua bel'), [(0, 7)]);
    });

    test('otherwise marks every word, merged and in order', () {
      expect(MatchText.ranges('Toilet dekat Gua Belanda', 'belanda toilet'),
          [(0, 6), (17, 24)]);
      expect(MatchText.ranges('Gua Jepang', 'x'), isEmpty);
      expect(MatchText.ranges('Gua Jepang', ''), isEmpty);
    });
  });
}
