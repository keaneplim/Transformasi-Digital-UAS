/// Highest first: safety (closing reminder) > navigation > trigger prompt > reminder (hydration).
enum VoicePriority { safety, navigation, triggerPrompt, reminder }

/// Named `NarrationState` to avoid clashing with audio_service's `PlaybackState`.
enum NarrationState { idle, loading, playing, paused, completed }

abstract interface class TtsService {
  Future<void> say(String text,
      {VoicePriority priority = VoicePriority.triggerPrompt});
}

abstract interface class AudioService {
  /// Recorded file, or TTS reading the POI text when `audio` is null.
  Future<void> playNarration(String poiId);

  Future<void> pause();

  Future<void> resume();

  Future<void> replay();

  Stream<NarrationState> get state;
}
