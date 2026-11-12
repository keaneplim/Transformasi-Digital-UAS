import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/modules/audio/audio.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/location/location.dart';
import 'package:jelajah_taman/modules/map/map.dart';
import 'package:jelajah_taman/modules/routing/routing.dart';
import 'package:jelajah_taman/modules/trigger/trigger.dart';

import 'places.dart';

/// Where the visitor's position comes from (ADR-009).
enum AppMode {
  /// Live GPS (default): triggers, navigation progress and walked distance follow the device.
  real,

  /// Simulated: "Mulai jalan" walks the dot along the trail graph, "Saya di sini" teleports,
  /// the clock can jump. For presentations and testing without being in the park.
  demo,
}

/// The guide state behind every screen (until the session/audio/notify engines land in their
/// own modules). Both modes feed positions into the real F02 [GeofenceEngine] and publish its
/// events on the [EventBus]; they differ only in where the position comes from.
class GuideController extends ChangeNotifier {
  GuideController({
    required this.content,
    required this.router,
    required Clock clock,
    this.player,
    this.location,
    KeyValueStore? store,
    this.bus,
    bool Function(GeoPoint)? insideZone,
  })  : _baseClock = clock,
        _store = store ?? MemoryKeyValueStore(),
        _insideZone = insideZone ?? ((_) => true),
        position = content.gate.position {
    places = [
      for (final p in content.pois) Place.poi(p),
      for (final f in content.facilities) Place.facility(f),
    ];
    _byId = {for (final p in places) p.id: p};
    _engine = GeofenceEngine(
      targets: buildGeofenceTargets(content, activeRouteId: routeId),
      params: GeofenceParams.fromPark(content.park),
    );
    mode =
        AppMode.values.asNameMap()[_store.getString(_modeKey)] ?? AppMode.real;
    final loc = location;
    if (loc != null) {
      _subs
        ..add(loc.fixes.listen(_onFix))
        ..add(loc.headings.listen(_onHeading))
        ..add(loc.quality.listen(_onQuality));
    }
    if (mode == AppMode.real) unawaited(_initLocation());
  }

  final ContentRepository content;
  final TrailRouter router;
  final Clock _baseClock;
  final NarrationPlayer? player;

  /// Device position; null where no GPS plugin is bound (tests, web preview).
  final LocationService? location;
  final EventBus? bus;
  final KeyValueStore _store;
  final bool Function(GeoPoint) _insideZone;
  late final GeofenceEngine _engine;
  final List<StreamSubscription<Object?>> _subs = [];
  static const _modeKey = 'app_mode';
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
    _engine.setTargets(buildGeofenceTargets(content, activeRouteId: id));
    notifyListeners();
  }

  void finishOnboarding() {
    onboarded = true;
    notifyListeners();
  }

  // ---- mode (real GPS / demo) ----------------------------------------------------------------
  late AppMode mode;
  bool get isDemo => mode == AppMode.demo;

  /// Switches the position source. The session restarts (positions from the two sources
  /// can't be mixed), the choice is remembered.
  void setMode(AppMode m) {
    if (m == mode) return;
    resetAll();
    mode = m;
    unawaited(_store.setString(_modeKey, m.name));
    fix = null;
    if (m == AppMode.real) {
      unawaited(_initLocation());
    } else {
      unawaited(location?.stop());
      position = content.gate.position;
    }
    notifyListeners();
  }

  // ---- live location (real mode) --------------------------------------------------------------
  /// Null = unknown or no GPS on this build.
  LocationAccess? access;

  /// Latest fix, weak ones too (real mode only).
  LocationFix? fix;
  GpsQuality quality = GpsQuality.none;
  bool _hasHeading = false;
  LocationFix? _lastGood;
  Timer? _heartbeat;

  bool get locationSupported => location != null;
  double get _weakM => content.park.param('gps_weak_accuracy_m');

  /// The dot is drawn (demo: always; real: once there is a fix).
  bool get showUser => isDemo || fix != null;

  /// Grey dot, no heading cone.
  bool get gpsWeak =>
      !isDemo &&
      (fix == null || fix!.isWeak(_weakM) || quality == GpsQuality.none);

  /// UI12 "GPS lemah" banner: weak or no fixes for 60 s during a session (D08).
  bool get gpsWeakBanner =>
      !isDemo &&
      sessionActive &&
      access == LocationAccess.granted &&
      _engine.weakBanner;

  double? get accuracyM => isDemo ? null : fix?.accuracyM;
  double? get heading =>
      isDemo ? headingDeg : (_hasHeading && !gpsWeak ? headingDeg : null);

  /// Real mode with a fix outside the visitor zone (e.g. at home): distances are then counted
  /// from the gate and screens show "Anda di luar kawasan".
  bool get outsideZone => !isDemo && fix != null && !_insideZone(fix!.position);

  /// Real mode without a usable position (no permission, GPS off, no fix yet).
  bool get noPosition => !isDemo && fix == null;

  /// Where walking distances and routes start: the visitor, or the gate when the visitor's
  /// position is unknown or outside the park.
  GeoPoint get origin => (isDemo || (fix != null && !outsideZone))
      ? position
      : content.gate.position;

  /// Straight-line distance from the visitor to the gate (outside-zone chip).
  double get distanceToGateM => haversineM(position, content.gate.position);

  Future<void> _initLocation() async {
    final loc = location;
    if (loc == null) return;
    try {
      access = await loc.access();
      if (access == LocationAccess.granted) await loc.start();
    } on Object catch (e) {
      AppLog.info('Location unavailable: $e');
    }
    if (!_disposed) notifyListeners();
  }

  /// Onboarding / "Aktifkan lokasi": asks the OS, starts updates when granted.
  Future<LocationAccess?> requestLocation() async {
    final loc = location;
    if (loc == null) return null;
    try {
      access = await loc.requestAccess();
      if (access == LocationAccess.granted) {
        await loc.start();
        if (sessionActive) await loc.startSession();
      }
    } on Object catch (e) {
      AppLog.info('Location request failed: $e');
    }
    if (!_disposed) notifyListeners();
    return access;
  }

  Future<void> openLocationSettings() async => location?.openSettings();

  void _onFix(LocationFix f) {
    if (isDemo) return;
    fix = f;
    position = f.position;
    if (f.headingDeg != null && !_hasHeading) headingDeg = f.headingDeg!;
    if (!f.isWeak(_weakM)) {
      _recordWalk(f);
      _navOnFix(f);
    }
    _apply(_engine.onFix(f, now()));
    _checkReminders();
    notifyListeners();
  }

  void _onHeading(double deg) {
    if (isDemo) return;
    _hasHeading = true;
    headingDeg = deg;
    notifyListeners();
  }

  void _onQuality(GpsQuality q) {
    if (isDemo || q == quality) return;
    quality = q;
    notifyListeners();
  }

  /// Walked distance and trail from good fixes: ≥ 3 m steps, jumps faster than 3.5 m/s
  /// (GPS glitches, a car) are skipped.
  void _recordWalk(LocationFix f) {
    final last = _lastGood;
    if (!sessionActive || last == null) {
      _lastGood = f;
      return;
    }
    final d = haversineM(last.position, f.position);
    if (d < 3) return;
    final dt = math.max(1, f.at.difference(last.at).inMilliseconds) / 1000;
    _lastGood = f;
    if (d / dt > 3.5) return;
    walkedM += d;
    if (trail.isEmpty || haversineM(trail.last, f.position) > 4) {
      trail.add(f.position);
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    if (isDemo || location == null) return;
    // reminders and the weak-GPS banner depend on time passing, not only on new fixes
    _heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
      final before = (reminder, gpsWeakBanner);
      _checkReminders();
      if ((reminder, gpsWeakBanner) != before) notifyListeners();
    });
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
      ..addAll([if (showUser && !outsideZone) position]);
    _lastGood = fix != null && !fix!.isWeak(_weakM)
        ? fix
        : null; // walking starts from here
    _hydrationAnchor = now();
    _closingShown = false;
    if (!isDemo) {
      unawaited(location?.startSession());
      _startHeartbeat();
    }
    notifyListeners();
  }

  void endSession() {
    sessionEnd = now();
    sessionActive = false;
    stopWalking();
    navigation = null;
    _heartbeat?.cancel();
    if (!isDemo) unawaited(location?.stopSession());
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
    if (isDemo) position = content.gate.position;
    _engine.reset();
    _queue.clear();
    approaching = null;
    pendingTrigger = null;
    reminder = null;
    stopAudio();
    _clockOffset = Duration.zero;
    notifyListeners();
  }

  // ---- position ------------------------------------------------------------------------------
  /// The dot: simulated (demo) or the latest fix (real).
  GeoPoint position;
  double headingDeg = 0;

  double walkingM(Place p) => router.walkingDistanceM(origin, p.node);
  Duration walkingTime(Place p) => router.walkingTime(origin, p.node);

  /// Places sorted by walking distance from the simulated position.
  List<Place> nearest({bool poisOnly = false, String? group, int? limit}) {
    final list = places
        .where((p) =>
            (!poisOnly || p.isPoi) && (group == null || p.group == group))
        .toList()
      ..sort((a, b) => walkingM(a).compareTo(walkingM(b)));
    return limit == null ? list : list.take(limit).toList();
  }

  /// Demo only: the real position comes from the GPS.
  void teleportTo(Place p) {
    if (!isDemo) return;
    stopWalking();
    _moveTo(p.position, record: false);
    notifyListeners();
  }

  // ---- triggers (F02 GeofenceEngine) -------------------------------------------------------
  /// POI currently in the "approaching" ring (banner).
  ({Place place, double distanceM})? approaching;

  /// POI that just triggered (trigger card).
  Place? pendingTrigger;

  /// Triggers that arrived while a card was open; shown one after another.
  final List<Place> _queue = [];

  PoiState stateOf(Place p) => _engine.stateOf(p.id);

  void _feedDemo(GeoPoint p) => _apply(
      _engine.onFix(LocationFix(position: p, accuracyM: 5, at: now()), now()));

  void _apply(List<DomainEvent> events) {
    for (final e in events) {
      bus?.publish(e);
      switch (e) {
        case PoiApproached():
          if (vibration && pendingTrigger == null) {
            HapticFeedback.mediumImpact();
          }
        case PoiTriggered(:final poiId):
          triggered.add(poiId);
          final p = place(poiId);
          if (p == null) break;
          if (pendingTrigger == null) {
            _showTrigger(p);
          } else if (pendingTrigger!.id != poiId && !_queue.contains(p)) {
            _queue.add(p);
          }
        case PoiVisited(:final poiId):
          visited.add(poiId);
        default:
          break;
      }
    }
    final a = _engine.approaching;
    approaching = a == null || pendingTrigger != null
        ? null
        : (place: place(a.id)!, distanceM: a.distanceM);
  }

  void _showTrigger(Place p) {
    approaching = null;
    pendingTrigger = p;
    if (vibration) HapticFeedback.heavyImpact();
    if (navigation != null) _pauseWalk = true;
    if (autoPlay) playAudio(p);
  }

  void dismissApproaching() {
    if (approaching != null) _engine.dismissApproach(approaching!.place.id);
    approaching = null;
    notifyListeners();
  }

  /// "Saya di sini" / QR / manual pick: straight to Triggered (QR: also Visited). In demo mode
  /// the dot jumps there too; in real mode the position stays the GPS one.
  void triggerNow(Place p, {bool viaQr = false}) {
    if (!p.isPoi) return;
    if (isDemo && p.position != position) _moveTo(p.position, record: false);
    pendingTrigger = null;
    final events =
        viaQr ? _engine.qr(p.id, now()) : _engine.manual(p.id, now());
    _apply(events);
    if (pendingTrigger?.id != p.id) {
      _showTrigger(p); // already visited: show the card anyway
    }
    triggered.add(p.id);
    approaching = null;
    notifyListeners();
  }

  /// Dengarkan / Lihat → visited (D05). Nanti → triggered only.
  void resolveTrigger({required bool engaged}) {
    final p = pendingTrigger;
    pendingTrigger = null;
    if (p != null && engaged) {
      _apply(_engine.onEngaged(p.id, EngagementKind.opened, now()));
    }
    _pauseWalk = false;
    while (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      if (!_engine.isVisited(next.id)) {
        _showTrigger(next);
        break;
      }
    }
    notifyListeners();
  }

  /// Engagement from anywhere (detail opened, narration played). Counts as a visit only for a
  /// POI that triggered this session (D05): reading about Gua Jepang at home is not a visit.
  void engage(Place p, EngagementKind how) {
    if (!p.isPoi) return;
    final before = visited.length;
    _apply(_engine.onEngaged(p.id, how, now()));
    if (visited.length != before) notifyListeners();
  }

  /// The visitor is at [p] for sure (arrival screen): triggered + visited without a card.
  void markVisited(Place p) {
    if (!p.isPoi) return;
    if (!_engine.isVisited(p.id)) {
      for (final e in _engine.manual(p.id, now())) {
        bus?.publish(e);
      }
      _apply(_engine.onEngaged(p.id, EngagementKind.nav, now()));
    }
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
    final r = router.route(origin, to.node);
    if (r == null) return false;
    stopWalking();
    navigation = (to: to, route: r);
    navProgressM = 0;
    arrivedAt = null;
    _offRoute = 0;
    if (!sessionActive) startSession();
    bus?.publish(NavigationStarted(at: now(), destinationId: to.id));
    notifyListeners();
    return true;
  }

  void cancelNavigation() {
    stopWalking();
    navigation = null;
    notifyListeners();
  }

  void toggleWalking() => walking ? stopWalking() : startWalking();

  /// Demo only: walks the dot along the route.
  void startWalking() {
    if (navigation == null || !isDemo) return;
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

  /// Times the route was recomputed after leaving it (real mode); the screen shows a toast.
  int reroutes = 0;
  int _offRoute = 0;

  /// Real navigation: progress = the fix projected onto the route; > 30 m off it for 2
  /// readings → new route from here; ≤ 15 m from the destination → arrived (D06, no trigger).
  void _navOnFix(LocationFix f) {
    final n = navigation;
    if (n == null || arrivedAt != null) return;
    final (along, off) = _project(n.route.polyline, f.position, navProgressM);
    if (off > content.park.param('offroute_m')) {
      _offRoute++;
      if (_offRoute >= content.park.param('offroute_readings')) {
        final r = router.route(f.position, n.to.node);
        if (r != null) {
          navigation = (to: n.to, route: r);
          navProgressM = 0;
          reroutes++;
        }
        _offRoute = 0;
      }
    } else {
      _offRoute = 0;
      navProgressM = math.max(navProgressM, along);
    }
    if (haversineM(f.position, n.to.position) <=
        content.park.param('arrival_m')) {
      arrivedAt = n.to;
      approaching = null;
      if (vibration) HapticFeedback.heavyImpact();
      bus?.publish(NavigationArrived(
          at: now(), destinationId: n.to.id, isPoi: n.to.isPoi));
    }
  }

  /// Distance along [line] of the point nearest to [p] (preferring the stretch from
  /// [fromM] − 40 m on, so a route that doubles back doesn't jump ahead), and how far off it is.
  static (double, double) _project(
      List<GeoPoint> line, GeoPoint p, double fromM) {
    final kx = 111320 * math.cos(p.lat * math.pi / 180);
    const ky = 110540.0;
    var acc = 0.0;
    var best = (fromM, double.infinity);
    for (var i = 1; i < line.length; i++) {
      final a = line[i - 1], b = line[i];
      final ax = (a.lng - p.lng) * kx, ay = (a.lat - p.lat) * ky;
      final bx = (b.lng - p.lng) * kx, by = (b.lat - p.lat) * ky;
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
      final cx = ax + dx * t, cy = ay + dy * t;
      final d = math.sqrt(cx * cx + cy * cy);
      final seg = math.sqrt(len2);
      final along = acc + seg * t;
      if (along >= fromM - 40 && d < best.$2) best = (along, d);
      acc += seg;
    }
    return best;
  }

  void _moveTo(GeoPoint p, {required bool record}) {
    if (record) {
      walkedM += haversineM(position, p);
      if (trail.isEmpty || haversineM(trail.last, p) > 4) trail.add(p);
    }
    if (haversineM(position, p) > 0.5) headingDeg = bearingDeg(position, p);
    position = p;
    _feedDemo(p);
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

  // ---- audio -------------------------------------------------------------------------------
  // POIs with a narration file (`audio` in pois.json) play it through [player] (just_audio,
  // bound in the composition root). Without a player (tests) or without a file (TTS fallback,
  // T07) the progress is simulated with a timer.
  Place? nowPlaying;
  double audioPos = 0; // seconds
  bool audioPlaying = false;
  Timer? _audioTimer;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<void>? _doneSub;
  final Map<String, double> _fileSeconds = {};

  bool _usesFile(Place p) => player != null && p.poi?.audio != null;

  double audioLength(Place p) =>
      _fileSeconds[p.id] ?? (p.poi?.audioSeconds ?? 90).toDouble();
  double get audioProgress => nowPlaying == null
      ? 0
      : (audioPos / audioLength(nowPlaying!)).clamp(0, 1);

  void playAudio(Place p) {
    final switching = nowPlaying?.id != p.id;
    if (switching) {
      _stopPlayback();
      audioPos = 0;
    }
    nowPlaying = p;
    audioPlaying = true;
    engage(p, EngagementKind.listened);
    if (_usesFile(p)) {
      unawaited(_playFile(p, fresh: switching));
    } else {
      _startTimer();
    }
    notifyListeners();
  }

  Future<void> _playFile(Place p, {required bool fresh}) async {
    final pl = player!;
    try {
      if (fresh) {
        final d = await pl.open(narrationAsset(p.poi!.audio!));
        if (d != null) _fileSeconds[p.id] = d.inMilliseconds / 1000;
        _posSub = pl.position.listen((d) {
          if (nowPlaying?.id != p.id) return;
          audioPos = (d.inMilliseconds / 1000).clamp(0, audioLength(p));
          notifyListeners();
        });
        _doneSub = pl.completed.listen((_) {
          if (nowPlaying?.id != p.id) return;
          audioPos = audioLength(p);
          audioPlaying = false;
          notifyListeners();
        });
      }
      // Paused or switched while loading: don't start.
      if (nowPlaying?.id != p.id || !audioPlaying) return;
      // Replay from the start after the end.
      if (audioPos >= audioLength(p) - 0.3) audioPos = 0;
      await pl.seek(Duration(milliseconds: (audioPos * 1000).round()));
      await pl.play();
    } catch (e) {
      AppLog.info('Narration file failed for ${p.id}: $e — simulating instead');
      _startTimer();
    }
  }

  void _startTimer() {
    _audioTimer?.cancel();
    if (audioPos >= audioLength(nowPlaying!)) audioPos = 0;
    _audioTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      audioPos += 0.2;
      if (audioPos >= audioLength(nowPlaying!)) {
        audioPos = audioLength(nowPlaying!);
        audioPlaying = false;
        _audioTimer?.cancel();
      }
      notifyListeners();
    });
  }

  void _stopPlayback() {
    _audioTimer?.cancel();
    _posSub?.cancel();
    _doneSub?.cancel();
    _posSub = null;
    _doneSub = null;
    if (player != null) unawaited(player!.stop());
  }

  void toggleAudio(Place p) =>
      (audioPlaying && nowPlaying?.id == p.id) ? pauseAudio() : playAudio(p);

  void pauseAudio() {
    audioPlaying = false;
    _audioTimer?.cancel();
    if (nowPlaying != null && _usesFile(nowPlaying!)) {
      unawaited(player!.pause());
    }
    notifyListeners();
  }

  void seekAudio(double fraction) {
    if (nowPlaying == null) return;
    audioPos = fraction * audioLength(nowPlaying!);
    if (_usesFile(nowPlaying!)) {
      unawaited(
          player!.seek(Duration(milliseconds: (audioPos * 1000).round())));
    }
    notifyListeners();
  }

  void skipAudio(double seconds) {
    if (nowPlaying == null) return;
    seekAudio(((audioPos + seconds).clamp(0, audioLength(nowPlaying!))) /
        audioLength(nowPlaying!));
  }

  void stopAudio() {
    _stopPlayback();
    audioPlaying = false;
    nowPlaying = null;
    audioPos = 0;
  }

  // ---- reminders (A03 closing, F08 hydration) --------------------------------------------
  GuideReminder? reminder;
  DateTime? _hydrationAnchor;
  bool _closingShown = false;

  Duration get walkToGate => router.walkingTime(origin, content.gate.graphNode);

  /// A03: jam tutup − waktu jalan ke gerbang − 15 menit.
  DateTime get closingReminderAt => closingTime.subtract(walkToGate).subtract(
      Duration(minutes: content.park.param('closing_buffer_min').round()));

  void _checkReminders() {
    if (reminder != null || !sessionActive) return;
    if (!_closingShown && now().isAfter(closingReminderAt)) {
      _closingShown = true;
      reminder = GuideReminder.closing;
    } else if (hydrationMin > 0 &&
        _hydrationAnchor != null &&
        now().difference(_hydrationAnchor!).inMinutes >= hydrationMin) {
      _hydrationAnchor = now();
      reminder = GuideReminder.hydration;
    }
  }

  void showReminder(GuideReminder r) {
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

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _walkTimer?.cancel();
    _heartbeat?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _stopPlayback();
    super.dispose();
  }
}

enum GuideReminder { closing, hydration }

class Recommendation {
  const Recommendation(this.items) : allVisited = false;
  const Recommendation.backToGate({this.allVisited = false}) : items = const [];

  final List<({Place place, List<String> reasons})> items;
  final bool allVisited;
  bool get backToGate => items.isEmpty;
}

final guideProvider = ChangeNotifierProvider<GuideController>((ref) {
  final scene = ref.watch(mapSceneProvider);
  return GuideController(
    content: ref.watch(contentRepositoryProvider),
    router: ref.watch(trailRouterProvider),
    clock: ref.watch(clockProvider),
    player: ref.watch(narrationPlayerProvider),
    location: ref.watch(locationServiceProvider),
    store: ref.watch(keyValueStoreProvider),
    bus: ref.watch(eventBusProvider),
    insideZone: scene.isInsideZone,
  );
});
