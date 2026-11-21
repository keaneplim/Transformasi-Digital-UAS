/// Plays one bundled narration file (assets/audio/pxx.mp3). Pure contract (R4); the adapter
/// (just_audio + audio_service media session) lives in `src/data/`. The guide (shell) drives
/// it; spoken prompts duck it through [setVolume] (VoiceArbiter, F04).
///
/// F04 lock screen / earphones: buttons outside the app don't touch the player. They arrive
/// as [commands] and the guide answers them through the same methods as its own buttons, so
/// the app and the lock screen never disagree about what is playing.
abstract interface class NarrationPlayer {
  /// Loads [assetPath] (e.g. `assets/audio/p05.mp3`) and returns its duration when known.
  /// [info] is what the lock screen and the media notification show.
  Future<Duration?> open(String assetPath, {NarrationInfo? info});

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  /// Unloads the file and ends the media session (notification gone). Not used to switch
  /// files: [open] replaces the current one, so the session stays alive between POIs.
  Future<void> stop();

  /// 0–1. Spoken prompts turn the narration down to 0.2 and back to 1 (F04).
  Future<void> setVolume(double volume);

  /// Current playback position, emitted while playing (≈5 times per second).
  Stream<Duration> get position;

  /// Emits once each time the loaded file plays to its end.
  Stream<void> get completed;

  /// Lock screen, notification, earphone / Bluetooth buttons, and audio interruptions
  /// (phone call, earphones unplugged), for the guide to act on.
  Stream<MediaCommand> get commands;

  Future<void> dispose();
}

/// What the lock screen shows for a narration.
class NarrationInfo {
  const NarrationInfo({required this.id, required this.title, this.subtitle});

  /// POI id (e.g. `P05`).
  final String id;
  final String title;
  final String? subtitle;
}

/// A request from outside the app's screens (F04 AC1: pause/resume without opening the app).
enum MediaCommand {
  /// Play button (lock screen, notification, earphone click while paused).
  play,

  /// Pause button, earphone click while playing, earphones unplugged, a call coming in.
  pause,

  /// The interruption that paused the narration is over (call ended): continue the same
  /// narration. Unlike [play] this never starts a newly triggered POI.
  resume,

  /// The media notification was closed.
  stop,

  /// 10 s back / forward.
  rewind,
  fastForward,
}

/// Audio focus events in plain terms (adapter maps the plugin's events onto these).
enum AudioInterruption {
  /// Another app needs the audio for a while (incoming call, navigation prompt that pauses).
  transientBegin,

  /// Another app may play over us at lower volume. Android lowers our volume itself.
  duckBegin,

  /// Another app took the audio for good (music app started).
  permanentBegin,

  /// The transient interruption is over.
  transientEnd,

  /// A duck or permanent interruption is over (no automatic resume).
  otherEnd,

  /// Headphones / Bluetooth disconnected: the narration must not suddenly play out loud.
  becomingNoisy,
}

/// Turns interruptions into [MediaCommand]s (pure, tested). Resumes only what an
/// interruption paused, never something the visitor paused.
class InterruptionPolicy {
  bool _pausedByInterruption = false;

  MediaCommand? on(AudioInterruption e, {required bool playing}) {
    switch (e) {
      case AudioInterruption.transientBegin:
        if (!playing) return null;
        _pausedByInterruption = true;
        return MediaCommand.pause;
      case AudioInterruption.permanentBegin || AudioInterruption.becomingNoisy:
        _pausedByInterruption = false;
        return playing ? MediaCommand.pause : null;
      case AudioInterruption.duckBegin || AudioInterruption.otherEnd:
        return null;
      case AudioInterruption.transientEnd:
        final resume = _pausedByInterruption;
        _pausedByInterruption = false;
        return resume ? MediaCommand.resume : null;
    }
  }

  /// The visitor acted (play/pause) during the interruption: their choice wins.
  void userActed() => _pausedByInterruption = false;
}

/// Asset path of a POI narration file name as stored in `pois.json` (`audio`).
String narrationAsset(String fileName) => 'assets/audio/$fileName';
