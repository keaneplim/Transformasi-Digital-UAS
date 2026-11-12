import 'package:jelajah_taman/core/core.dart';

// Hand-written models (ADR-002: no code generation). Schema: IMPLEMENTATION_PLAN.md §3.

List<String> _strings(Object? value) => value == null
    ? const []
    : List<String>.unmodifiable(value as List<Object?>);

double _double(Object? value) => (value as num).toDouble();

class Poi {
  const Poi({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
    required this.isDummyCoordinate,
    required this.radiusM,
    required this.triggers,
    required this.qrCode,
    required this.visitMinutes,
    required this.difficulty,
    required this.graphNode,
    required this.keywords,
    required this.text,
    this.draftText,
    required this.keyFacts,
    required this.images,
    required this.audio,
    required this.audioSeconds,
    required this.routes,
    required this.safetyNote,
    required this.sources,
  });

  factory Poi.fromJson(Map<String, Object?> j) => Poi(
        id: j['id']! as String,
        name: j['name']! as String,
        category: j['category']! as String,
        position: GeoPoint(_double(j['lat']), _double(j['lng'])),
        isDummyCoordinate: j['coord_source'] == 'DUMMY',
        radiusM: _double(j['radius_m']),
        triggers: _strings(j['trigger']),
        qrCode: j['qr_code'] as String?,
        visitMinutes: j['visit_minutes']! as int,
        difficulty: j['difficulty']! as int,
        graphNode: j['graph_node']! as String,
        keywords: _strings(j['keywords']),
        text: j['text']! as String,
        draftText: j['draft_text'] as String?,
        keyFacts: _strings(j['key_facts']),
        images: _strings(j['images']),
        audio: j['audio'] as String?,
        audioSeconds: j['audio_seconds'] as int?,
        routes: _strings(j['routes']),
        safetyNote: j['safety_note'] as String?,
        sources: _strings(j['sources']),
      );

  final String id;
  final String name;

  /// informasi | sejarah | alam | rekreasi
  final String category;
  final GeoPoint position;
  final bool isDummyCoordinate;
  final double radiusM;

  /// "gps", "qr"
  final List<String> triggers;
  final String? qrCode;
  final int visitMinutes;

  /// 1 easy · 2 medium · 3 hard
  final int difficulty;
  final String graphNode;
  final List<String> keywords;
  final String text;

  /// Unverified, observational UI mock copy (dummy content only). Never a source of facts.
  final String? draftText;
  final List<String> keyFacts;
  final List<String> images;

  /// File name in assets/audio/, or null → TTS fallback reads [text].
  final String? audio;
  final int? audioSeconds;
  final List<String> routes;
  final String? safetyNote;
  final List<String> sources;

  bool get hasQr => triggers.contains('qr');
  bool get isPlaceholderText => text.startsWith('[ISI]');

  /// Text for the UI: the real text, or the draft while the real text is still a placeholder.
  String get displayText => isPlaceholderText ? (draftText ?? '') : text;
}

class Facility {
  const Facility({
    required this.id,
    required this.type,
    required this.name,
    required this.position,
    required this.isDummyCoordinate,
    required this.graphNode,
    required this.keywords,
    this.images = const [],
  });

  factory Facility.fromJson(Map<String, Object?> j) => Facility(
        id: j['id']! as String,
        type: j['type']! as String,
        name: j['name']! as String,
        position: GeoPoint(_double(j['lat']), _double(j['lng'])),
        isDummyCoordinate: j['coord_source'] == 'DUMMY',
        graphNode: j['graph_node']! as String,
        keywords: _strings(j['keywords']),
        images: _strings(j['images']),
      );

  final String id;

  /// toilet | musala | warung | pos_petugas | istirahat
  final String type;
  final String name;
  final GeoPoint position;
  final bool isDummyCoordinate;
  final String graphNode;
  final List<String> keywords;
  final List<String> images;
}

class TrailRoute {
  const TrailRoute({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.distanceM,
    required this.ascentM,
    required this.durationMin,
    required this.poiSequence,
    required this.nodePath,
  });

  factory TrailRoute.fromJson(Map<String, Object?> j) => TrailRoute(
        id: j['id']! as String,
        name: j['name']! as String,
        difficulty: j['difficulty']! as int,
        distanceM: _double(j['distance_m']),
        ascentM: _double(j['ascent_m']),
        durationMin: j['duration_min']! as int,
        poiSequence: _strings(j['poi_sequence']),
        nodePath: _strings(j['node_path']),
      );

  final String id;
  final String name;
  final int difficulty;
  final double distanceM;
  final double ascentM;
  final int durationMin;
  final List<String> poiSequence;
  final List<String> nodePath;
}

/// Opening hours + every tunable parameter (park.json). No magic numbers in domain code.
class ParkConfig {
  ParkConfig({
    required this.open,
    required this.close,
    required this.hoursVerified,
    required this.gatePoiId,
    required Map<String, Object?> params,
  }) : _params = Map.unmodifiable(params);

  factory ParkConfig.fromJson(Map<String, Object?> j) {
    final hours = j['hours']! as Map<String, Object?>;
    return ParkConfig(
      open: _parseTime(hours['open']! as String),
      close: _parseTime(hours['close']! as String),
      hoursVerified: hours['verified'] == true,
      gatePoiId: j['gate_poi']! as String,
      params: j['params']! as Map<String, Object?>,
    );
  }

  /// Time of day as offset from midnight.
  final Duration open;
  final Duration close;
  final bool hoursVerified;
  final String gatePoiId;
  final Map<String, Object?> _params;

  /// Numeric parameter from park.json `params`. Throws if missing — a typo must fail loudly.
  double param(String key) {
    final value = _params[key];
    if (value is! num) {
      throw StateError('park.json params.$key is missing or not a number');
    }
    return value.toDouble();
  }

  Map<String, double> get recWeights => {
        for (final e
            in (_params['rec_weights']! as Map<String, Object?>).entries)
          e.key: (e.value! as num).toDouble(),
      };

  DateTime closingTimeOn(DateTime day) =>
      DateTime(day.year, day.month, day.day).add(close);

  DateTime openingTimeOn(DateTime day) =>
      DateTime(day.year, day.month, day.day).add(open);

  /// Indonesian format, e.g. "16.00".
  String get openLabel => _label(open);
  String get closeLabel => _label(close);

  static Duration _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]));
  }

  static String _label(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h.$m';
  }
}

class GraphNode {
  const GraphNode({
    required this.id,
    required this.position,
    required this.elevationM,
    required this.ref,
  });

  factory GraphNode.fromJson(Map<String, Object?> j) => GraphNode(
        id: j['id']! as String,
        position: GeoPoint(_double(j['lat']), _double(j['lng'])),
        elevationM: _double(j['ele']),
        ref: j['ref'] as String?,
      );

  final String id;
  final GeoPoint position;
  final double elevationM;

  /// POI/facility id this node represents, or null for a junction.
  final String? ref;
}

class GraphEdge {
  const GraphEdge({
    required this.from,
    required this.to,
    required this.lengthM,
    required this.ascentM,
    required this.descentM,
    required this.geometry,
  });

  factory GraphEdge.fromJson(Map<String, Object?> j) => GraphEdge(
        from: j['from']! as String,
        to: j['to']! as String,
        lengthM: _double(j['length_m']),
        ascentM: _double(j['ascent_m']),
        descentM: _double(j['descent_m']),
        geometry: [
          for (final p in j['geometry']! as List<Object?>)
            if (p case [final Object lat, final Object lng, ...])
              GeoPoint(_double(lat), _double(lng)),
        ],
      );

  /// Undirected edge. [ascentM]/[descentM] are for the from → to direction.
  final String from;
  final String to;
  final double lengthM;
  final double ascentM;
  final double descentM;
  final List<GeoPoint> geometry;
}

class TrailGraph {
  TrailGraph({required List<GraphNode> nodes, required List<GraphEdge> edges})
      : nodes = {for (final n in nodes) n.id: n},
        edges = List.unmodifiable(edges);

  factory TrailGraph.fromJson(Map<String, Object?> j) => TrailGraph(
        nodes: [
          for (final n in j['nodes']! as List<Object?>)
            GraphNode.fromJson(n! as Map<String, Object?>),
        ],
        edges: [
          for (final e in j['edges']! as List<Object?>)
            GraphEdge.fromJson(e! as Map<String, Object?>),
        ],
      );

  final Map<String, GraphNode> nodes;
  final List<GraphEdge> edges;
}
