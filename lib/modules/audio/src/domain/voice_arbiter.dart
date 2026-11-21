import 'dart:async';

import 'package:jelajah_taman/core/core.dart';

import 'audio_contracts.dart';

/// The text-to-speech engine, reduced to what the arbiter needs. The flutter_tts adapter
/// lives in `src/data/`; tests use a fake.
abstract interface class Speaker {
  /// Completes when the utterance has ended: spoken, stopped by [stop], or failed (may throw).
  Future<void> speak(String text);

  Future<void> stop();

  Future<VoiceSupport> support();
}

/// F04 voice arbitration (IMPLEMENTATION_PLAN F04 "Voice arbitration", owner moved to B):
/// - one voice at a time;
/// - a higher [VoicePriority] interrupts the current line, which is spoken again right after
///   (navigation first, then the prompt);
/// - otherwise lines wait, by priority, then in arrival order;
/// - a line still waiting after [staleAfter] is dropped (an old turn instruction misleads);
/// - the same text already waiting or speaking isn't added twice;
/// - while speaking, [duck] asks the narration to turn down, or to pause for a safety line.
/// A failing engine drops the line and goes on; it never blocks the queue.
class VoiceArbiter implements TtsService {
  VoiceArbiter(
    this._speaker, {
    required Clock clock,
    this.staleAfter = const Duration(seconds: 30),
  }) : _clock = clock;

  final Speaker _speaker;
  final Clock _clock;
  final Duration staleAfter;

  final List<_Line> _queue = [];
  final StreamController<VoiceDuck> _duck =
      StreamController<VoiceDuck>.broadcast();
  _Line? _current;
  bool _running = false;
  int _seq = 0;
  VoiceDuck _duckState = VoiceDuck.none;
  Future<VoiceSupport>? _support;

  @override
  Stream<VoiceDuck> get duck => _duck.stream;

  /// Current ducking, for a listener that subscribes late.
  VoiceDuck get ducking => _duckState;

  /// Asked once; the answer doesn't change while the app runs.
  @override
  Future<VoiceSupport> get support => _support ??= _speaker.support().then(
        (s) => s,
        onError: (Object e) {
          AppLog.info('Voice support check failed: $e');
          return VoiceSupport.missing;
        },
      );

  /// What is being spoken now, or null.
  String? get speaking => _current?.text;

  /// Waiting lines in the order they will be spoken.
  List<String> get waiting => [for (final l in _queue) l.text];

  @override
  Future<void> say(String text,
      {VoicePriority priority = VoicePriority.triggerPrompt}) {
    final t = text.trim();
    if (t.isEmpty) return Future.value();
    for (final l in [if (_current != null) _current!, ..._queue]) {
      if (l.text == t) return l.done.future;
    }
    final line = _Line(t, priority, _clock.now(), _seq++);
    _insert(line);
    final cur = _current;
    if (cur != null && priority.index < cur.priority.index) {
      cur.interrupted = true;
      _insert(
          cur); // keeps its place: earlier than anything of its priority that came later
      unawaited(_stopSpeaker());
    }
    unawaited(_pump());
    return line.done.future;
  }

  @override
  Future<void> stopAll() async {
    final all = [..._queue];
    _queue.clear();
    final cur = _current;
    if (cur != null) {
      cur.cancelled = true;
      await _stopSpeaker();
    }
    for (final l in all) {
      l.finish();
    }
  }

  void _insert(_Line line) {
    final i = _queue.indexWhere((q) =>
        q.priority.index > line.priority.index ||
        (q.priority == line.priority && q.seq > line.seq));
    i < 0 ? _queue.add(line) : _queue.insert(i, line);
  }

  Future<void> _stopSpeaker() async {
    try {
      await _speaker.stop();
    } on Object catch (e) {
      AppLog.info('Voice stop failed: $e');
    }
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty) {
        final line = _queue.removeAt(0);
        if (_clock.now().difference(line.queuedAt) > staleAfter) {
          line.finish();
          continue;
        }
        // Current from here on, so say() sees it while the support check is awaited
        // (duplicates, interruption).
        _current = line..interrupted = false;
        final supported = await support != VoiceSupport.missing;
        if (line.cancelled || !supported) {
          _current = null;
          line.finish();
          continue;
        }
        if (line.interrupted) {
          _current = null; // already back in the queue behind the higher line
          continue;
        }
        // Stays paused until the queue is empty: no pause/resume flapping.
        _setDuck(line.priority == VoicePriority.safety ||
                _duckState == VoiceDuck.pause
            ? VoiceDuck.pause
            : VoiceDuck.duck);
        try {
          await _speaker.speak(line.text);
        } on Object catch (e) {
          AppLog.info('Voice line failed: $e');
        }
        _current = null;
        if (!line.interrupted || line.cancelled) {
          _queue.remove(line);
          line.finish();
        }
      }
    } finally {
      _running = false;
      _setDuck(VoiceDuck.none);
    }
  }

  void _setDuck(VoiceDuck d) {
    if (d == _duckState) return;
    _duckState = d;
    _duck.add(d);
  }

  Future<void> dispose() async {
    await stopAll();
    await _duck.close();
  }
}

class _Line {
  _Line(this.text, this.priority, this.queuedAt, this.seq);

  final String text;
  final VoicePriority priority;
  final DateTime queuedAt;
  final int seq;
  final Completer<void> done = Completer<void>();
  bool interrupted = false;
  bool cancelled = false;

  void finish() {
    if (!done.isCompleted) done.complete();
  }
}
