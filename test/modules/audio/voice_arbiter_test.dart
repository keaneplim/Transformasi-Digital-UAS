import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/audio/audio.dart';

/// A TTS engine the test finishes by hand: each line speaks until [end] (or [stop]).
class FakeSpeaker implements Speaker {
  FakeSpeaker({this.supportResult = VoiceSupport.ready});

  VoiceSupport supportResult;
  final spoken = <String>[];
  final stops = <String>[];
  Completer<void>? _line;
  String? failOn;

  String? get current => _line == null ? null : spoken.last;

  void end() {
    final l = _line;
    _line = null;
    l?.complete();
  }

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    if (text == failOn) throw StateError('engine failed');
    final c = Completer<void>();
    _line = c;
    return c.future;
  }

  @override
  Future<void> stop() async {
    if (_line != null) stops.add(spoken.last);
    end();
  }

  @override
  Future<VoiceSupport> support() async => supportResult;
}

Future<void> flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeSpeaker speaker;
  late FakeClock clock;
  late VoiceArbiter voice;
  late List<VoiceDuck> ducks;

  setUp(() {
    speaker = FakeSpeaker();
    clock = FakeClock(DateTime(2026, 11, 20, 10));
    voice = VoiceArbiter(speaker, clock: clock);
    ducks = [];
    voice.duck.listen(ducks.add);
  });

  test('speaks at once when idle and completes when the line ends', () async {
    var done = false;
    unawaited(voice.say('Anda tiba di Gua Jepang.').then((_) => done = true));
    await flush();
    expect(speaker.current, 'Anda tiba di Gua Jepang.');
    expect(done, isFalse);
    speaker.end();
    await flush();
    expect(done, isTrue);
    expect(voice.speaking, isNull);
  });

  test('a lower or equal priority waits; then by priority, then FIFO',
      () async {
    unawaited(voice.say('prompt', priority: VoicePriority.triggerPrompt));
    await flush();
    unawaited(voice.say('minum 1', priority: VoicePriority.reminder));
    unawaited(voice.say('prompt 2', priority: VoicePriority.triggerPrompt));
    unawaited(voice.say('minum 2', priority: VoicePriority.reminder));
    await flush();
    expect(speaker.current, 'prompt', reason: 'not interrupted');
    expect(voice.waiting, ['prompt 2', 'minum 1', 'minum 2']);
    for (var i = 0; i < 4; i++) {
      speaker.end();
      await flush();
    }
    expect(speaker.spoken, ['prompt', 'prompt 2', 'minum 1', 'minum 2']);
  });

  test('a higher priority interrupts; the interrupted line is said right after',
      () async {
    var promptDone = false;
    unawaited(voice
        .say('Anda tiba di Gua Belanda. Ingin mendengar ceritanya?')
        .then((_) => promptDone = true));
    unawaited(voice.say('minum', priority: VoicePriority.reminder));
    await flush();
    unawaited(voice.say('Belok kiri.', priority: VoicePriority.navigation));
    await flush();
    expect(speaker.stops,
        ['Anda tiba di Gua Belanda. Ingin mendengar ceritanya?']);
    expect(speaker.current, 'Belok kiri.');
    expect(promptDone, isFalse, reason: 'interrupted is not done');
    speaker.end();
    await flush();
    expect(speaker.current,
        'Anda tiba di Gua Belanda. Ingin mendengar ceritanya?');
    speaker.end();
    await flush();
    expect(promptDone, isTrue);
    expect(speaker.current, 'minum');
  });

  test('a line waiting longer than 30 s is dropped (stale direction)',
      () async {
    unawaited(voice.say('prompt'));
    await flush();
    var staleDone = false;
    unawaited(voice
        .say('Belok kanan.', priority: VoicePriority.reminder)
        .then((_) => staleDone = true));
    clock.setNow(clock.now().add(const Duration(seconds: 31)));
    speaker.end();
    await flush();
    expect(speaker.spoken, ['prompt'], reason: 'the old line is not said');
    expect(staleDone, isTrue, reason: 'a dropped line still completes');
  });

  test('the same text already waiting or speaking is not added twice',
      () async {
    unawaited(
        voice.say('Rute diperbarui.', priority: VoicePriority.navigation));
    unawaited(
        voice.say('Rute diperbarui.', priority: VoicePriority.navigation));
    unawaited(voice.say('x', priority: VoicePriority.reminder));
    unawaited(voice.say('x', priority: VoicePriority.reminder));
    await flush();
    expect(voice.waiting, ['x']);
    speaker.end();
    await flush();
    speaker.end();
    await flush();
    expect(speaker.spoken, ['Rute diperbarui.', 'x']);
  });

  test('narration ducks under normal lines and pauses for a safety line',
      () async {
    unawaited(voice.say('prompt'));
    await flush();
    expect(ducks, [VoiceDuck.duck]);
    unawaited(voice.say('Kawasan tutup pukul 16.00.',
        priority: VoicePriority.safety));
    await flush();
    expect(ducks, [VoiceDuck.duck, VoiceDuck.pause]);
    speaker.end(); // safety line
    await flush();
    expect(speaker.current, 'prompt');
    expect(ducks.last, VoiceDuck.pause,
        reason:
            'stays paused until the queue is empty (no resume/pause flapping)');
    speaker.end();
    await flush();
    expect(ducks, [VoiceDuck.duck, VoiceDuck.pause, VoiceDuck.none]);
  });

  test('a failing engine drops the line and goes on', () async {
    speaker.failOn = 'rusak';
    var done = false;
    unawaited(voice.say('rusak').then((_) => done = true));
    unawaited(voice.say('berikutnya', priority: VoicePriority.reminder));
    await flush();
    expect(done, isTrue);
    expect(speaker.current, 'berikutnya');
  });

  test('no Indonesian voice: silent, never another language', () async {
    speaker.supportResult = VoiceSupport.missing;
    var done = false;
    unawaited(voice.say('Anda tiba di Kolam Pakar.').then((_) => done = true));
    await flush();
    expect(speaker.spoken, isEmpty);
    expect(done, isTrue);
    expect(await voice.support, VoiceSupport.missing);
  });

  test('a voice that is only online still speaks (Settings shows the hint)',
      () async {
    speaker.supportResult = VoiceSupport.notInstalled;
    unawaited(voice.say('halo'));
    await flush();
    expect(speaker.current, 'halo');
  });

  test('stopAll silences and forgets the queue', () async {
    unawaited(voice.say('a'));
    unawaited(voice.say('b'));
    await flush();
    await voice.stopAll();
    await flush();
    expect(speaker.spoken, ['a']);
    expect(voice.waiting, isEmpty);
    expect(voice.speaking, isNull);
    expect(ducks.last, VoiceDuck.none);
  });
}
