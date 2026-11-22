/// Module `recommendation` (level 4, owner A) — public front door.
///
/// F07: candidate filter (unvisited, closing time − 15 min via routing's `TimeBudget`, passed
/// in), `ScoreFactor` strategies with D10 weights from `park.json`, 1 main + 2 alternatives
/// with reasons, or back to the gate. Pure domain; the guide (shell) runs it after E7
/// PoiFinished and shows UI08.
/// Spec: IMPLEMENTATION_PLAN.md F07. Template: docs/engineering/ARCHITECTURE.md §7.
library;

export 'src/domain/recommender.dart';
