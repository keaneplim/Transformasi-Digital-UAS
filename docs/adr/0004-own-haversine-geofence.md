# 0004 Own Haversine Geofence instead of OS Geofencing

Status: Accepted

Date: 2026-11-06

Scope: location-based trigger engine (F02)

## Context

PRD F02 and §4.2 define a precise trigger behaviour: per-POI radii of 20–40 m, an Approaching state at r+30 m with exit hysteresis at r+40 m, confirmation by two consecutive readings inside the radius, rejection of readings with accuracy worse than 30 m, separation of *triggered* and *visited*, and a re-trigger rule that requires both leaving beyond r+15 m and a 10-minute cooldown. These rules must be testable (TC-02, TC-03) and calibrated after field tests.

Android's geofencing API offers enter/exit/dwell transitions with OS-controlled timing, typical minimum radii around 100 m, and no control over debounce, hysteresis or accuracy filtering.

## Decision

The app implements its **own geofence**: it receives GPS fixes from the `location` module, computes haversine distances to every eligible POI on each reading, and runs a per-POI state machine (`Outside → Approaching → Triggered → Visited → Cooldown`) in pure Dart inside the `trigger` module (`GeofenceEngine`).

## Rationale

Only an in-app engine can implement the specified debounce, hysteresis, cooldown and accuracy rules exactly, and only pure Dart logic can be unit-tested deterministically with a fake clock and synthetic walks. Radii below the OS minimum are required by the PRD.

## Alternatives Considered

- **Android Geofencing API (Play Services):** rejected; radius too coarse, timing not controllable, behaviour not testable off-device.
- **A third-party geofencing plugin:** rejected for the same reasons and an extra fragile dependency.

## Implementation Details

- Distance: haversine in `core` geo maths.
- Location settings: updates every ±3 s with distance filter 0 (decision D14), so a stationary visitor still produces readings for the two-reading confirmation and the weak-GPS timer.
- All thresholds come from `park.json` (`ParkConfig`), so field calibration is a data change.
- Engine state is serializable (`toJson`/`restore`) so a session survives the app being killed.

## Consequences

The app must keep receiving location updates during a session, which requires a foreground service (ADR 0006) and has a battery cost (A06). The trigger logic is fully owned and documented by the team.

## Validation

Unit tests for the engine cover the PRD and IMPLEMENTATION_PLAN F02 cases (approach, confirmation, hysteresis, cooldown, QR and manual layers, restore). Field validation is TC-02 and TC-03.

## Risks

GPS accuracy under the forest canopy and in caves; mitigated by the accuracy filter, the QR fallback (A02) and manual POI pick.

## Follow-up

Calibrate radii and thresholds after the Sprint 5 field test and record final values in the PRD Change Log.
