import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/modules/audio/audio.dart';
import 'package:jelajah_taman/modules/content/content.dart';

/// The ONLY place where implementations are bound to interfaces (rule R8).
///
/// As modules land, add their bindings here, e.g.:
///   locationSourceProvider.overrideWith((ref) => cfg.gpxFile != null
///       ? GpxReplaySource(cfg.gpxFile!) : GeolocatorSource()),
///   scoreFactorsProvider.overrideWithValue([DistanceFactor(), InterestFactor(), ...]),
List<Override> buildOverrides({
  required ContentRepository content,
  Clock? clock,
}) =>
    [
      contentRepositoryProvider.overrideWithValue(content),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ];

/// Loads everything the app needs before the first frame, then returns the bindings.
Future<List<Override>> bootstrap({AssetBundle? bundle}) async {
  final content = await loadContentFromAssets(bundle ?? rootBundle);
  if (content.isDummy) {
    AppLog.info(
        'Content is DUMMY data — replace with survey data before field tests.');
  }
  return [
    ...buildOverrides(content: content),
    // Real audio only in the app; tests keep the silent fallback (no platform plugin).
    bindJustAudioNarrationPlayer(),
  ];
}
