import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/location/src/domain/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeolocatorSource implements LocationService {
  final Clock _clock;
  StreamSubscription<Position>? _positionStream;
  Timer? _noFixTimer;
  
  final _fixController = StreamController<LocationFix>.broadcast();
  final _qualityController = StreamController<GpsQuality>.broadcast();
  
  LocationFix? _lastFix;
  GpsQuality _lastQuality = GpsQuality.none;

  GeolocatorSource(this._clock);

  @override
  Stream<LocationFix> get fixes => _fixController.stream;

  @override
  Stream<GpsQuality> get quality => _qualityController.stream;

  @override
  LocationFix? get last => _lastFix;

  @override
  Future<void> startSession() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _updateQuality(GpsQuality.none);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _updateQuality(GpsQuality.none);
      return;
    }

    late LocationSettings locationSettings;
    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Jelajah Taman sedang memandu Anda",
          notificationTitle: "Jelajah Taman Aktif",
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      final fix = LocationFix(
        position: GeoPoint(position.latitude, position.longitude),
        accuracyM: position.accuracy,
        speedMps: position.speed,
        headingDeg: position.heading,
        at: _clock.now(),
      );
      
      _lastFix = fix;
      _fixController.add(fix);
      _resetNoFixTimer();

      // D08: Weak GPS logic
      if (fix.accuracyM > 30.0) {
        _updateQuality(GpsQuality.weak);
      } else {
        _updateQuality(GpsQuality.good);
      }
    });

    _resetNoFixTimer();
  }

  @override
  Future<void> stopSession() async {
    await _positionStream?.cancel();
    _noFixTimer?.cancel();
    _positionStream = null;
    _updateQuality(GpsQuality.none);
  }

  void _resetNoFixTimer() {
    _noFixTimer?.cancel();
    _noFixTimer = Timer(const Duration(seconds: 10), () {
      _updateQuality(GpsQuality.none);
    });
  }

  void _updateQuality(GpsQuality q) {
    if (_lastQuality != q) {
      _lastQuality = q;
      _qualityController.add(q);
    }
  }
}