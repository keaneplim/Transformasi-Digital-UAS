import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/basemap.dart';

const basemapAsset = 'assets/map/basemap.json';

/// Reads the bundled basemap (A01: offline from the first launch).
Future<BasemapData> loadBasemapFromAssets(AssetBundle bundle) async {
  final raw = await bundle.loadString(basemapAsset);
  return BasemapData.fromJson(jsonDecode(raw) as Map<String, Object?>);
}
