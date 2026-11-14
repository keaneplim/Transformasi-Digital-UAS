/// Module `notify` (level 1, owner C) — public front door.
///
/// System notifications (trigger UI05 with Dengarkan / Lihat detail / Nanti, approach UI04),
/// taps forwarded from the plugin's background engine to the main isolate, vibration.
/// Owns plugins flutter_local_notifications and vibration (src/data/ only, rule R5).
/// Spec: IMPLEMENTATION_PLAN.md §6.2, F02, F04 (PB07).
library;

export 'src/domain/alert_contracts.dart';
export 'src/notify_providers.dart';
