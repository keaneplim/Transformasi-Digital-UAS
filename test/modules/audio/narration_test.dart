import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/audio/audio.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/shell/src/state/guide_controller.dart';

import '../../helpers/test_content.dart';

/// Records calls; position and completion are driven by the test.
class FakeNarrationPlayer implements NarrationPlayer {
  final calls = <String>[];
  final _pos = StreamController<Duration>.broadcast();
  final _done = StreamController<void>.broadcast();
  final _commands = StreamController<MediaCommand>.broadcast(sync: true);
  NarrationInfo? info;

  /// A lock-screen / earphone button or an interruption.
  void press(MediaCommand c) => _commands.add(c);

  void emit(Duration d) => _pos.add(d);
  void finish() => _done.add(null);

  @override
  Future<Duration?> open(String assetPath, {NarrationInfo? info}) async {
    this.info = info;
    calls.add('open $assetPath');
    return const Duration(seconds: 150);
  }

  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek ${position.inSeconds}');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> setVolume(double volume) async => calls.add('volume $volume');
  @override
  Stream<Duration> get position => _pos.stream;
  @override
  Stream<void> get completed => _done.stream;
  @override
  Stream<MediaCommand> get commands => _commands.stream;
  @override
  Future<void> dispose() async {}
}

void main() {
  late ContentRepository content;
  setUpAll(() => content = loadTestContent());

  group('narration content (F03 c)', () {
    test('every POI has a 120–180 s narration file with sources', () {
      for (final p in content.pois) {
        expect(p.audio, isNotNull, reason: p.id);
        final file = File('assets/audio/${p.audio}');
        expect(file.existsSync(), isTrue, reason: '${p.id}: ${file.path}');
        expect(file.lengthSync(), greaterThan(500 * 1024), reason: p.id);
        expect(p.audioSeconds, inInclusiveRange(120, 180), reason: p.id);
      }
    });
  });

  group('GuideController with a narration player', () {
    late FakeNarrationPlayer player;
    late ProviderContainer container;
    late GuideController demo;

    setUp(() {
      player = FakeNarrationPlayer();
      container = ProviderContainer(overrides: [
        ...buildOverrides(
            content: content, clock: FakeClock(DateTime(2026, 11, 14, 10))),
        narrationPlayerProvider.overrideWithValue(player),
      ]);
      demo = container.read(guideProvider);
    });
    tearDown(() => container.dispose());

    test('plays the POI file, follows its position, and pauses it', () async {
      final cave = demo.place('P05')!;
      demo.playAudio(cave);
      await pumpEventQueue();
      expect(player.calls,
          containsAllInOrder(['open assets/audio/p05.mp3', 'seek 0', 'play']));
      expect(demo.audioLength(cave), 150); // duration from the file, not JSON

      player.emit(const Duration(seconds: 42));
      await pumpEventQueue();
      expect(demo.audioPos, 42);

      demo.pauseAudio();
      expect(player.calls.last, 'pause');
      expect(demo.audioPlaying, isFalse);
    });

    test('seek and skip go to the player; completion stops playing', () async {
      final cave = demo.place('P06')!;
      demo.playAudio(cave);
      await pumpEventQueue();
      demo.seekAudio(0.5);
      expect(player.calls.last, 'seek 75');
      demo.skipAudio(10);
      expect(player.calls.last, 'seek 85');

      player.finish();
      await pumpEventQueue();
      expect(demo.audioPlaying, isFalse);
      expect(demo.audioProgress, 1);
    });

    test(
        'switching POI pauses the previous file and opens the new one; '
        'only stopAudio ends the media session', () async {
      demo.playAudio(demo.place('P02')!);
      await pumpEventQueue();
      demo.playAudio(demo.place('P03')!);
      await pumpEventQueue();
      expect(
          player.calls,
          containsAllInOrder([
            'open assets/audio/p02.mp3',
            'pause',
            'open assets/audio/p03.mp3'
          ]));
      expect(player.calls, isNot(contains('stop')),
          reason: 'a stop would restart the media service while locked');
      expect(player.info?.title, demo.place('P03')!.name,
          reason: 'the lock screen shows the POI name');
      demo.stopAudio();
      expect(player.calls.last, 'stop');
    });
  });

  group('F04 AC1 lock screen / earphone buttons (MediaCommand)', () {
    late FakeNarrationPlayer player;
    late ProviderContainer container;
    late GuideController demo;

    setUp(() {
      player = FakeNarrationPlayer();
      container = ProviderContainer(overrides: [
        ...buildOverrides(
            content: content, clock: FakeClock(DateTime(2026, 11, 14, 10))),
        narrationPlayerProvider.overrideWithValue(player),
      ]);
      demo = container.read(guideProvider);
    });
    tearDown(() => container.dispose());

    test('pause and play from the lock screen pause and resume the narration',
        () async {
      final cave = demo.place('P05')!;
      demo.playAudio(cave);
      await pumpEventQueue();
      player.press(MediaCommand.pause);
      expect(demo.audioPlaying, isFalse);
      expect(player.calls.last, 'pause');
      player.press(MediaCommand.play);
      await pumpEventQueue();
      expect(demo.audioPlaying, isTrue);
      expect(demo.nowPlaying?.id, 'P05');
      expect(player.calls.last, 'play');
    });

    test('rewind / fast-forward move 10 s; stop ends the narration', () async {
      demo.playAudio(demo.place('P06')!);
      await pumpEventQueue();
      demo.seekAudio(0.5); // 75 s
      player.press(MediaCommand.fastForward);
      expect(player.calls.last, 'seek 85');
      player.press(MediaCommand.rewind);
      expect(player.calls.last, 'seek 75');
      player.press(MediaCommand.stop);
      expect(demo.nowPlaying, isNull);
      expect(player.calls.last, 'stop');
    });

    test(
        'UC-F04-1 step 3: earphone play with a trigger waiting → listens to it '
        '(visited, listened)', () async {
      demo.startSession();
      final cave = demo.place('P05')!;
      demo.triggerNow(cave);
      expect(demo.pendingTrigger?.id, 'P05');
      player.press(MediaCommand.play);
      await pumpEventQueue();
      expect(demo.pendingTrigger, isNull);
      expect(demo.nowPlaying?.id, 'P05');
      expect(demo.audioPlaying, isTrue);
      expect(demo.visited, contains('P05'));
      expect(demo.visitLog.last.how, 'listened');
      demo.stopAudio();
    });

    test(
        'a call: paused, and resumed after it — the narration, never a new trigger',
        () async {
      demo.startSession();
      demo.playAudio(demo.place('P02')!);
      await pumpEventQueue();
      player.press(MediaCommand.pause); // call starts (InterruptionPolicy)
      demo.triggerNow(demo.place('P05')!); // meanwhile a POI triggers
      player.press(MediaCommand.resume); // call ends
      await pumpEventQueue();
      expect(demo.nowPlaying?.id, 'P02');
      expect(demo.audioPlaying, isTrue);
      expect(demo.pendingTrigger?.id, 'P05',
          reason: 'still waiting for an answer');
      demo.stopAudio();
    });

    test('play with nothing loaded and no trigger does nothing', () {
      player.press(MediaCommand.play);
      player.press(MediaCommand.resume);
      expect(demo.nowPlaying, isNull);
      expect(player.calls, isEmpty);
    });
  });

  group('InterruptionPolicy', () {
    test('a call pauses a playing narration and resumes it after', () {
      final p = InterruptionPolicy();
      expect(p.on(AudioInterruption.transientBegin, playing: true),
          MediaCommand.pause);
      expect(p.on(AudioInterruption.transientEnd, playing: false),
          MediaCommand.resume);
    });

    test('never resumes what the visitor paused', () {
      final p = InterruptionPolicy();
      expect(p.on(AudioInterruption.transientBegin, playing: false), isNull);
      expect(p.on(AudioInterruption.transientEnd, playing: false), isNull);

      expect(p.on(AudioInterruption.transientBegin, playing: true),
          MediaCommand.pause);
      p.userActed(); // visitor pressed play/pause during the call
      expect(p.on(AudioInterruption.transientEnd, playing: false), isNull);
    });

    test('earphones unplugged or another app taking over: pause, no resume',
        () {
      final p = InterruptionPolicy();
      expect(p.on(AudioInterruption.becomingNoisy, playing: true),
          MediaCommand.pause);
      expect(p.on(AudioInterruption.becomingNoisy, playing: false), isNull);
      expect(p.on(AudioInterruption.transientBegin, playing: true),
          MediaCommand.pause);
      expect(p.on(AudioInterruption.permanentBegin, playing: false), isNull);
      expect(p.on(AudioInterruption.transientEnd, playing: false), isNull,
          reason: 'a permanent loss cancels the pending resume');
    });

    test('ducking is left to Android', () {
      final p = InterruptionPolicy();
      expect(p.on(AudioInterruption.duckBegin, playing: true), isNull);
      expect(p.on(AudioInterruption.otherEnd, playing: true), isNull);
    });
  });
}
