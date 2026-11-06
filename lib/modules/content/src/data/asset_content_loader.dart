import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/content_repository.dart';

/// Loads assets/content/*.json from the app bundle (offline, A01).
Future<ContentRepository> loadContentFromAssets(AssetBundle bundle) async {
  Future<Map<String, Object?>> read(String name) async =>
      jsonDecode(await bundle.loadString('assets/content/$name'))
          as Map<String, Object?>;

  return ContentRepository.fromJson(
    pois: await read('pois.json'),
    facilities: await read('facilities.json'),
    routes: await read('routes.json'),
    park: await read('park.json'),
    graph: await read('trail_graph.json'),
  );
}
