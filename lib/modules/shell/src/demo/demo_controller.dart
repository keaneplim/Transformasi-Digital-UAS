import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/routing/routing.dart';

import 'places.dart';

/// UI MOCK (2026-11-12). Stands in for the real engines until they land:
/// location (T01), trigger (T08), session (T16), audio (T07), reminders (T23/T28).
/// The visitor's position is simulated: tap a place, then "Mulai jalan" walks the dot along
/// the real trail graph (GraphTrailRouter), or "Saya di sini" teleports. No GPS needed.
/// Trigger rules are simplified (no debounce/cooldown) — the real TriggerEngine owns those.
class DemoController extends ChangeNotifier {
  DemoController(
      {required this.content, required this.router, required Clock clock})
      : _baseClock = clock,
        position = content.gate.position {
    places = [
      for (final p in content.pois) Place.poi(p),
      for (final f in content.facilities) Place.facility(f),
    ];
    _byId = {for (final p in places) p.id: p};
  }

  final ContentRepository content;
  final TrailRouter router;
  final Clock _baseClock;
  late final List<Place> places;
  late final Map<String, Place> _byId;

  Place? place(String id) => _byId[id];
  List<Place> get pois => places.where((p) => p.isPoi).toList();
  List<Place> get facilities => places.where((p) => !p.isPoi).toList();

  // ---- time (demo can jump the clock, e.g. to 15.30 for TC-10) ---------------------------
  Duration _clockOffset = Duration.zero;
  DateTime now() => _baseClock.now().add(_clockOffset);

  void setDemoTime(int hour, int minute) {
    final n = _baseClock.now();
    _clockOffset = DateTime(n.year, n.month, n.day, hour, minute).difference(n);
    notifyListeners();
  }

  void resetDemoTime() {
    _clockOffset = Duration.zero;
    notifyListeners();
  }

  DateTime get closingTime => content.park.closingTimeOn(now());
  DateTime get openingTime => content.park.openingTimeOn(now());
  Duration get timeToClose => closingTime.difference(now());
  bool get isOpen => now().isAfter(openingTime) && now().isBefore(closingTime);

  // ---- onboarding & preferences -----------------------------------------------------------
  bool onboarded = false;
  final Set<String> interests = {'sejarah', 'alam'};
  String routeId = 'santai';
  TrailRoute get route => content.routes.firstWhere((r) => r.id == routeId);

  void toggleInterest(String c) {
    interests.contains(c) ? interests.remove(c) : interests.add(c);
    notifyListeners();
  }

  void chooseRoute(String id) {
    routeId = id;
    notifyListeners();
  }

  void finishOnboarding() {
    onboarded = true;
    notifyListeners();
  }

  // ---- settings ----------------------------------------------------------------------------
  bool autoPlay = false;
  bool voiceGuidance = true;
  bool vibration = true;
  int hydrationMin = 45;
  double textScale = 1.0;
  double? weightKg;

  /// The simulated walk runs this many times faster than 3 km/h.
  double walkSpeedFactor = 25;

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  // ---- session ------------------------------------------------------------------------------
  bool sessionActive = false;
  DateTime? sessionStart;
  DateTime? sessionEnd;
  final Set<String> visited = {};
  final Set<String> triggered = {};
  double walkedM = 0;
  final List<GeoPoint> trail = [];

  int get steps => (walkedM / 0.72).round();
  Duration get sessionDuration => sessionStart == null
      ? Duration.zero
      : (sessionEnd ?? now()).difference(sessionStart!);
  double get kcal {
    // MET × kg × hours (D11); walking on trails ≈ MET 4.0.
    final h = sessionDuration.inSeconds / 3600;
    return 4.0 * (weightKg ?? 60) * h;
  }

  List<Place> get routePois => [
        for (final id in route.poiSequence.toSet())
          if (place(id) case final p? when !p.isGate) p,
      ];

  void startSession() {
    sessionActive = true;
    sessionStart = now();
    sessionEnd = null;
    visited.clear();
    triggered.clear();
    walkedM = 0;
    trail
      ..clear()
      ..add(position);
    _hydrationAnchor = now();
    notifyListeners();
  }

  void endSession() {
    sessionEnd = now();
    sessionActive = false;
    stopWalking();
    navigation = null;
    notifyListeners();
  }

  void resetAll() {
    endSession();
    sessionStart = null;
    sessionEnd = null;
    visited.clear();
    triggered.clear();
    walkedM = 0;
    trail.clear();
    position = content.gate.position;
    _approachedIds.clear();
    approaching = null;
    pendingTrigger = null;
    reminder = null;
    stopAudio();
    _clockOffset = Duration.zero;
    notifyListeners();
  }

  // ---- position (simulated) ----------------------------------------------------------------
  GeoPoint position;
  double headingDeg = 0;

  double walkingM(Place p) => router.walkingDistanceM(position, p.node);
  Duration walkingTime(Place p) => router.walkingTime(position, p.node);

  /// Places sorted by walking distance from the simulated position.
  List<Place> nearest({bool poisOnly = false, String? group, int? limit}) {
    final list = places
        .where((p) =>
            (!poisOnly || p.isPoi) && (group == null || p.group == group))
        .toList()
      ..sort((a, b) => walkingM(a).compareTo(walkingM(b)));
    return limit == null ? list : list.take(limit).toList();
  }

  void teleportTo(Place p) {
    stopWalking();
    _moveTo(p.position, record: false);
    notifyListeners();
  }

  // ---- triggers (simplified F02) ----------------------------------------------------------
  /// POI currently in the "approaching" ring (banner).
  ({Place place, double distanceM})? approaching;

  /// POI that just triggered (trigger card).
  Place? pendingTrigger;
  final Set<String> _approachedIds = {};

  void _evaluate() {
    final margin = content.park.param('approach_margin_m');
    final exitMargin = content.park.param('approach_exit_margin_m');
    ({Place place, double distanceM})? nearestApproach;
    Place? nearestTrigger;
    var nearestTriggerD = double.infinity;
    for (final p in pois) {
      final poi = p.poi!;
      final d = haversineM(position, p.position);
      if (d > poi.radiusM + exitMargin) _approachedIds.remove(p.id);
      if (triggered.contains(p.id) || visited.contains(p.id)) continue;
      if (p.isGate) continue; // D07: the gate offer lives on Home
      if (d <= poi.radiusM) {
        if (d < nearestTriggerD) {
          nearestTrigger = p;
          nearestTriggerD = d;
        }
      } else if (d <= poi.radiusM + margin) {
        if (!_approachedIds.contains(p.id) &&
            (nearestApproach == null || d < nearestApproach.distanceM)) {
          nearestApproach = (place: p, distanceM: d);
        }
      }
    }
    if (nearestTrigger != null && pendingTrigger == null) {
      triggered.add(nearestTrigger.id);
      approaching = null;
      pendingTrigger = nearestTrigger;
      if (vibration) HapticFeedback.heavyImpact();
      if (navigation != null) _pauseWalk = true;
      if (autoPlay) playAudio(nearestTrigger);
      return;
    }
    if (nearestApproach != null) {
      if (approaching?.place.id != nearestApproach.place.id && vibration) {
        HapticFeedback.mediumImpact();
      }
      approaching = nearestApproach;
    } else if (approaching != null) {
      final d = haversineM(position, approaching!.place.position);
      if (d > approaching!.place.poi!.radiusM + exitMargin ||
          triggered.contains(approaching!.place.id)) {
        _approachedIds.add(approaching!.place.id);
        approaching = null;
      } else {
        approaching = (place: approaching!.place, distanceM: d);
      }
    }
  }

  void dismissApproaching() {
    if (approaching != null) _approachedIds.add(approaching!.place.id);
    approaching = null;
    notifyListeners();
  }

  /// "Saya di sini" / QR / manual pick: straight to Triggered (QR: also Visited).
  void triggerNow(Place p, {bool viaQr = false}) {
    if (!p.isPoi) return;
    if (p.position != position) _moveTo(p.position, record: false);
    triggered.add(p.id);
    if (viaQr) visited.add(p.id);
    approaching = null;
    pendingTrigger = p;
    if (vibration) HapticFeedback.heavyImpact();
    notifyListeners();
  }

  /// Dengarkan / Lihat → visited (D05). Nanti → triggered only.
  void resolveTrigger({required bool engaged}) {
    final p = pendingTrigger;
    pendingTrigger = null;
    if (p != null && engaged) visited.add(p.id);
    if (_pauseWalk) {
      _pauseWalk = false;
    }
    notifyListeners();
  }

  void markVisited(Place p) {
    if (!p.isPoi) return;
    visited.add(p.id);
    triggered.add(p.id);
    notifyListeners();
  }

  // ---- navigation (simulated walk) --------------------------------------------------------
  ({Place to, RouteResult route})? navigation;
  double navProgressM = 0;
  bool walking = false;
  bool _pauseWalk = false;
  Place? arrivedAt;
  Timer? _walkTimer;
  DateTime? _lastTick;

  double get navRemainingM => navigation == null
      ? 0
      : math.max(0, navigation!.route.distanceM - navProgressM);
  Duration get navRemainingTime {
    final n = navigation;
    if (n == null || n.route.distanceM == 0) return Duration.zero;
    final f = navRemainingM / n.route.distanceM;
    return n.route.eta * f;
  }

  TurnInstruction? get nextTurn {
    final n = navigation;
    if (n == null) return null;
    for (final t in n.route.turns) {
      if (t.distanceFromStartM >= navProgressM - 2) return t;
    }
    return n.route.turns.isEmpty ? null : n.route.turns.last;
  }

  double get distanceToNextTurn =>
      math.max(0, (nextTurn?.distanceFromStartM ?? 0) - navProgressM);

  bool startNavigation(Place to) {
    final r = router.route(position, to.node);
    if (r == null) return false;
    stopWalking();
    navigation = (to: to, route: r);
    navProgressM = 0;
    arrivedAt = null;
    if (!sessionActive) startSession();
    notifyListeners();
    return true;
  }

  void cancelNavigation() {
    stopWalking();
    navigation = null;
    notifyListeners();
  }

  void toggleWalking() => walking ? stopWalking() : startWalking();

  void startWalking() {
    if (navigation == null) return;
    walking = true;
    _pauseWalk = false;
    _lastTick = null;
    _walkTimer?.cancel();
    _walkTimer = Timer.periodic(const Duration(milliseconds: 50), _tick);
    notifyListeners();
  }

  void stopWalking() {
    _walkTimer?.cancel();
    _walkTimer = null;
    walking = false;
  }

  void _tick(Timer t) {
    final n = navigation;
    if (n == null) return stopWalking();
    final stamp = _baseClock.now();
    final dt = _lastTick == null
        ? 0.05
        : stamp.difference(_lastTick!).inMicroseconds / 1e6;
    _lastTick = stamp;
    if (_pauseWalk || pendingTrigger != null) return;
    // 3 km/h = 0.833 m/s (D09 base speed), sped up for the demo.
    navProgressM = math.min(
        n.route.distanceM, navProgressM + 0.833 * walkSpeedFactor * dt);
    // Session clock advances with the simulated walk so durations look realistic.
    _clockOffset +=
        Duration(microseconds: (dt * (walkSpeedFactor - 1) * 1e6).round());
    final pos = _pointAlong(n.route.polyline, navProgressM);
    _moveTo(pos, record: true);
    if (navRemainingM <= content.park.param('arrival_m') * 0.2) {
      stopWalking();
      arrivedAt = n.to; // D06: arrival never triggers the POI again
      approaching = null;
      if (vibration) HapticFeedback.heavyImpact();
    }
    _checkReminders();
    notifyListeners();
  }

  void finishArrival() {
    navigation = null;
    arrivedAt = null;
    notifyListeners();
  }

  void _moveTo(GeoPoint p, {required bool record}) {
    if (record) {
      walkedM += haversineM(position, p);
      if (trail.isEmpty || haversineM(trail.last, p) > 4) trail.add(p);
    }
    if (haversineM(position, p) > 0.5) headingDeg = bearingDeg(position, p);
    position = p;
    _evaluate();
  }

  static GeoPoint _pointAlong(List<GeoPoint> line, double m) {
    var left = m;
    for (var i = 1; i < line.length; i++) {
      final a = line[i - 1], b = line[i];
      final seg = haversineM(a, b);
      if (left <= seg && seg > 0) {
        final f = left / seg;
        return GeoPoint(
            a.lat + (b.lat - a.lat) * f, a.lng + (b.lng - a.lng) * f);
      }
      left -= seg;
    }
    return line.last;
  }

  // ---- audio (mock: progress only, no sound until T07) -----------------------------------
  Place? nowPlaying;
  double audioPos = 0; // seconds
  bool audioPlaying = false;
  Timer? _audioTimer;

  int audioLength(Place p) => p.poi?.audioSeconds ?? 90;
  double get audioProgress => nowPlaying == null
      ? 0
      : (audioPos / audioLength(nowPlaying!)).clamp(0, 1);

  void playAudio(Place p) {
    if (nowPlaying?.id != p.id) audioPos = 0;
    nowPlaying = p;
    audioPlaying = true;
    markVisited(p);
    _audioTimer?.cancel();
    _audioTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      audioPos += 0.2;
      if (audioPos >= audioLength(nowPlaying!)) {
        audioPos = audioLength(nowPlaying!).toDouble();
        audioPlaying = false;
        _audioTimer?.cancel();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void toggleAudio(Place p) =>
      (audioPlaying && nowPlaying?.id == p.id) ? pauseAudio() : playAudio(p);

  void pauseAudio() {
    audioPlaying = false;
    _audioTimer?.cancel();
    notifyListeners();
  }

  void seekAudio(double fraction) {
    if (nowPlaying == null) return;
    audioPos = fraction * audioLength(nowPlaying!);
    notifyListeners();
  }

  void skipAudio(double seconds) {
    if (nowPlaying == null) return;
    audioPos =
        (audioPos + seconds).clamp(0, audioLength(nowPlaying!).toDouble());
    notifyListeners();
  }

  void stopAudio() {
    _audioTimer?.cancel();
    audioPlaying = false;
    nowPlaying = null;
    audioPos = 0;
  }

  // ---- reminders (A03 closing, F08 hydration) --------------------------------------------
  DemoReminder? reminder;
  DateTime? _hydrationAnchor;
  bool _closingShown = false;

  Duration get walkToGate =>
      router.walkingTime(position, content.gate.graphNode);

  /// A03: jam tutup − waktu jalan ke gerbang − 15 menit.
  DateTime get closingReminderAt => closingTime.subtract(walkToGate).subtract(
      Duration(minutes: content.park.param('closing_buffer_min').round()));

  void _checkReminders() {
    if (reminder != null || !sessionActive) return;
    if (!_closingShown && now().isAfter(closingReminderAt)) {
      _closingShown = true;
      reminder = DemoReminder.closing;
    } else if (hydrationMin > 0 &&
        _hydrationAnchor != null &&
        now().difference(_hydrationAnchor!).inMinutes >= hydrationMin) {
      _hydrationAnchor = now();
      reminder = DemoReminder.hydration;
    }
  }

  void showReminder(DemoReminder r) {
    reminder = r;
    if (vibration) HapticFeedback.mediumImpact();
    notifyListeners();
  }

  void dismissReminder() {
    reminder = null;
    _hydrationAnchor = now();
    notifyListeners();
  }

  // ---- recommendation (F07, simplified) ---------------------------------------------------
  Recommendation recommend() {
    final w = content.park.recWeights;
    final buffer =
        Duration(minutes: content.park.param('closing_buffer_min').round());
    final left = timeToClose - buffer;
    final gate = content.gate.graphNode;
    final candidates =
        <({Place place, double score, List<String> reasons, Duration total})>[];
    final dists = <String, double>{};
    for (final p in pois) {
      if (p.isGate || visited.contains(p.id)) continue;
      dists[p.id] = walkingM(p);
    }
    if (dists.isEmpty) return const Recommendation.backToGate(allVisited: true);
    final maxD = dists.values.reduce(math.max);
    for (final p in pois) {
      final d = dists[p.id];
      if (d == null) continue;
      final total = walkingTime(p) +
          Duration(minutes: p.poi!.visitMinutes) +
          router.walkingTimeBetween(p.node, gate);
      if (total > left) continue;
      final interest = interests.contains(p.kind) ? 1.0 : 0.0;
      final onRoute = p.poi!.routes.contains(routeId) ? 1.0 : 0.0;
      final easy = (3 - p.poi!.difficulty) / 2;
      final score = (w['dist'] ?? 0.5) * (1 - d / math.max(1, maxD)) +
          (w['interest'] ?? 0.25) * interest +
          (w['route'] ?? 0.15) * onRoute +
          (w['difficulty'] ?? 0.1) * easy;
      candidates.add((
        place: p,
        score: score,
        total: total,
        reasons: [
          if (d == dists.values.reduce(math.min)) 'Paling dekat',
          if (interest > 0)
            'Sesuai minat ${categoryLabel(p.kind).toLowerCase()}',
          if (onRoute > 0) 'Di rute ${route.name}',
          if (p.poi!.difficulty == 1) 'Jalur mudah',
          'Belum dikunjungi',
        ],
      ));
    }
    if (candidates.isEmpty) return const Recommendation.backToGate();
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return Recommendation(
      [
        for (final c in candidates.take(3)) (place: c.place, reasons: c.reasons)
      ],
    );
  }

  @override
  void dispose() {
    _walkTimer?.cancel();
    _audioTimer?.cancel();
    super.dispose();
  }
}

enum DemoReminder { closing, hydration }

class Recommendation {
  const Recommendation(this.items) : allVisited = false;
  const Recommendation.backToGate({this.allVisited = false}) : items = const [];

  final List<({Place place, List<String> reasons})> items;
  final bool allVisited;
  bool get backToGate => items.isEmpty;
}

final demoProvider =
    ChangeNotifierProvider<DemoController>((ref) => DemoController(
          content: ref.watch(contentRepositoryProvider),
          router: ref.watch(trailRouterProvider),
          clock: ref.watch(clockProvider),
        ));
