import 'dart:math' as math;

/// T07: a POI text prepared to be read aloud by the voice when its recording is missing or
/// fails. Split into sentences (each one a line for the `VoiceArbiter`, so a prompt or a turn
/// instruction can cut in and the sentence is read again), with an estimated start time for
/// each, so the player shows progress and can seek to a sentence.
class NarrationScript {
  NarrationScript._(this.sentences, this.starts, this.length);

  /// [wordsPerSecond]: Indonesian TTS at the normal rate reads about 2,4 words a second.
  factory NarrationScript.fromText(String text, {double wordsPerSecond = 2.4}) {
    final sentences = split(text);
    final starts = <double>[];
    var t = 0.0;
    for (final s in sentences) {
      starts.add(t);
      // A short pause between sentences.
      t += _words(s) / wordsPerSecond + 0.4;
    }
    return NarrationScript._(
        List.unmodifiable(sentences), List.unmodifiable(starts), t);
  }

  final List<String> sentences;

  /// Estimated start of each sentence, in seconds.
  final List<double> starts;

  /// Estimated length of the whole reading, in seconds.
  final double length;

  bool get isEmpty => sentences.isEmpty;

  /// Estimated end of sentence [i].
  double endOf(int i) => i + 1 < starts.length ? starts[i + 1] : length;

  /// The sentence playing at [seconds]; the last one at or after the end.
  int indexAt(double seconds) {
    if (sentences.isEmpty) return 0;
    for (var i = sentences.length - 1; i > 0; i--) {
      if (seconds >= starts[i]) return i;
    }
    return 0;
  }

  static int _words(String s) =>
      math.max(1, s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length);

  /// Sentences of [text]: split after `.`, `!`, `?` or `…` followed by a space; empty pieces and
  /// placeholders (`[ISI] …`, `[VERIFIKASI]`) are never read aloud.
  static List<String> split(String text) {
    final clean = text
        .replaceAll(RegExp(r'\[(ISI|VERIFIKASI)\][^.!?…]*[.!?…]?'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return const [];
    return [
      for (final s in clean.split(RegExp(r'(?<=[.!?…])\s+')))
        if (s.trim().isNotEmpty) s.trim(),
    ];
  }
}
