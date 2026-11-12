import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/modules/content/content.dart';

import 'application/map_scene.dart';
import 'domain/basemap.dart';

final mapSceneProvider = Provider<MapScene>(
  (ref) => MapScene.fromContent(ref.watch(contentRepositoryProvider),
      basemap: ref.watch(basemapProvider)),
);

/// The offline vector basemap. Loaded before the first frame by the composition root;
/// null (plain paper background) when not bound, e.g. in unit tests.
final basemapProvider = Provider<BasemapData?>((ref) => null);
