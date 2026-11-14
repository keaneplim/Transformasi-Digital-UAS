import 'package:jelajah_taman/core/core.dart';

/// Whether a log entry is a trigger or a visit. They are kept apart on purpose (D05):
/// "Nanti" leaves a POI triggered, only an engagement makes it visited.
enum VisitKind { triggered, visited }

/// One entry of the visit log (PB06): field-test evidence of what triggered when, and how.
class VisitEvent {
  const VisitEvent({
    required this.at,
    required this.poiId,
    required this.kind,
    required this.how,
  });

  factory VisitEvent.fromJson(Map<String, Object?> j) => VisitEvent(
        at: DateTime.parse(j['at']! as String),
        poiId: j['poi']! as String,
        kind: VisitKind.values.byName(j['kind']! as String),
        how: j['how']! as String,
      );

  final DateTime at;
  final String poiId;
  final VisitKind kind;

  /// `TriggerSource` name for a trigger (gps / qr / manual), `EngagementKind` name for a
  /// visit (opened / listened / autoplay / qr / nav).
  final String how;

  Map<String, Object?> toJson() => {
        'at': at.toIso8601String(),
        'poi': poiId,
        'kind': kind.name,
        'how': how,
      };
}

/// One exploration session as stored on the device, so it survives the app being killed
/// (ARCHITECTURE §9 "Background": restore from storage on next launch).
class SessionRecord {
  SessionRecord({
    required this.id,
    required this.startedAt,
    required this.mode,
    required this.routeId,
    required List<String> interests,
    this.endedAt,
    this.walkedM = 0,
    List<GeoPoint>? trail,
    List<VisitEvent>? events,
    this.triggerState,
  })  : interests = [...interests],
        trail = trail ?? [],
        events = events ?? [];

  factory SessionRecord.fromJson(Map<String, Object?> j) {
    final ended = j['ended_at'] as String?;
    return SessionRecord(
      id: j['id']! as String,
      startedAt: DateTime.parse(j['started_at']! as String),
      endedAt: ended == null ? null : DateTime.parse(ended),
      mode: j['mode']! as String,
      routeId: j['route']! as String,
      interests: [
        for (final i in j['interests']! as List<Object?>) i! as String
      ],
      walkedM: (j['walked_m']! as num).toDouble(),
      trail: [
        for (final p in j['trail']! as List<Object?>)
          if (p case [final num lat, final num lng])
            GeoPoint(lat.toDouble(), lng.toDouble()),
      ],
      events: [
        for (final e in j['events']! as List<Object?>)
          VisitEvent.fromJson(e! as Map<String, Object?>),
      ],
      triggerState: j['trigger'] as Map<String, Object?>?,
    );
  }

  /// A restored session older than this is not resumed (nobody walks the park for 12 h).
  static const maxResumeAge = Duration(hours: 12);

  final String id;
  final DateTime startedAt;
  DateTime? endedAt;

  /// `AppMode` name (real / demo): a demo session is never resumed as a GPS one.
  final String mode;
  String routeId;
  List<String> interests;
  double walkedM;
  final List<GeoPoint> trail;
  final List<VisitEvent> events;

  /// Trigger engine snapshot (`GeofenceEngine.toJson`), opaque to this module.
  Map<String, Object?>? triggerState;

  bool get isEnded => endedAt != null;

  Set<String> get triggeredIds => {
        for (final e in events)
          if (e.kind == VisitKind.triggered) e.poiId
      };

  Set<String> get visitedIds => {
        for (final e in events)
          if (e.kind == VisitKind.visited) e.poiId
      };

  /// Resume after a restart only an unfinished session of the same mode, started today and
  /// less than [maxResumeAge] ago. Anything else is archived as the last session instead.
  bool canResume({required DateTime now, required String mode}) =>
      !isEnded &&
      this.mode == mode &&
      startedAt.year == now.year &&
      startedAt.month == now.month &&
      startedAt.day == now.day &&
      !startedAt.isAfter(now) &&
      now.difference(startedAt) < maxResumeAge;

  Map<String, Object?> toJson() => {
        'id': id,
        'started_at': startedAt.toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
        'mode': mode,
        'route': routeId,
        'interests': interests,
        'walked_m': double.parse(walkedM.toStringAsFixed(1)),
        // ~0.1 m precision is plenty and keeps a 6 km trail small.
        'trail': [
          for (final p in trail)
            [
              double.parse(p.lat.toStringAsFixed(6)),
              double.parse(p.lng.toStringAsFixed(6)),
            ],
        ],
        'events': [for (final e in events) e.toJson()],
        if (triggerState != null) 'trigger': triggerState,
      };
}
