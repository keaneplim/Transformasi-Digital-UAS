/// Module `trigger` (level 2, owner A) — public front door.
///
/// Geofence state machine (debounce, hysteresis, cooldown), QR + manual triggers,
/// trigger notification reaction, UI04/UI05/UI12, QR scanner. Owns plugin `mobile_scanner`
/// and table `visit_events`.
/// Publishes E3 PoiApproached, E4 PoiTriggered, E6 PoiVisited, E7 PoiFinished(leftArea).
/// Listens to E5 PoiEngaged → Visited (D05).
/// Spec: IMPLEMENTATION_PLAN.md F02, A02. Worked layout: ARCHITECTURE.md §7.2.
library;

export 'src/domain/trigger_contracts.dart';
export 'src/trigger_providers.dart';
