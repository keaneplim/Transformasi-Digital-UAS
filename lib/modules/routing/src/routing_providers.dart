import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/modules/content/content.dart';

import 'domain/graph_trail_router.dart';
import 'domain/time_budget.dart';
import 'domain/trail_router.dart';

/// Swap the implementation here (one line), not in callers.
final trailRouterProvider = Provider<TrailRouter>(
  (ref) => GraphTrailRouter.fromContent(ref.watch(contentRepositoryProvider)),
);

/// The one closing-time rule (T23), shared by reminders, recommendation and route chooser.
final timeBudgetProvider = Provider<TimeBudget>(
  (ref) => TimeBudget.fromContent(
      ref.watch(contentRepositoryProvider), ref.watch(trailRouterProvider)),
);
