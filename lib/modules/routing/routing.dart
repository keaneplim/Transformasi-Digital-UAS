/// Module `routing` (level 2, owner B) — public front door.
///
/// Trail graph, snapping, Dijkstra on walking time, ETA with slope (D09), turn instructions.
/// Backed by [GraphTrailRouter]; works on the dummy graph and on the surveyed one alike.
library;

export 'src/domain/graph_trail_router.dart' show GraphTrailRouter;
export 'src/domain/trail_router.dart';
export 'src/routing_providers.dart';
