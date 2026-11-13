import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';

import 'places.dart';

/// How the search list is ordered.
enum SearchSort {
  /// Best match first (only meaningful with a query), nearest as the tie-breaker.
  relevance,

  /// Shortest walk first.
  nearest,

  /// Alphabetical.
  name,
}

/// A place that matched a query, with how well and through what.
class SearchHit {
  const SearchHit(this.place,
      {this.score = 0, this.via, this.corrected, this.fuzzy = false});

  final Place place;

  /// Higher is better: 100 exact name … 20 typo-tolerant keyword match. 0 without a query.
  final int score;

  /// The synonym that matched when the name itself did not (e.g. "wc" for a toilet).
  final String? via;

  /// The query as it was understood when typo tolerance kicked in ("pinsu" → "pinus").
  final String? corrected;

  /// True when at least one query word only matched within the typo budget.
  final bool fuzzy;
}

/// F05 matching (D12): case-insensitive partial match on the name and keywords (synonyms
/// like "wc" → toilet), plus light typo tolerance: Levenshtein ≤ 1 for words of 4–6
/// letters, ≤ 2 for words of ≥ 7 letters (a swapped pair counts as one). Returns null when [p] does not match.
///
/// The score ranks hits: the whole name, then the start of the name, a word of the name,
/// anywhere in the name, a keyword, the category, word-by-word, and last typo-tolerant.
SearchHit? matchPlace(Place p, String query) {
  final q = normalizeQuery(query);
  if (q.isEmpty) return SearchHit(p);
  final name = normalizeQuery(p.name);
  final nameWords = name.split(' ');
  if (name == q) return SearchHit(p, score: 100);
  if (name.startsWith(q)) return SearchHit(p, score: 90);
  if (nameWords.any((w) => w.startsWith(q))) return SearchHit(p, score: 80);
  if (name.contains(q)) return SearchHit(p, score: 70);

  final keywords = [
    ...?p.poi?.keywords.map(normalizeQuery),
    ...?p.facility?.keywords.map(normalizeQuery),
  ];
  for (final (score, test) in [
    (60, (String k) => k == q),
    (55, (String k) => k.startsWith(q)),
    (50, (String k) => k.contains(q)),
  ]) {
    for (final k in keywords) {
      if (test(k)) return SearchHit(p, score: score, via: k);
    }
  }
  final label = normalizeQuery(p.groupLabel);
  if (label.contains(q)) return SearchHit(p, score: 45);

  // Word by word: every query word must match some word, exactly, partially, or within
  // the typo budget.
  final otherWords = {
    for (final k in keywords) ...k.split(' '),
    ...label.split(' '),
  }..remove('');
  String? via;
  var fuzzy = false;
  final understood = <String>[];
  for (final qw in q.split(' ')) {
    if (nameWords.any((w) => w.contains(qw))) {
      understood.add(qw);
      continue;
    }
    final partial = otherWords.where((w) => w.contains(qw)).firstOrNull;
    if (partial != null) {
      via ??= partial;
      understood.add(qw);
      continue;
    }
    final budget = qw.length >= 7 ? 2 : (qw.length >= 4 ? 1 : 0);
    if (budget == 0) return null;
    String? best;
    var bestD = budget + 1;
    var bestInName = false;
    for (final (inName, words) in [(true, nameWords), (false, otherWords)]) {
      for (final w in words) {
        final d = _lev(qw, w);
        if (d < bestD) {
          best = w;
          bestD = d;
          bestInName = inName;
        }
      }
    }
    if (best == null) return null;
    fuzzy = true;
    if (!bestInName) via ??= best;
    understood.add(best);
  }
  return SearchHit(
    p,
    score: fuzzy ? (via == null ? 30 : 20) : 40,
    via: via,
    corrected: fuzzy ? understood.join(' ') : null,
    fuzzy: fuzzy,
  );
}

bool matchesQuery(Place p, String query) => matchPlace(p, query) != null;

/// Every place that matches [query], unsorted. Typo-tolerant hits are a fallback: they
/// are dropped when anything matched literally, and otherwise only the closest tier stays
/// (a misspelt name beats a misspelt synonym).
List<SearchHit> searchPlaces(Iterable<Place> places, String query) {
  final hits = [
    for (final p in places)
      if (matchPlace(p, query) case final hit?) hit,
  ];
  if (!hits.any((h) => h.fuzzy)) return hits;
  if (hits.any((h) => !h.fuzzy)) return hits.where((h) => !h.fuzzy).toList();
  final best = hits.map((h) => h.score).reduce(math.max);
  return hits.where((h) => h.score == best).toList();
}

/// When nothing matched literally and typo tolerance had to step in: the reading most
/// hits agree on ("pinsu" → "pinus"). Null otherwise.
String? didYouMean(List<SearchHit> hits) {
  if (hits.isEmpty || hits.any((h) => !h.fuzzy)) return null;
  final votes = <String, int>{};
  for (final h in hits) {
    votes.update(h.corrected!, (v) => v + 1, ifAbsent: () => 1);
  }
  return (votes.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .first
      .key;
}

/// Orders [hits] in place. [distanceOf] is the walking distance in metres.
void sortHits(
    List<SearchHit> hits, SearchSort sort, double Function(Place) distanceOf) {
  int byDistance(SearchHit a, SearchHit b) =>
      distanceOf(a.place).compareTo(distanceOf(b.place));
  hits.sort(switch (sort) {
    SearchSort.nearest => byDistance,
    SearchSort.name => (a, b) =>
        a.place.name.toLowerCase().compareTo(b.place.name.toLowerCase()),
    SearchSort.relevance => (a, b) {
        final s = b.score.compareTo(a.score);
        return s != 0 ? s : byDistance(a, b);
      },
  });
}

/// Lower-case, punctuation stripped, single spaces, "goa" read as "gua".
String normalizeQuery(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll('goa', 'gua')
    .trim();

/// Edit distance where swapping two neighbouring letters counts as one slip
/// (optimal string alignment), so "pinsu" is one away from "pinus".
int _lev(String a, String b) {
  if ((a.length - b.length).abs() > 2) return 99;
  List<int>? prev2;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var d =
          math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      if (prev2 != null &&
          j > 1 &&
          a[i - 1] == b[j - 2] &&
          a[i - 2] == b[j - 1]) {
        d = math.min(d, prev2[j - 2] + 1);
      }
      cur[j] = d;
    }
    prev2 = prev;
    prev = cur;
  }
  return prev[b.length];
}

/// The last few things the visitor searched for, newest first. Kept on the device only
/// (NG05: no accounts, no server data).
class RecentSearches extends ChangeNotifier {
  RecentSearches(this._store) {
    try {
      final raw = _store.getString(_key);
      if (raw != null) {
        _items.addAll((jsonDecode(raw) as List<Object?>).whereType<String>());
      }
    } on FormatException {
      // unreadable history is simply dropped
    }
  }

  static const _key = 'recent_searches';
  static const max = 6;

  final KeyValueStore _store;
  final List<String> _items = [];

  List<String> get items => List.unmodifiable(_items);

  /// Remembers [query] (trimmed; ignored when shorter than two characters).
  void add(String query) {
    final q = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.length < 2) return;
    _items
      ..removeWhere((e) => e.toLowerCase() == q.toLowerCase())
      ..insert(0, q);
    if (_items.length > max) _items.removeRange(max, _items.length);
    _save();
  }

  void remove(String query) {
    _items.remove(query);
    _save();
  }

  void clear() {
    _items.clear();
    _save();
  }

  void _save() {
    _store.setString(_key, jsonEncode(_items));
    notifyListeners();
  }
}

final recentSearchesProvider = ChangeNotifierProvider<RecentSearches>(
    (ref) => RecentSearches(ref.watch(keyValueStoreProvider)));
