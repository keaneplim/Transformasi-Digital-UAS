import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/just_audio_narration_player.dart';
import 'domain/audio_contracts.dart';
import 'domain/narration_player.dart';

final ttsServiceProvider = Provider<TtsService>(
  (ref) => throw UnimplementedError('ttsServiceProvider not bound yet'),
);

final audioServiceProvider = Provider<AudioService>(
  (ref) => throw UnimplementedError('audioServiceProvider not bound yet'),
);

/// Narration file player. Null until the composition root binds it (R8), so widget and
/// golden tests run without the platform plugin; callers then fall back to a silent timer.
final narrationPlayerProvider = Provider<NarrationPlayer?>((ref) => null);

/// Binding for the composition root: the just_audio player, disposed with the scope.
Override bindJustAudioNarrationPlayer() =>
    narrationPlayerProvider.overrideWith((ref) {
      final player = JustAudioNarrationPlayer();
      ref.onDispose(player.dispose);
      return player;
    });
