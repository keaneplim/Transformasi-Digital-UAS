/// Module `routing` (level 2, owner B) — public front door.
///
/// Trail graph, snapping, Dijkstra, ETA with slope (D09), turn instructions.
/// Currently backed by [StubTrailRouter] (haversine × 1.3).
library;

export 'src/domain/stub_trail_router.dart' show StubTrailRouter;
export 'src/domain/trail_router.dart';
export 'src/routing_providers.dart';
