import 'dart:async';
import 'package:jelajah_taman/core/models/location_models.dart';

abstract class LocationService {
  Stream<LocationFix> get fixes;
  Stream<GpsQuality> get quality;
  LocationFix? get last;
  
  Future<void> startSession();
  Future<void> stopSession();
}