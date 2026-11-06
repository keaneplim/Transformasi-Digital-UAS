/// Module `map` (level 3, owner B) — public front door.
///
/// Explore map UI03: tile layer (MBTiles, T05), trails, POI/facility markers, geofence rings,
/// route line, user dot. Owns flutter_map + the MBTiles provider.
/// Spec: IMPLEMENTATION_PLAN.md A01. Template: docs/engineering/ARCHITECTURE.md §7.
/// Export only what other modules need; keep everything else in src/.
library;

export 'src/application/map_scene.dart' show MapScene;
export 'src/domain/map_geometry.dart' show GeoBounds;
export 'src/map_providers.dart' show mapSceneProvider;
export 'src/ui/explore_map.dart' show ExploreMap;
