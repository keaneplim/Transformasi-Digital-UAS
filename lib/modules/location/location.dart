/// Module `location` (level 1) — public front door.
///
/// GPS fixes, GPS quality, compass heading, permission access, foreground tracking during a
/// session. Owns plugins `geolocator` and `flutter_compass` (in src/data/ only).
/// Spec: IMPLEMENTATION_PLAN.md F01, A06.
library;

export 'src/application/location_service_impl.dart' show LocationServiceImpl;
export 'src/domain/location_contracts.dart';
export 'src/location_providers.dart';
