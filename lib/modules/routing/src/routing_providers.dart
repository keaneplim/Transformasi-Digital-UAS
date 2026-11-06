import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/modules/content/content.dart';

import 'domain/stub_trail_router.dart';
import 'domain/trail_router.dart';

/// Stub until the graph router lands; swap the implementation here (one line), not in callers.
final trailRouterProvider = Provider<TrailRouter>(
  (ref) => StubTrailRouter(ref.watch(contentRepositoryProvider)),
);
