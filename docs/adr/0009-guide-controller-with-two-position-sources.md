# 0009 One GuideController with Real and Demo Position Sources

Status: Accepted

Date: 2026-11-12

Scope: app state for all screens, demo mode, `shell` module

## Context

The full UI (UI01–UI15) was built before most engines existed, so it could be reviewed and presented early. The app must also be demonstrable away from Tahura (progress reviews, presentations, the product video), without a second, fake code path that drifts from the real logic.

## Decision

One `GuideController` in `lib/modules/shell/src/state/` holds the guide state behind every screen and takes positions from **two sources**:

- **real** (default): GPS fixes from the `location` module;
- **demo**: a simulated walk along the trail graph, with the ability to jump the clock (for example to 15.30 for TC-10).

The mode is switched in Settings (*Mode demo*) and persisted (`app_mode`, default real). **Both modes feed the same `GeofenceEngine`** and publish the same events on the `EventBus`; they differ only in where the position comes from.

## Rationale

The demo exercises the real trigger, routing and reminder logic, so a demo is evidence of real behaviour and there is no second code path to keep in sync.

## Alternatives Considered

- **Separate demo controller with mocked state:** rejected; it would drift from real behaviour.
- **GPX replay only:** kept as a development source, but not enough for live presentations that need control over the walk and the clock.

## Implementation Details

- `AppMode { real, demo }`, persisted under `app_mode`.
- The Settings *Mode demo* panel is the only place where operational detail may appear in the visitor UI.
- The controller also hosts session wiring, navigation progress and reminder scheduling until those move to their owner modules.

## Consequences

`GuideController` is large while it hosts logic that belongs to `session`, `navigation` and `audio`. The architecture checker still applies.

## Validation

Controller tests cover both modes; demo walks run through the real engine in widget and golden tests.

## Risks

A large controller is harder to review; mitigated by moving logic out as engines land.

## Follow-up

Move session, navigation and audio logic into their owner modules; keep the controller as a thin composition of them.
