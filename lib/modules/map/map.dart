/// Module `map` (level 3, owner B) — public front door.
///
/// Explore map UI03 (A01): the bundled offline vector basemap (OpenStreetMap + terrain, made by
/// tools/osm_to_basemap.py), optional online satellite imagery, trails, POI/facility markers,
/// geofence rings, route line, user dot. Owns flutter_map + latlong2 (R5).
/// Spec: IMPLEMENTATION_PLAN.md A01, ADR-008. Template: docs/engineering/ARCHITECTURE.md §7.
/// Export only what other modules need; keep everything else in src/.
library;

export 'src/application/basemap_loader.dart'
    show basemapAsset, loadBasemapFromAssets;
export 'src/application/map_scene.dart' show MapScene;
export 'src/domain/basemap.dart' show BasemapData;
export 'src/domain/map_geometry.dart' show GeoBounds;
export 'src/map_providers.dart' show basemapProvider, mapSceneProvider;
export 'src/ui/explore_map.dart' show ExploreMap;
export 'src/ui/park_map_view.dart'
    show MapPin, ParkMapController, ParkMapView, PlaceMarker, UserDot;
