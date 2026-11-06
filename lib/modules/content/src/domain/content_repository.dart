import 'models.dart';

/// All static content, loaded once at startup and immutable afterwards (A05).
///
/// A concrete class on purpose: there is only one implementation (ADR-007).
class ContentRepository {
  ContentRepository({
    required List<Poi> pois,
    required List<Facility> facilities,
    required List<TrailRoute> routes,
    required this.park,
    required this.graph,
    this.isDummy = false,
  })  : pois = List.unmodifiable(pois),
        facilities = List.unmodifiable(facilities),
        routes = List.unmodifiable(routes),
        _poiById = {for (final p in pois) p.id: p},
        _facilityById = {for (final f in facilities) f.id: f},
        _poiByQr = {
          for (final p in pois)
            if (p.qrCode != null) p.qrCode!: p,
        };

  /// Parses the five decoded JSON files (assets/content/*.json).
  factory ContentRepository.fromJson({
    required Map<String, Object?> pois,
    required Map<String, Object?> facilities,
    required Map<String, Object?> routes,
    required Map<String, Object?> park,
    required Map<String, Object?> graph,
  }) {
    List<Map<String, Object?>> list(Map<String, Object?> file, String key) => [
          for (final item in file[key]! as List<Object?>)
            item! as Map<String, Object?>,
        ];
    final anyDummy = [pois, facilities, routes, park, graph]
        .any((file) => file['dummy'] == true);
    return ContentRepository(
      pois: list(pois, 'pois').map(Poi.fromJson).toList(),
      facilities:
          list(facilities, 'facilities').map(Facility.fromJson).toList(),
      routes: list(routes, 'routes').map(TrailRoute.fromJson).toList(),
      park: ParkConfig.fromJson(park),
      graph: TrailGraph.fromJson(graph),
      isDummy: anyDummy,
    );
  }

  final List<Poi> pois;
  final List<Facility> facilities;
  final List<TrailRoute> routes;
  final ParkConfig park;
  final TrailGraph graph;

  /// True while any content file is still survey-free dummy data. The UI shows a banner.
  final bool isDummy;

  final Map<String, Poi> _poiById;
  final Map<String, Facility> _facilityById;
  final Map<String, Poi> _poiByQr;

  Poi? poiById(String id) => _poiById[id];

  Facility? facilityById(String id) => _facilityById[id];

  /// Resolves a scanned QR payload such as `jelajahtaman://poi/P05` (A02). Null if unknown.
  Poi? poiByQr(String payload) {
    var normalized = payload.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return _poiByQr[normalized];
  }

  Poi get gate => _poiById[park.gatePoiId]!;
}
