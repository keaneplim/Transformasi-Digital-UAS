/// Module `trigger` (level 2) — public front door.
///
/// Geofence state machine (debounce, hysteresis, cooldown), QR + manual triggers.
/// Publishes E3 PoiApproached, E4 PoiTriggered, E6 PoiVisited, E7 PoiFinished(leftArea).
/// Listens to E5 PoiEngaged → Visited (D05).
/// Spec: IMPLEMENTATION_PLAN.md F02, A02. Worked layout: ARCHITECTURE.md §7.2.
library;

export 'src/application/geofence_targets.dart';
export 'src/domain/geofence_engine.dart';
export 'src/domain/trigger_contracts.dart';
