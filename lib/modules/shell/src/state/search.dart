import 'dart:math' as math;

import 'places.dart';

/// F05 matching (D12), simplified for the UI mock: case-insensitive partial match on the
/// name and keywords (synonyms like "wc" → toilet), plus light typo tolerance:
/// Levenshtein ≤ 1 for words of 4–6 letters, ≤ 2 for words of ≥ 7 letters.
bool matchesQuery(Place p, String query) {
  final q = _norm(query);
  if (q.isEmpty) return true;
  final haystack = [
    _norm(p.name),
    ...?p.poi?.keywords.map(_norm),
    ...?p.facility?.keywords.map(_norm),
    _norm(p.groupLabel),
  ];
  if (haystack.any((h) => h.contains(q))) return true;
  final words = {for (final h in haystack) ...h.split(' ')}..remove('');
  // Every query word must match some word (exactly, by prefix, or within the typo budget).
  return q.split(' ').where((w) => w.isNotEmpty).every((qw) => words.any((w) {
        if (w.startsWith(qw) || w.contains(qw)) return true;
        final budget = qw.length >= 7 ? 2 : (qw.length >= 4 ? 1 : 0);
        return budget > 0 && _lev(qw, w) <= budget;
      }));
}

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll('goa', 'gua')
    .trim();

int _lev(String a, String b) {
  if ((a.length - b.length).abs() > 2) return 99;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] =
          math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
    }
    prev = cur;
  }
  return prev[b.length];
}
