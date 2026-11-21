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

/// One shown recommendation (F07 UC-F07-1 postcondition): TC-09 evidence (always unvisited)
/// and, with the E7 time, AC2 (≤ 2 s after finishing a POI).
class RecommendationEntry {
  const RecommendationEntry({
    required this.at,
    required this.afterPoiId,
    required this.reason,
    required this.finishedAt,
    required this.poiIds,
  });

  /// Null for anything that isn't a well-formed entry (stored data is never trusted).
  static RecommendationEntry? tryParse(Object? o) {
    if (o is! Map) return null;
    final at = DateTime.tryParse('${o['at']}');
    final fin = DateTime.tryParse('${o['finished_at']}');
    final after = o['after'];
    final reason = o['reason'];
    final ids = o['pois'];
    if (at == null ||
        fin == null ||
        after is! String ||
        reason is! String ||
        ids is! List) {
      return null;
    }
    return RecommendationEntry(
      at: at,
      afterPoiId: after,
      reason: reason,
      finishedAt: fin,
      poiIds: [for (final i in ids) '$i'],
    );
  }

  final DateTime at;

  /// The POI that was finished.
  final String afterPoiId;

  /// `FinishReason` name (detailClosed / narrationDone / leftArea).
  final String reason;
  final DateTime finishedAt;

  /// Main first, then the alternatives. Empty = back to the gate.
  final List<String> poiIds;

  Map<String, Object?> toJson() => {
        'at': at.toIso8601String(),
        'after': afterPoiId,
        'reason': reason,
        'finished_at': finishedAt.toIso8601String(),
        'pois': poiIds,
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
    List<RecommendationEntry>? recommendations,
    this.triggerState,
    this.stepState,
  })  : interests = [...interests],
        trail = trail ?? [],
        events = events ?? [],
        recommendations = recommendations ?? [];

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
      recommendations: [
        if (j['recommendations'] case final List<Object?> l)
          for (final o in l)
            if (RecommendationEntry.tryParse(o) case final e?) e,
      ],
      triggerState: j['trigger'] as Map<String, Object?>?,
      stepState: j['steps'] as Map<String, Object?>?,
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

  /// Every recommendation shown in this session (F07).
  final List<RecommendationEntry> recommendations;

  /// Trigger engine snapshot (`GeofenceEngine.toJson`), opaque to this module.
  Map<String, Object?>? triggerState;

  /// Step counter snapshot (`StepTracker.toJson`, F08), opaque to this module. Null in demo
  /// mode and on phones without a step counter.
  Map<String, Object?>? stepState;

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
        if (recommendations.isNotEmpty)
          'recommendations': [for (final r in recommendations) r.toJson()],
        if (triggerState != null) 'trigger': triggerState,
        if (stepState != null) 'steps': stepState,
      };
}
