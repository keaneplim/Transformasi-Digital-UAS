/// Highest first: safety (closing reminder) > navigation > trigger prompt > reminder (hydration).
enum VoicePriority { safety, navigation, triggerPrompt, reminder }

/// Named `NarrationState` to avoid clashing with audio_service's `PlaybackState`.
enum NarrationState { idle, loading, playing, paused, completed }

/// What the narration should do while a voice line is spoken (IMPLEMENTATION_PLAN F04
/// "Voice arbitration"): nothing, turn down to 20 %, or pause and resume afterwards.
enum VoiceDuck { none, duck, pause }

/// Whether the phone can speak Indonesian (risk R3).
enum VoiceSupport {
  /// An offline id-ID voice is installed.
  ready,

  /// id-ID is known to the engine but the offline voice isn't downloaded: it may only work
  /// with internet, so the park (offline) can be silent. Settings shows how to install it.
  notInstalled,

  /// No Indonesian at all: the app stays silent rather than read Indonesian with another
  /// language's voice.
  missing,
}

/// Spoken prompts (F04): trigger prompt, navigation, reminders. One voice at a time; the
/// implementation is the `VoiceArbiter`.
abstract interface class TtsService {
  /// Completes when [text] has been spoken, or dropped (stale, unsupported, failed).
  Future<void> say(String text,
      {VoicePriority priority = VoicePriority.triggerPrompt});

  /// Narration ducking while speaking; emits on change only.
  Stream<VoiceDuck> get duck;

  Future<VoiceSupport> get support;

  /// Silence now and forget everything queued (session ended).
  Future<void> stopAll();
}
