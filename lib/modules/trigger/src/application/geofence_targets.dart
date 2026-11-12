import 'package:jelajah_taman/modules/content/content.dart';

import '../domain/geofence_engine.dart';

/// Geofences from the content for the active route:
/// - the gate never triggers in a session (D07: its welcome lives on Home);
/// - a POI that belongs only to the Trekking route (Curug Omas, §4.1) is evaluated only when
///   Trekking is the active route.
List<GeofenceTarget> buildGeofenceTargets(ContentRepository content,
        {String? activeRouteId}) =>
    [
      for (final p in content.pois)
        GeofenceTarget(
          id: p.id,
          position: p.position,
          radiusM: p.radiusM,
          enabled: p.id != content.park.gatePoiId &&
              !(p.routes.length == 1 &&
                  p.routes.first == 'trekking' &&
                  activeRouteId != 'trekking'),
        ),
    ];
