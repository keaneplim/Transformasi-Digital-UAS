import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../domain/narration_player.dart';

/// [NarrationPlayer] on just_audio. Foreground playback only for now; lock-screen and
/// earphone controls come with audio_service in T15.
class JustAudioNarrationPlayer implements NarrationPlayer {
  JustAudioNarrationPlayer() {
    _stateSub = _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) _completed.add(null);
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final StreamController<void> _completed = StreamController<void>.broadcast();
  late final StreamSubscription<ProcessingState> _stateSub;
  String? _loaded;

  @override
  Future<Duration?> open(String assetPath) async {
    if (_loaded == assetPath) return _player.duration;
    _loaded = assetPath;
    return _player.setAsset(assetPath);
  }

  @override
  Future<void> play() async {
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    // just_audio's play() completes when playback stops, so don't await it.
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    _loaded = null;
  }

  @override
  Stream<Duration> get position => _player.createPositionStream(
        minPeriod: const Duration(milliseconds: 200),
        maxPeriod: const Duration(milliseconds: 200),
      );

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Future<void> dispose() async {
    await _stateSub.cancel();
    await _completed.close();
    await _player.dispose();
  }
}
