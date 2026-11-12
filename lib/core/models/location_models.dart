import 'package:jelajah_taman/core/core.dart'; // Assuming GeoPoint is defined here

enum GpsQuality { good, weak, none }
enum TriggerSource { gps, qr, manual }
enum PoiState { outside, approaching, triggered, visited, cooldown }

class LocationFix {
  final GeoPoint position;
  final double accuracyM;
  final double? speedMps;
  final double? headingDeg;
  final DateTime at;

  const LocationFix({
    required this.position,
    required this.accuracyM,
    required this.at,
    this.speedMps,
    this.headingDeg,
  });
}