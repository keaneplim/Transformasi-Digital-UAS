import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/step_tracker.dart';
import 'data/pedometer_step_source.dart';
import 'domain/steps.dart';

/// Session step counting (F08). Null until the composition root binds it (R8): tests,
/// goldens and the web preview estimate steps from distance instead.
final stepTrackerProvider = Provider<StepTracker?>((ref) => null);

/// Binding for the composition root: the phone's step counter. [permissions] comes from
/// `shell` (permission_handler is a shell plugin, R5).
Override bindPedometerStepTracker(StepPermissions permissions) =>
    stepTrackerProvider.overrideWith((ref) {
      final tracker = StepTracker(
          source: const PedometerStepSource(), permissions: permissions);
      ref.onDispose(tracker.dispose);
      return tracker;
    });
