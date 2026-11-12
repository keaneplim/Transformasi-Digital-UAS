import 'package:jelajah_taman/core/core.dart';

enum GpsQuality {
  /// accuracy ≤ 30 m
  good,

  /// accuracy > 30 m — shown, but ignored by the trigger engine (F01)
  weak,

  /// no fix for 10 s
  none,
}

/// Can the app read the position? (UC-F01-3)
enum LocationAccess {
  granted,

  /// Asked and refused; can ask again.
  denied,

  /// "Don't ask again": only the OS settings can change it.
  deniedForever,

  /// Location services are switched off on the device.
  serviceOff,
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

  /// Course over ground (only meaningful while moving).
  final double? headingDeg;

  bool isWeak(double weakAccuracyM) => accuracyM > weakAccuracyM;
}

/// Extension point (ARCHITECTURE.md §6): GeolocatorSource, GpxReplaySource, TeleportSource.
abstract interface class LocationSource {
  /// Fixes every [interval]. [background] keeps them coming with the screen off (Android
  /// foreground service), used only during a session (NG06).
  Stream<LocationFix> fixes({required Duration interval, bool background});
}

/// Permission and device-setting access, behind an interface so tests need no plugin.
abstract interface class LocationPermissions {
  Future<LocationAccess> check();

  Future<LocationAccess> request();

  /// Opens the app's OS settings page (after "don't ask again").
  Future<void> openSettings();

  /// Opens the device location settings (services off).
  Future<void> openLocationSettings();
}

/// Device compass in degrees (0 = north). Null events when the sensor is absent.
abstract interface class HeadingSource {
  Stream<double?> headings();
}

/// The only way any module reads the position. No screen touches the GPS plugin directly.
abstract interface class LocationService {
  /// Every fix, including weak ones (the UI shows them).
  Stream<LocationFix> get fixes;

  Stream<GpsQuality> get quality;

  /// Compass heading, falling back to the GPS course while walking.
  Stream<double> get headings;

  LocationFix? get last;

  GpsQuality get currentQuality;

  bool get isRunning;

  Future<LocationAccess> access();

  /// Asks the OS (shows the system dialog when allowed to).
  Future<LocationAccess> requestAccess();

  Future<void> openSettings();

  /// Fixes while the app is in use (map, Home). No-op when access isn't granted.
  Future<void> start();

  /// Starts the foreground service and 3 s updates (decision D14: distance filter 0).
  Future<void> startSession();

  /// Back to in-use updates only.
  Future<void> stopSession();

  Future<void> stop();
}
