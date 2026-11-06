import 'dart:convert';
import 'dart:io';

import 'package:jelajah_taman/modules/content/content.dart';

/// Loads the real assets/content/*.json from disk (tests run from the project root).
ContentRepository loadTestContent() {
  Map<String, Object?> read(String name) =>
      jsonDecode(File('assets/content/$name').readAsStringSync())
          as Map<String, Object?>;

  return ContentRepository.fromJson(
    pois: read('pois.json'),
    facilities: read('facilities.json'),
    routes: read('routes.json'),
    park: read('park.json'),
    graph: read('trail_graph.json'),
  );
}
