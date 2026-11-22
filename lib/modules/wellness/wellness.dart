/// Module `wellness` (level 4, owner C; step counter built by B) — public front door.
///
/// Route chooser data, pedometer, GPS distance, kcal estimate (D11), session summary data
/// (the UI14 screen is in shell, owner B). Owns plugin pedometer.
/// Built so far: session step counting from the hardware step counter (F08 b, TC-12);
/// `ActivityMeter` = walked distance with the accuracy filter, active time and kcal (D11).
/// Spec: IMPLEMENTATION_PLAN.md F08. Template: docs/engineering/ARCHITECTURE.md §7.
library;

export 'src/application/step_tracker.dart';
export 'src/domain/activity.dart';
export 'src/domain/steps.dart';
export 'src/wellness_providers.dart';
