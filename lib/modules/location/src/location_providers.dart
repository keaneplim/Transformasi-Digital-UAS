import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/location_service_impl.dart';
import 'data/geolocator_source.dart';
import 'domain/location_contracts.dart';

/// The device position. Null until the composition root binds it (R8), so widget and golden
/// tests run without the platform plugin; callers then behave as "no GPS" (or use demo mode).
final locationServiceProvider = Provider<LocationService?>((ref) => null);

/// Binding for the composition root: GPS via geolocator + compass, disposed with the scope.
Override bindGeolocatorLocationService() =>
    locationServiceProvider.overrideWith((ref) {
      final service = LocationServiceImpl(
        source: const GeolocatorLocationSource(),
        permissions: const GeolocatorPermissions(),
        headingSource: const CompassHeadingSource(),
      );
      ref.onDispose(service.dispose);
      return service;
    });
