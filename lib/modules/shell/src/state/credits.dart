import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/core.dart';

/// Who made a bundled photo and under which licence (assets/content/image_credits.json,
/// written by tools/photos.py).
class ImageCredit {
  const ImageCredit({
    required this.file,
    required this.source,
    required this.author,
    required this.license,
    this.licenseUrl = '',
    this.sourceUrl = '',
    this.edit = '',
  });

  factory ImageCredit.fromJson(String file, Map<String, Object?> j) =>
      ImageCredit(
        file: file,
        source: j['source'] as String? ?? 'survey',
        author: j['author'] as String? ?? '',
        license: j['license'] as String? ?? '',
        licenseUrl: j['license_url'] as String? ?? '',
        sourceUrl: j['source_url'] as String? ?? '',
        edit: j['edit'] as String? ?? '',
      );

  final String file;

  /// `survey` (the team's own photos) or `commons` (Wikimedia Commons).
  final String source;
  final String author;
  final String license;
  final String licenseUrl;
  final String sourceUrl;
  final String edit;

  bool get isCommons => source == 'commons';

  /// One line for a caption: "Foto: Nama · CC BY-SA 4.0 · Wikimedia Commons".
  String get caption => isCommons
      ? 'Foto: $author · $license · Wikimedia Commons'
      : 'Foto: $author';
}

const imageCreditsAsset = 'assets/content/image_credits.json';

/// Credits keyed by file name; empty if the file is missing (the screens then fall back to a
/// generic caption).
final imageCreditsProvider =
    FutureProvider<Map<String, ImageCredit>>((ref) async {
  try {
    final raw = jsonDecode(await rootBundle.loadString(imageCreditsAsset))
        as Map<String, Object?>;
    final images = (raw['images'] as Map<String, Object?>?) ?? const {};
    return {
      for (final e in images.entries)
        e.key: ImageCredit.fromJson(e.key, e.value! as Map<String, Object?>),
    };
  } on Object catch (e) {
    AppLog.info('No image credits: $e');
    return const {};
  }
});
