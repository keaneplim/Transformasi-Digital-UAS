/// Module `audio` (level 1, owner C) — public front door.
///
/// Narration playback (recorded file or TTS fallback), TTS prompts, VoiceArbiter
/// (priority / duck / queue), media session for lock-screen and earphone controls.
/// Owns plugins `just_audio`, `audio_service`, `flutter_tts` (in src/data/ only).
/// Publishes E5 PoiEngaged(listened/autoplay), E7 PoiFinished(narrationDone).
/// Spec: IMPLEMENTATION_PLAN.md F03 (player), F04.
library;

export 'src/audio_providers.dart';
export 'src/domain/audio_contracts.dart';
export 'src/domain/narration_player.dart';
