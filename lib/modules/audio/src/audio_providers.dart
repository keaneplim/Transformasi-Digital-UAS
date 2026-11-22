import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/providers.dart';

import 'data/flutter_tts_speaker.dart';
import 'data/media_session_narration_player.dart';
import 'domain/audio_contracts.dart';
import 'domain/narration_player.dart';
import 'domain/voice_arbiter.dart';

/// Spoken prompts (F04). Null until the composition root binds it (R8): tests, goldens and
/// anything without a TTS engine stay silent, and the guide behaves as without voice.
final ttsServiceProvider = Provider<TtsService?>((ref) => null);

/// Binding for the composition root: the VoiceArbiter over flutter_tts.
Override bindFlutterTts() => ttsServiceProvider.overrideWith((ref) {
      final voice =
          VoiceArbiter(FlutterTtsSpeaker(), clock: ref.watch(clockProvider));
      ref.onDispose(voice.dispose);
      return voice;
    });

/// Narration file player. Null until the composition root binds it (R8), so widget and
/// golden tests run without the platform plugin; callers then fall back to a silent timer.
final narrationPlayerProvider = Provider<NarrationPlayer?>((ref) => null);

/// Binding for the composition root: just_audio published as a media session (lock screen,
/// earphones; F04), disposed with the scope. The session starts right away so earphone
/// buttons reach the app before the first narration.
Override bindNarrationPlayer() => narrationPlayerProvider.overrideWith((ref) {
      final player = MediaSessionNarrationPlayer();
      unawaited(player.start());
      ref.onDispose(player.dispose);
      return player;
    });
