import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jelajah_taman/core/core.dart';

import '../domain/location_contracts.dart';

/// GPS fixes from `geolocator` (F01): high accuracy, distance filter 0 (D14), and an Android
/// foreground service with an ongoing notification while a session runs.
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Stream<LocationFix> fixes(
      {required Duration interval, bool background = false}) {
    final LocationSettings settings;
    if (!kIsWeb && Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        intervalDuration: interval,
        foregroundNotificationConfig: background
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Jelajah Taman',
                notificationText: 'Jelajah Taman sedang memandu Anda',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: false,
        showBackgroundLocationIndicator: background,
      );
    } else {
      settings = const LocationSettings(
          accuracy: LocationAccuracy.best, distanceFilter: 0);
    }
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => LocationFix(
        position: GeoPoint(p.latitude, p.longitude),
        accuracyM: p.accuracy,
        at: p.timestamp,
        speedMps: p.speed >= 0 ? p.speed : null,
        headingDeg: p.heading >= 0 && p.speed > 0.6 ? p.heading : null,
      ),
    );
  }
}

class GeolocatorPermissions implements LocationPermissions {
  const GeolocatorPermissions();

  @override
  Future<LocationAccess> check() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    return _map(await Geolocator.checkPermission());
  }

  @override
  Future<LocationAccess> request() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return _map(p);
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  static LocationAccess _map(LocationPermission p) => switch (p) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        _ => LocationAccess.denied,
      };
}

/// Magnetic compass (`flutter_compass`). Emits nothing on devices without a sensor.
class CompassHeadingSource implements HeadingSource {
  const CompassHeadingSource();

  @override
  Stream<double?> headings() {
    if (kIsWeb) {
      return const Stream.empty(); // no web implementation (browser preview)
    }
    try {
      final events = FlutterCompass.events;
      if (events == null) return const Stream.empty();
      return events.map((e) => e.heading);
    } on Object catch (e) {
      AppLog.info('compass unavailable: $e');
      return const Stream.empty();
    }
  }
}
