import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/audio_contracts.dart';

final ttsServiceProvider = Provider<TtsService>(
  (ref) => throw UnimplementedError('ttsServiceProvider not bound yet'),
);

final audioServiceProvider = Provider<AudioService>(
  (ref) => throw UnimplementedError('audioServiceProvider not bound yet'),
);
