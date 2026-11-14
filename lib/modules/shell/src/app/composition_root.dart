import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/prefs/shared_prefs_store.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/modules/audio/audio.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/location/location.dart';
import 'package:jelajah_taman/modules/map/map.dart';
import 'package:jelajah_taman/modules/notify/notify.dart';

/// The ONLY place where implementations are bound to interfaces (rule R8).
///
/// As modules land, add their bindings here, e.g.:
///   locationSourceProvider.overrideWith((ref) => cfg.gpxFile != null
///       ? GpxReplaySource(cfg.gpxFile!) : GeolocatorSource()),
///   scoreFactorsProvider.overrideWithValue([DistanceFactor(), InterestFactor(), ...]),
List<Override> buildOverrides({
  required ContentRepository content,
  Clock? clock,
  BasemapData? basemap,
}) =>
    [
      contentRepositoryProvider.overrideWithValue(content),
      if (clock != null) clockProvider.overrideWithValue(clock),
      if (basemap != null) basemapProvider.overrideWithValue(basemap),
    ];

/// Loads everything the app needs before the first frame, then returns the bindings.
Future<List<Override>> bootstrap({AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  final content = await loadContentFromAssets(assets);
  BasemapData? basemap;
  try {
    basemap = await loadBasemapFromAssets(assets);
  } on Object catch (e) {
    // The map still works without it (trails + markers on paper); log, don't crash.
    AppLog.info('Basemap could not be loaded: $e');
  }
  if (content.isDummy) {
    AppLog.info(
        'Content is DUMMY data — replace with survey data before field tests.');
  }
  KeyValueStore? prefs;
  try {
    prefs = await SharedPrefsStore.load();
  } on Object catch (e) {
    AppLog.info('Settings storage unavailable, using memory: $e');
  }
  // PB07: before the first frame, so a notification tap that cold-started the app is kept.
  Override? alerts;
  try {
    alerts = await bindLocalAlertNotifier();
  } on Object catch (e) {
    // Without notifications the in-app card still works; don't block the app.
    AppLog.info('Notifications unavailable: $e');
  }
  return [
    ...buildOverrides(content: content, basemap: basemap),
    if (prefs != null) keyValueStoreProvider.overrideWithValue(prefs),
    if (alerts != null) alerts,
    // Real audio and GPS only in the app; tests keep the silent/no-GPS fallbacks (no plugins).
    bindJustAudioNarrationPlayer(),
    bindGeolocatorLocationService(),
  ];
}
