/// Module `session` (level 3, owner A) — public front door.
///
/// Session lifecycle (start / end / restore after the app is killed), session log with
/// triggered vs visited (D05), session metrics. Owns table `sessions`.
/// Publishes E1 SessionStarted, E2 SessionEnded.
library;

export 'src/data/session_store.dart';
export 'src/domain/session_contracts.dart';
export 'src/domain/session_record.dart';
export 'src/session_providers.dart';
