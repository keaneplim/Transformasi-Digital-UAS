/// Domain events E1–E10 — the shared language between modules (ARCHITECTURE.md §5.2).
///
/// Rules:
/// - Payloads are IDs and primitive values only, never module-internal types.
/// - Adding an event = add a row to ARCHITECTURE.md §5.2 in the same PR.
/// - Events announce news. Never use them to fetch data.
abstract class DomainEvent {
  const DomainEvent(this.at);

  /// Taken from `Clock.now()`, never `DateTime.now()`.
  final DateTime at;

  @override
  String toString() => '$runtimeType@${at.toIso8601String()}';
}

// ---- shared enums used in event payloads ---------------------------------------------------

enum TriggerSource { gps, qr, manual }

/// How the visitor engaged with a POI. Any engagement makes it "visited" (decision D05).
enum EngagementKind { opened, listened, autoplay, qr, nav }

/// Why a POI visit is considered finished (starts the recommendation, F07).
enum FinishReason { detailClosed, narrationDone, leftArea }

enum ReminderKind { closing, hydration, finalCall }

// ---- E1–E2 session --------------------------------------------------------------------------

/// E1 — published by `session`.
class SessionStarted extends DomainEvent {
  const SessionStarted({
    required DateTime at,
    required this.sessionId,
    required this.interests,
    this.routeId,
  }) : super(at);

  final String sessionId;
  final String? routeId;
  final List<String> interests;
}

/// E2 — published by `session`.
class SessionEnded extends DomainEvent {
  const SessionEnded({required DateTime at, required this.sessionId})
      : super(at);

  final String sessionId;
}

// ---- E3–E7 POI lifecycle --------------------------------------------------------------------

/// E3 — published by `trigger` when the visitor enters r+30 m of an eligible POI.
class PoiApproached extends DomainEvent {
  const PoiApproached({
    required DateTime at,
    required this.poiId,
    required this.distanceM,
  }) : super(at);

  final String poiId;
  final double distanceM;
}

/// E4 — published by `trigger`.
class PoiTriggered extends DomainEvent {
  const PoiTriggered({
    required DateTime at,
    required this.poiId,
    required this.source,
  }) : super(at);

  final String poiId;
  final TriggerSource source;
}

/// E5 — published by `poi`, `audio`, `trigger` (QR), `navigation` (UI11). `trigger` listens → Visited.
class PoiEngaged extends DomainEvent {
  const PoiEngaged({
    required DateTime at,
    required this.poiId,
    required this.how,
  }) : super(at);

  final String poiId;
  final EngagementKind how;
}

/// E6 — published by `trigger`.
class PoiVisited extends DomainEvent {
  const PoiVisited({
    required DateTime at,
    required this.poiId,
    required this.how,
  }) : super(at);

  final String poiId;
  final EngagementKind how;
}

/// E7 — published by `poi`, `audio`, `trigger`. `recommendation` listens.
class PoiFinished extends DomainEvent {
  const PoiFinished({
    required DateTime at,
    required this.poiId,
    required this.reason,
  }) : super(at);

  final String poiId;
  final FinishReason reason;
}

// ---- E8–E9 navigation -----------------------------------------------------------------------

/// E8 — published by `navigation`.
class NavigationStarted extends DomainEvent {
  const NavigationStarted({required DateTime at, required this.destinationId})
      : super(at);

  final String destinationId;
}

/// E9 — published by `navigation`. Never creates a trigger (decision D06).
class NavigationArrived extends DomainEvent {
  const NavigationArrived({
    required DateTime at,
    required this.destinationId,
    required this.isPoi,
  }) : super(at);

  final String destinationId;
  final bool isPoi;
}

// ---- E10 reminders --------------------------------------------------------------------------

/// E10 — published by `reminders`. `audio` speaks it, `notify` posts it.
class ReminderDue extends DomainEvent {
  const ReminderDue({
    required DateTime at,
    required this.kind,
    required this.text,
    this.actionDestinationId,
  }) : super(at);

  final ReminderKind kind;
  final String text;

  /// e.g. the gate POI for "Navigasi ke gerbang", or a rest point for hydration.
  final String? actionDestinationId;
}
