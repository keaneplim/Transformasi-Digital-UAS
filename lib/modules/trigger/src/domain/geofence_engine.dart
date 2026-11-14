import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/location/location.dart';

import 'trigger_contracts.dart';

/// Tunables from park.json (F02, D01–D08). Defaults = PRD values.
class GeofenceParams {
  const GeofenceParams({
    this.approachMarginM = 30,
    this.approachExitMarginM = 40,
    this.debounceReadings = 2,
    this.retriggerExitMarginM = 15,
    this.cooldown = const Duration(minutes: 10),
    this.weakAccuracyM = 30,
    this.weakBannerAfter = const Duration(seconds: 60),
    this.triggerSpacing = const Duration(seconds: 30),
  });

  factory GeofenceParams.fromPark(ParkConfig park) {
    double p(String k, double fallback) {
      try {
        return park.param(k);
      } on StateError {
        return fallback;
      }
    }

    return GeofenceParams(
      approachMarginM: p('approach_margin_m', 30),
      approachExitMarginM: p('approach_exit_margin_m', 40),
      debounceReadings: p('debounce_readings', 2).round(),
      retriggerExitMarginM: p('retrigger_exit_margin_m', 15),
      cooldown: Duration(minutes: p('cooldown_min', 10).round()),
      weakAccuracyM: p('gps_weak_accuracy_m', 30),
      weakBannerAfter:
          Duration(seconds: p('gps_weak_banner_after_s', 60).round()),
    );
  }

  final double approachMarginM;
  final double approachExitMarginM;
  final int debounceReadings;
  final double retriggerExitMarginM;
  final Duration cooldown;
  final double weakAccuracyM;
  final Duration weakBannerAfter;

  /// D01 overlap: a second POI may trigger only this long after the previous one (PROPOSED in
  /// IMPLEMENTATION_PLAN F02 UC-F02-3) so two notifications never stack.
  final Duration triggerSpacing;
}

/// One geofence. [enabled] = false keeps the POI out of GPS evaluation (gate, D07; Curug Omas
/// off the Trekking route, §4.1). QR/manual still work on disabled targets.
class GeofenceTarget {
  const GeofenceTarget({
    required this.id,
    required this.position,
    required this.radiusM,
    this.enabled = true,
  });

  final String id;
  final GeoPoint position;
  final double radiusM;
  final bool enabled;
}

class _Track {
  PoiState state = PoiState.outside;
  int debounce = 0;
  DateTime? triggeredAt;
  bool leftZone = false;
  double? distanceM;

  /// This approach episode already announced (or dismissed); cleared beyond r+40 (D03).
  bool episode = false;
}

/// The F02 state machine, pure Dart: fixes + time in, domain events out (ARCHITECTURE §7.2).
///
/// Per POI: Outside → Approaching (≤ r+30, leaves at > r+40, one event per episode, D03) →
/// Triggered (2 consecutive good fixes ≤ r) → Visited (only on engagement, D05).
/// - All eligible POIs are evaluated; the nearest candidate triggers first, the next one no
///   sooner than [GeofenceParams.triggerSpacing] later (D01).
/// - Weak fixes (> 30 m) are ignored: they neither count towards nor reset the debounce. After
///   60 s of weak/no fixes [weakBanner] turns on (D08).
/// - A triggered POI (visitor chose "Nanti") becomes eligible again once the visitor has been
///   > r+15 m away **and** 10 min have passed since the trigger (D04); it goes through Cooldown.
/// - A visited POI stays visited for the session: no approach buzz, no new trigger (D02,
///   UC-F02-6). This also keeps out-and-back routes from re-triggering on the way back.
class GeofenceEngine implements TriggerEngine {
  GeofenceEngine(
      {required List<GeofenceTarget> targets,
      this.params = const GeofenceParams()}) {
    setTargets(targets);
  }

  final GeofenceParams params;
  final Map<String, GeofenceTarget> _targets = {};
  final Map<String, _Track> _tracks = {};
  DateTime? _lastTriggerAt;
  DateTime? _weakSince;
  bool _weakBanner = false;

  /// Replace the targets (e.g. active route changed) keeping the state of known POIs.
  void setTargets(List<GeofenceTarget> targets) {
    _targets
      ..clear()
      ..addEntries(targets.map((t) => MapEntry(t.id, t)));
    for (final t in targets) {
      _tracks.putIfAbsent(t.id, _Track.new);
    }
  }

  @override
  Map<String, PoiState> get states =>
      {for (final e in _tracks.entries) e.key: e.value.state};

  PoiState stateOf(String id) => _tracks[id]?.state ?? PoiState.outside;

  bool isVisited(String id) => stateOf(id) == PoiState.visited;

  Set<String> get visitedIds => {
        for (final e in _tracks.entries)
          if (e.value.state == PoiState.visited) e.key
      };

  /// Last distance computed for [id] from a good fix.
  double? distanceTo(String id) => _tracks[id]?.distanceM;

  /// GPS has been weak or absent for ≥ 60 s (UI12 banner, D08).
  bool get weakBanner => _weakBanner;

  /// The nearest POI currently in the approaching ring, with its distance.
  ({String id, double distanceM})? get approaching {
    ({String id, double distanceM})? best;
    for (final e in _tracks.entries) {
      final d = e.value.distanceM;
      if (e.value.state != PoiState.approaching || d == null) continue;
      if (best == null || d < best.distanceM) best = (id: e.key, distanceM: d);
    }
    return best;
  }

  /// Feed one fix. Returns the events it caused (E3 PoiApproached, E4 PoiTriggered,
  /// E7 PoiFinished(leftArea)).
  List<DomainEvent> onFix(LocationFix fix, DateTime now) {
    if (fix.isWeak(params.weakAccuracyM)) {
      _weakSince ??= now;
      if (now.difference(_weakSince!) >= params.weakBannerAfter) {
        _weakBanner = true;
      }
      return const [];
    }
    _weakSince = null;
    _weakBanner = false;
    final out = <DomainEvent>[];
    final candidates = <(String, double)>[];
    for (final t in _targets.values) {
      final tr = _tracks[t.id]!;
      final d = haversineM(fix.position, t.position);
      tr.distanceM = d;
      final r = t.radiusM;
      switch (tr.state) {
        case PoiState.visited:
          if (!tr.leftZone && d > r + params.retriggerExitMarginM) {
            tr.leftZone = true;
            out.add(PoiFinished(
                at: now, poiId: t.id, reason: FinishReason.leftArea));
          }
        case PoiState.triggered || PoiState.cooldown:
          if (!tr.leftZone && d > r + params.retriggerExitMarginM) {
            tr.leftZone = true;
            tr.state = PoiState.cooldown;
            out.add(PoiFinished(
                at: now, poiId: t.id, reason: FinishReason.leftArea));
          }
          final cooled = tr.triggeredAt != null &&
              now.difference(tr.triggeredAt!) >= params.cooldown;
          if (tr.leftZone && cooled && d > r + params.retriggerExitMarginM) {
            tr
              ..state = PoiState.outside
              ..debounce = 0
              ..triggeredAt = null
              ..leftZone = false
              ..episode = false;
          }
        case PoiState.outside || PoiState.approaching:
          if (!t.enabled) {
            tr
              ..state = PoiState.outside
              ..debounce = 0;
            continue;
          }
          if (d > r + params.approachExitMarginM) {
            tr
              ..state = PoiState.outside
              ..episode = false;
          } else if (!tr.episode &&
              tr.state == PoiState.outside &&
              d <= r + params.approachMarginM &&
              d > r) {
            tr
              ..state = PoiState.approaching
              ..episode = true;
            out.add(PoiApproached(at: now, poiId: t.id, distanceM: d));
          }
          tr.debounce = d <= r ? tr.debounce + 1 : 0;
          if (tr.debounce >= params.debounceReadings) candidates.add((t.id, d));
      }
    }
    if (candidates.isNotEmpty) {
      final spaced = _lastTriggerAt == null ||
          now.difference(_lastTriggerAt!) >= params.triggerSpacing;
      if (spaced) {
        candidates.sort((a, b) => a.$2.compareTo(b.$2));
        out.add(_trigger(candidates.first.$1, TriggerSource.gps, now));
      }
    }
    return out;
  }

  PoiTriggered _trigger(String id, TriggerSource source, DateTime now) {
    final tr = _tracks.putIfAbsent(id, _Track.new);
    tr
      ..state = PoiState.triggered
      ..triggeredAt = now
      ..debounce = 0
      ..leftZone = false
      ..episode = true;
    _lastTriggerAt = now;
    return PoiTriggered(at: now, poiId: id, source: source);
  }

  /// E5 engagement → Visited (D05). Only a POI that triggered can become visited this way;
  /// opening a detail page from the list far away is not a visit.
  List<DomainEvent> onEngaged(String id, EngagementKind how, DateTime now) {
    final tr = _tracks[id];
    if (tr == null ||
        (tr.state != PoiState.triggered && tr.state != PoiState.cooldown)) {
      return const [];
    }
    tr.state = PoiState.visited;
    return [PoiVisited(at: now, poiId: id, how: how)];
  }

  /// QR: straight to Triggered + Visited (PRD §4.2).
  @override
  List<DomainEvent> qr(String id, DateTime now) {
    final t = _trigger(id, TriggerSource.qr, now);
    _tracks[id]!.state = PoiState.visited;
    return [t, PoiVisited(at: now, poiId: id, how: EngagementKind.qr)];
  }

  /// Manual pick ("Saya di sini" / list): Triggered.
  @override
  List<DomainEvent> manual(String id, DateTime now) {
    if (isVisited(id)) return const [];
    return [_trigger(id, TriggerSource.manual, now)];
  }

  /// Arrival via navigation (UI11) followed by an engagement there: Visited, source `nav`.
  /// Arrival never creates a trigger (D06), so no [PoiTriggered] is returned.
  List<DomainEvent> visitOnArrival(String id, DateTime now) {
    final tr = _tracks.putIfAbsent(id, _Track.new);
    if (tr.state == PoiState.visited) return const [];
    tr
      ..state = PoiState.visited
      ..debounce = 0
      ..leftZone = false
      ..episode = true;
    return [PoiVisited(at: now, poiId: id, how: EngagementKind.nav)];
  }

  /// The state worth keeping across an app restart (session restore, PB06): POIs that are
  /// triggered, cooling down or visited. Outside/approaching are transient and start over.
  Map<String, Object?> toJson() => {
        if (_lastTriggerAt != null)
          'last_trigger_at': _lastTriggerAt!.toIso8601String(),
        'pois': {
          for (final e in _tracks.entries)
            if (e.value.state
                case PoiState.triggered ||
                    PoiState.cooldown ||
                    PoiState.visited)
              e.key: {
                'state': e.value.state.name,
                if (e.value.triggeredAt != null)
                  'triggered_at': e.value.triggeredAt!.toIso8601String(),
                'left_zone': e.value.leftZone,
              },
        },
      };

  /// Restores what [toJson] wrote. Unknown states or malformed entries are skipped, so a
  /// stored session from an older build can't crash the app.
  void restore(Map<String, Object?> json) {
    reset();
    final last = json['last_trigger_at'];
    if (last is String) _lastTriggerAt = DateTime.tryParse(last);
    final pois = json['pois'];
    if (pois is! Map) return;
    for (final MapEntry(:key, :value) in pois.entries) {
      if (key is! String || value is! Map) continue;
      final state = PoiState.values.asNameMap()[value['state']];
      if (state == null) continue;
      final at = value['triggered_at'];
      _tracks.putIfAbsent(key, _Track.new)
        ..state = state
        ..triggeredAt = at is String ? DateTime.tryParse(at) : null
        ..leftZone = value['left_zone'] == true
        ..episode = true;
    }
  }

  /// "Nanti" on the approaching banner: end this episode quietly.
  void dismissApproach(String id) {
    final tr = _tracks[id];
    if (tr != null && tr.state == PoiState.approaching) {
      tr.state = PoiState.outside;
    }
  }

  void reset() {
    _tracks.updateAll((_, __) => _Track());
    _lastTriggerAt = null;
    _weakSince = null;
    _weakBanner = false;
  }
}
