import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/location_contracts.dart';

// TODO(A): implement GeolocatorSource + GpxReplaySource in src/data/ and LocationService in
// src/application/, then bind them in the shell composition root.
final locationSourceProvider = Provider<LocationSource>(
  (ref) => throw UnimplementedError('locationSourceProvider not bound yet'),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => throw UnimplementedError('locationServiceProvider not bound yet'),
);
