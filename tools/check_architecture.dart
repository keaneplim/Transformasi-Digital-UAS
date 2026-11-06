// ignore_for_file: avoid_print
//
// Enforces docs/engineering/ARCHITECTURE.md rules on lib/:
//   R1  never import another module's src/
//   R2  module dependencies must follow the allowed table (§4)
//   R4  no Flutter / plugin imports in src/domain/
//   R5  plugin packages only in the owning module (src/data/, or src/ui/ for UI plugins)
//   R7  no DateTime.now() outside lib/core/clock/
//   +   core must not import any module
//
// Usage:  dart run tools/check_architecture.dart      (exit 1 on any violation)
// Changing [allowed] or [pluginOwner] = update ARCHITECTURE.md §3/§4 in the same PR.

import 'dart:io';

const package = 'jelajah_taman';

/// ARCHITECTURE.md §4 — which modules each module may import (core is always allowed).
const allowed = <String, Set<String>>{
  'content': {},
  'location': {'content'},
  'audio': {'content'},
  'notify': {},
  'routing': {'content'},
  'trigger': {'content', 'location', 'audio', 'notify'},
  'session': {'content', 'location', 'trigger'},
  'map': {'content', 'location', 'routing', 'trigger'},
  'navigation': {'content', 'location', 'audio', 'routing'},
  'poi': {'content', 'location', 'audio', 'routing'},
  'search': {'content', 'location', 'routing'},
  'recommendation': {'content', 'location', 'notify', 'routing', 'session'},
  'reminders': {'content', 'location', 'audio', 'notify', 'routing', 'session'},
  'wellness': {'content', 'location', 'routing', 'session'},
  'shell': {
    'content',
    'location',
    'audio',
    'notify',
    'routing',
    'trigger',
    'session',
    'map',
    'navigation',
    'poi',
    'search',
    'recommendation',
    'reminders',
    'wellness',
  },
};

/// ARCHITECTURE.md §3 — plugin package → owning module.
const pluginOwner = <String, String>{
  'geolocator': 'location',
  'just_audio': 'audio',
  'audio_service': 'audio',
  'flutter_tts': 'audio',
  'flutter_local_notifications': 'notify',
  'vibration': 'notify',
  'mobile_scanner': 'trigger',
  'flutter_map': 'map',
  'flutter_map_mbtiles': 'map',
  'latlong2': 'map',
  'pedometer': 'wellness',
  'go_router': 'shell',
  'permission_handler': 'shell',
  'sqflite': 'core',
  'shared_preferences': 'core',
};

/// Plugins that provide widgets and may also be used in src/ui/ (and anywhere in shell).
const uiPlugins = {
  'flutter_map',
  'flutter_map_mbtiles',
  'latlong2',
  'mobile_scanner',
  'go_router'
};

final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

class Violation {
  Violation(this.file, this.line, this.rule, this.message);
  final String file;
  final int line;
  final String rule;
  final String message;
  @override
  String toString() => '$file:$line  [$rule] $message';
}

/// Returns the lib-relative path ("modules/trigger/src/...") of an import, or null if external.
String? libPathOf(String spec, File from, Directory lib) {
  if (spec.startsWith('package:$package/')) {
    return spec.substring('package:$package/'.length);
  }
  if (spec.startsWith('package:') || spec.startsWith('dart:')) return null;
  // Work on URIs (always '/'-separated, dot segments normalized) so Windows and Linux agree.
  final resolved = from.absolute.uri.resolve(spec).path;
  final libRoot = lib.absolute.uri.path; // ends with '/'
  if (!resolved.startsWith(libRoot)) return null;
  return resolved.substring(libRoot.length);
}

/// `modules/<m>/...` → m, `core/...` → "core", anything else → null (e.g. main.dart).
String? moduleOf(String libRelative) {
  final parts = libRelative.split('/');
  if (parts.first == 'core') return 'core';
  if (parts.length > 1 && parts.first == 'modules') return parts[1];
  return null;
}

void main() {
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    print('Run from the project root (lib/ not found).');
    exit(2);
  }
  final violations = <Violation>[];
  final files = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    final rel = file.absolute.uri.path.substring(lib.absolute.uri.path.length);
    final display = 'lib/$rel';
    final owner = moduleOf(rel);
    final inDomain = rel.contains('/src/domain/');
    final inData = rel.contains('/src/data/');
    final inUi = rel.contains('/src/ui/');
    final lines = file.readAsLinesSync();

    if (owner != null && owner != 'core' && !allowed.containsKey(owner)) {
      violations.add(Violation(display, 1, 'MOD',
          "module '$owner' is not in the allowed table — add it to ARCHITECTURE.md §3/§4 and this script"));
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//')) continue;

      // R7 — time only from Clock.
      if (line.contains('DateTime.now()') && !rel.startsWith('core/clock/')) {
        violations.add(Violation(
            display, i + 1, 'R7', 'use Clock.now(), not DateTime.now()'));
      }

      final match = importRe.firstMatch(line);
      if (match == null) continue;
      final spec = match.group(1)!;

      // R4 — pure domain.
      if (inDomain &&
          (spec.startsWith('package:flutter/') ||
              spec.startsWith('package:flutter_riverpod/') ||
              spec == 'dart:ui')) {
        violations.add(Violation(
            display, i + 1, 'R4', 'src/domain/ must be pure Dart: $spec'));
      }

      // R5 — plugin ownership.
      if (spec.startsWith('package:') &&
          !spec.startsWith('package:$package/')) {
        final pkg = spec.substring('package:'.length).split('/').first;
        final pluginModule = pluginOwner[pkg];
        if (pluginModule != null) {
          final ownerOk = owner == pluginModule;
          final layerOk = owner == 'core' ||
              owner == 'shell' ||
              inData ||
              (inUi && uiPlugins.contains(pkg));
          if (!ownerOk || !layerOk) {
            violations.add(Violation(display, i + 1, 'R5',
                "plugin '$pkg' belongs to module '$pluginModule' (src/data/${uiPlugins.contains(pkg) ? ' or src/ui/' : ''})"));
          }
          if (inDomain) {
            violations.add(Violation(
                display, i + 1, 'R4', 'plugin import in src/domain/: $pkg'));
          }
        }
      }

      // R1 / R2 — module boundaries.
      final target = libPathOf(spec, file, lib);
      if (target == null) continue;
      final targetModule = moduleOf(target);
      if (targetModule == null || targetModule == owner) continue;
      if (targetModule == 'core') continue;

      if (owner == 'core') {
        violations.add(Violation(display, i + 1, 'CORE',
            'core must not import module $targetModule'));
        continue;
      }
      if (target.startsWith('modules/$targetModule/src/')) {
        violations.add(Violation(display, i + 1, 'R1',
            "import modules/$targetModule/$targetModule.dart instead of its src/"));
      }
      if (owner != null && !(allowed[owner]?.contains(targetModule) ?? false)) {
        violations.add(Violation(display, i + 1, 'R2',
            "'$owner' may not depend on '$targetModule' (ARCHITECTURE.md §4)"));
      }
      if (owner == null && targetModule != 'shell') {
        violations.add(Violation(
            display, i + 1, 'R8', 'main.dart should only import shell'));
      }
    }
  }

  if (violations.isEmpty) {
    print('Architecture check passed.');
    return;
  }
  violations.forEach(print);
  print('\n${violations.length} architecture violation(s).');
  exit(1);
}
