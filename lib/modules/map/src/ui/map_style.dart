import 'package:flutter/material.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/theme/app_theme.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Colours and icons for map content (DESIGN.md §2 category tints). Only map widgets use this.
abstract final class MapStyle {
  /// Plain background until the MBTiles layer exists (T05). W12 scope allows this.
  static const background = Color(0xFFE6ECE2);
  static const trail = Color(0xFF8A968E);
  static const activeRoute = AppColors.trailGreen;
  static const gpsWeakDot = AppColors.mossGray;

  static Color category(String category) => switch (category) {
        'sejarah' => AppColors.heritageStone,
        'alam' => AppColors.fern,
        'rekreasi' => AppColors.springTeal,
        _ => AppColors.canopyDeep, // informasi
      };

  static IconData categoryIcon(String category) => switch (category) {
        'sejarah' => Icons.account_balance,
        'alam' => Icons.park,
        'rekreasi' => Icons.directions_walk,
        _ => Icons.info_outline, // informasi
      };

  static IconData facilityIcon(String type) => switch (type) {
        'toilet' => Icons.wc,
        'musala' => Icons.mosque,
        'warung' => Icons.storefront,
        'pos_petugas' => Icons.local_police,
        _ => Icons.event_seat, // istirahat
      };
}

extension GeoPointLatLng on GeoPoint {
  LatLng toLatLng() => LatLng(lat, lng);
}
