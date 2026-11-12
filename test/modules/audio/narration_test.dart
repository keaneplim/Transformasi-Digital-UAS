import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/audio/audio.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/shell/src/demo/demo_controller.dart';

import '../../helpers/test_content.dart';

/// Records calls; position and completion are driven by the test.
class FakeNarrationPlayer implements NarrationPlayer {
  final calls = <String>[];
  final _pos = StreamController<Duration>.broadcast();
  final _done = StreamController<void>.broadcast();

  void emit(Duration d) => _pos.add(d);
  void finish() => _done.add(null);

  @override
  Future<Duration?> open(String assetPath) async {
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
  Stream<Duration> get position => _pos.stream;
  @override
  Stream<void> get completed => _done.stream;
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

  group('DemoController with a narration player', () {
    late FakeNarrationPlayer player;
    late ProviderContainer container;
    late DemoController demo;

    setUp(() {
      player = FakeNarrationPlayer();
      container = ProviderContainer(overrides: [
        ...buildOverrides(
            content: content, clock: FakeClock(DateTime(2026, 11, 14, 10))),
        narrationPlayerProvider.overrideWithValue(player),
      ]);
      demo = container.read(demoProvider);
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

    test('switching POI stops the previous file and opens the new one',
        () async {
      demo.playAudio(demo.place('P02')!);
      await pumpEventQueue();
      demo.playAudio(demo.place('P03')!);
      await pumpEventQueue();
      expect(
          player.calls,
          containsAllInOrder([
            'open assets/audio/p02.mp3',
            'stop',
            'open assets/audio/p03.mp3'
          ]));
      demo.stopAudio();
    });
  });
}
