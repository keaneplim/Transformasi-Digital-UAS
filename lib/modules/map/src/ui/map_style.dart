import 'package:flutter/material.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/theme/app_theme.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Colours and icons for map content (DESIGN.md §2 category tints, §11 map). Only map widgets use this.
abstract final class MapStyle {
  /// Warm paper under everything (also shows while tiles or the basemap load).
  static const background = Color(0xFFEFF1DC);
  static const trail = Color(0xFF8A968E);
  static const activeRoute = AppColors.trailGreen;
  static const gpsWeakDot = AppColors.mossGray;

  // ---- basemap ("Sunlit Field Guide" cartography) -------------------------------------
  static const forest = Color(0xFFC9DDAE);
  static const scrub = Color(0xFFD8E3B7);
  static const grass = Color(0xFFE2EBC0);
  static const farmland = Color(0xFFF0E7C4);
  static const residential = Color(0xFFEDE5D6);
  static const cemetery = Color(0xFFE0E2C9);
  static const parkTint = Color(0x1A2F7A50);
  static const parkEdge = Color(0xFF2F7A50);
  static const water = Color(0xFFB4D6E7);
  static const waterEdge = Color(0xFF86B9D6);
  static const waterText = Color(0xFF3C7DA6);
  static const building = Color(0xFFE6DBC8);
  static const buildingEdge = Color(0xFFD5C6AD);
  static const roadCasing = Color(0xFFDCD1B9);
  static const roadFill = Color(0xFFFFFCF4);
  static const majorRoadFill = Color(0xFFFFF0C9);
  static const footpath = Color(0xFFB79C6B);
  static const contour = Color(0xFF8E7A52);
  static const trailCore = Color(0xFFC79A55);

  static Color landcover(String kind) => switch (kind) {
        'forest' => forest,
        'scrub' => scrub,
        'grass' => grass,
        'farmland' => farmland,
        'residential' => residential,
        'cemetery' => cemetery,
        _ => grass,
      };

  /// Line width that grows with zoom like a printed map's (base at z16).
  static double scaled(double base, double zoom,
      {double min = 0.6, double max = 28}) {
    final f = zoom <= 16 ? 1 + (zoom - 16) * 0.28 : 1 + (zoom - 16) * 0.55;
    return (base * f).clamp(min, max);
  }

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
