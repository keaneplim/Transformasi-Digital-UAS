import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/modules/content/content.dart';

import 'application/map_scene.dart';

final mapSceneProvider = Provider<MapScene>(
  (ref) => MapScene.fromContent(ref.watch(contentRepositoryProvider)),
);
