import 'package:jelajah_taman/core/core.dart';

enum GpsQuality {
  /// accuracy ≤ 30 m
  good,

  /// accuracy > 30 m — shown, but ignored by the trigger engine (F01)
  weak,

  /// no fix for 10 s
  none,
}

class LocationFix {
  const LocationFix({
    required this.position,
    required this.accuracyM,
    required this.at,
    this.speedMps,
    this.headingDeg,
  });

  final GeoPoint position;
  final double accuracyM;
  final DateTime at;
  final double? speedMps;
  final double? headingDeg;
}

/// Extension point (ARCHITECTURE.md §6): GeolocatorSource, GpxReplaySource, TeleportSource.
abstract interface class LocationSource {
  Stream<LocationFix> fixes({required Duration interval});
}

/// The only way any module reads the position. No screen touches the GPS plugin directly.
abstract interface class LocationService {
  /// Every fix, including weak ones (the UI shows them).
  Stream<LocationFix> get fixes;

  Stream<GpsQuality> get quality;

  LocationFix? get last;

  /// Starts the foreground service and 3 s updates (decision D14: distance filter 0).
  Future<void> startSession();

  Future<void> stopSession();
}
