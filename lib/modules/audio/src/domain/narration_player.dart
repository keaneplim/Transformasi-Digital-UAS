/// Plays one bundled narration file (assets/audio/pxx.mp3). Pure contract (R4); the
/// just_audio adapter lives in `src/data/`. `AudioService` (T07) builds on this for POI
/// narration and adds the TTS fallback, the VoiceArbiter and the media session (T15).
abstract interface class NarrationPlayer {
  /// Loads [assetPath] (e.g. `assets/audio/p05.mp3`) and returns its duration when known.
  Future<Duration?> open(String assetPath);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> stop();

  /// Current playback position, emitted while playing (≈5 times per second).
  Stream<Duration> get position;

  /// Emits once each time the loaded file plays to its end.
  Stream<void> get completed;

  Future<void> dispose();
}

/// Asset path of a POI narration file name as stored in `pois.json` (`audio`).
String narrationAsset(String fileName) => 'assets/audio/$fileName';
