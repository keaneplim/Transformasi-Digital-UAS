import 'package:flutter/material.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:jelajah_taman/modules/content/content.dart';

/// One thing on the map a visitor can go to: a POI or a facility.
/// Screens work with this so they don't switch on two model types everywhere.
class Place {
  Place.poi(Poi p)
      : id = p.id,
        name = p.name,
        kind = p.category,
        node = p.graphNode,
        position = p.position,
        images = p.images,
        poi = p,
        facility = null;

  Place.facility(Facility f)
      : id = f.id,
        name = f.name,
        kind = f.type,
        node = f.graphNode,
        position = f.position,
        images = f.images,
        poi = null,
        facility = f;

  final String id;
  final String name;

  /// POI category (sejarah/alam/rekreasi/informasi) or facility type (toilet/musala/…).
  final String kind;
  final String node;
  final GeoPoint position;
  final List<String> images;
  final Poi? poi;
  final Facility? facility;

  bool get isPoi => poi != null;
  bool get isGate => id == 'P01';
  String? get cover => images.isEmpty ? null : images.first;

  /// Category used for colour/filter: facilities are all "fasilitas".
  String get group => isPoi ? kind : 'fasilitas';
  Color get tint => JT.category(group);
  Color get tintSoft => JT.categorySoft(group);
  String get groupLabel => isPoi ? categoryLabel(kind) : facilityLabel(kind);
  IconData get icon => isPoi ? poiIcon(poi!) : facilityIcon(kind);
  Doodle get doodle => isPoi ? poiDoodle(id) : facilityDoodle(kind);
  int get seed => id.codeUnits.fold(0, (a, b) => a * 31 + b);
}

String categoryLabel(String c) => switch (c) {
      'sejarah' => 'Sejarah',
      'alam' => 'Alam',
      'rekreasi' => 'Rekreasi',
      'fasilitas' => 'Fasilitas',
      _ => 'Informasi',
    };

String facilityLabel(String t) => switch (t) {
      'toilet' => 'Toilet',
      'musala' => 'Musala',
      'warung' => 'Warung',
      'pos_petugas' => 'Pos Petugas',
      _ => 'Tempat Istirahat',
    };

IconData categoryIcon(String c) => switch (c) {
      'sejarah' => Icons.account_balance_rounded,
      'alam' => Icons.forest_rounded,
      'rekreasi' => Icons.park_rounded,
      'fasilitas' => Icons.wc_rounded,
      _ => Icons.flag_rounded,
    };

IconData poiIcon(Poi p) => switch (p.id) {
      'P01' => Icons.door_front_door_rounded,
      'P03' => Icons.museum_rounded,
      'P04' => Icons.water_rounded,
      'P05' || 'P06' => Icons.landscape_rounded,
      'P07' => Icons.pets_rounded,
      'P08' => Icons.forest_rounded,
      'P09' => Icons.deck_rounded,
      'P10' => Icons.local_florist_rounded,
      'P11' => Icons.waves_rounded,
      _ => categoryIcon(p.category),
    };

IconData facilityIcon(String t) => switch (t) {
      'toilet' => Icons.wc_rounded,
      'musala' => Icons.mosque_rounded,
      'warung' => Icons.storefront_rounded,
      'pos_petugas' => Icons.support_agent_rounded,
      _ => Icons.cabin_rounded,
    };

Doodle poiDoodle(String id) => switch (id) {
      'P01' => Doodle.map,
      'P02' => Doodle.sparkle,
      'P03' => Doodle.binoculars,
      'P04' => Doodle.drop,
      'P05' || 'P06' => Doodle.cave,
      'P07' => Doodle.deer,
      'P08' => Doodle.pine,
      'P09' => Doodle.butterfly,
      'P10' => Doodle.leaf,
      'P11' => Doodle.mountain,
      _ => Doodle.compass,
    };

Doodle facilityDoodle(String t) => switch (t) {
      'istirahat' => Doodle.bench,
      'warung' => Doodle.mushroom,
      'musala' => Doodle.sparkle,
      'toilet' => Doodle.drop,
      _ => Doodle.compass,
    };

String difficultyLabel(int d) => switch (d) {
      1 => 'Mudah',
      2 => 'Sedang',
      _ => 'Menantang',
    };

// ---- Indonesian formatting ------------------------------------------------------------

String thousands(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

String km(double metres, {int digits = 1}) =>
    (metres / 1000).toStringAsFixed(digits).replaceAll('.', ',');

String distanceLabel(double metres) =>
    metres < 950 ? '${(metres / 10).round() * 10} m' : '${km(metres)} km';

String minutesLabel(Duration d) {
  final m = d.inSeconds / 60;
  if (m < 1) return '<1 mnt';
  if (m < 60) return '${m.round()} mnt';
  final h = m ~/ 60;
  final r = (m % 60).round();
  return r == 0 ? '$h j' : '$h j $r mnt';
}

String clockLabel(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

String durationClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0
      ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
      : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String greeting(DateTime t) => switch (t.hour) {
      < 11 => 'Selamat pagi',
      < 15 => 'Selamat siang',
      < 18 => 'Selamat sore',
      _ => 'Selamat malam',
    };
