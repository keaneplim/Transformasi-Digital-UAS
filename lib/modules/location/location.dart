/// Module `location` (level 1, owner A) — public front door.
///
/// GPS fixes, GPS quality, foreground tracking during a session, interval switching (A06),
/// GPX replay source for desk testing. Owns plugin `geolocator` (in src/data/ only).
/// Spec: IMPLEMENTATION_PLAN.md F01, A06.
library;

export 'src/domain/location_contracts.dart';
export 'src/location_providers.dart';
