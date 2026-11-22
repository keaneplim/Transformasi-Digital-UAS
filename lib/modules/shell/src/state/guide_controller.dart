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
import 'package:jelajah_taman/modules/recommendation/recommendation.dart';
import 'package:jelajah_taman/modules/reminders/reminders.dart';
import 'package:jelajah_taman/modules/routing/routing.dart';
import 'package:jelajah_taman/modules/session/session.dart';
import 'package:jelajah_taman/modules/trigger/trigger.dart';
import 'package:jelajah_taman/modules/wellness/wellness.dart';

import 'guide_prefs.dart';
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
    this.voice,
    this.location,
    this.stepTracker,
    KeyValueStore? store,
    this.bus,
    bool Function(GeoPoint)? insideZone,
    TimeBudget? timeBudget,
  })  : _baseClock = clock,
        _store = store ?? MemoryKeyValueStore(),
        _insideZone = insideZone ?? ((_) => true),
        position = content.gate.position {
    places = [
      for (final p in content.pois) Place.poi(p),
      for (final f in content.facilities) Place.facility(f),
    ];
    _byId = {for (final p in places) p.id: p};
    _loadPrefs();
    _engine = GeofenceEngine(
      targets: buildGeofenceTargets(content, activeRouteId: routeId),
      params: GeofenceParams.fromPark(content.park),
    );
    mode =
        AppMode.values.asNameMap()[_store.getString(_modeKey)] ?? AppMode.real;
    _sessions = SessionStore(_store);
    budget = timeBudget ?? TimeBudget.fromContent(content, router);
    final finalCallMinM = _parkParam('final_call_min_distance_m', 200);
    _reminders = ReminderScheduler([
      ClosingReminder(budget, gatePoiId: content.gate.id),
      FinalCallReminder(budget,
          gatePoiId: content.gate.id, minDistanceM: finalCallMinM),
      const HydrationReminder(),
    ]);
    _reminderStore = ReminderStore(_store);
    _trackingPolicy =
        TrackingPolicy(params: TrackingPolicyParams.fromPark(content.park));
    final loc = location;
    if (loc != null) {
      _subs
        ..add(loc.fixes.listen(_onFix))
        ..add(loc.headings.listen(_onHeading))
        ..add(loc.quality.listen(_onQuality));
    }
    final pl = player;
    if (pl != null) _subs.add(pl.commands.listen(onMediaCommand));
    // Without an Indonesian voice the arbiter drops every line, so reading aloud would rush
    // through the text in silence: then the progress stays simulated.
    unawaited(voice?.support.then((s) {
      _voiceReady = s != VoiceSupport.missing;
    }, onError: (Object _) {}));
    stepTracker?.onChange = () {
      if (_disposed) return;
      _onStepsChanged();
      _persist();
      notifyListeners();
    };
    _restoreSession();
    if (mode == AppMode.real) unawaited(_initLocation());
  }

  final ContentRepository content;
  final TrailRouter router;
  final Clock _baseClock;
  final NarrationPlayer? player;

  /// The guide's voice (VoiceArbiter); reads a POI text aloud when its recording is missing
  /// or fails (T07). Null in tests and the web preview.
  final TtsService? voice;

  /// Device position; null where no GPS plugin is bound (tests, web preview).
  final LocationService? location;

  /// The phone's step counter (F08, TC-12); null where no plugin is bound (tests, preview).
  final StepTracker? stepTracker;
  final EventBus? bus;
  final KeyValueStore _store;
  final bool Function(GeoPoint) _insideZone;
  late final GeofenceEngine _engine;
  late final SessionStore _sessions;
  late final TrackingPolicy _trackingPolicy;
  int _lastPolicySteps = 0;
  final List<StreamSubscription<Object?>> _subs = [];
  static const _modeKey = 'app_mode';

  /// App version shown in Settings UI15 (kept in sync with pubspec.yaml).
  static const appVersion = '0.1.0';

  late final List<Place> places;
  late final Map<String, Place> _byId;

  double _parkParam(String key, double fallback) {
    try {
      return content.park.param(key);
    } on StateError {
      return fallback;
    }
  }

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

  /// Fine clock control from the hidden debug menu (T31 / TC-10): moves simulated time
  /// and evaluates reminders right away.
  void shiftClock(Duration delta) {
    _clockOffset += delta;
    if (sessionActive) _checkReminders();
    notifyListeners();
  }

  /// Sets simulated time of day from the hidden debug menu and checks reminders at once.
  void setClockTime(int hour, int minute) {
    final n = _baseClock.now();
    _clockOffset = DateTime(n.year, n.month, n.day, hour, minute).difference(n);
    if (sessionActive) _checkReminders();
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
    _savePrefs();
    notifyListeners();
  }

  void chooseRoute(String id) {
    routeId = id;
    _engine.setTargets(buildGeofenceTargets(content, activeRouteId: id));
    _persist(force: true);
    _savePrefs();
    notifyListeners();
  }

  void finishOnboarding() {
    onboarded = true;
    _savePrefs();
    notifyListeners();
  }

  /// #32: what the visitor chose survives closing the app (onboarding, Settings, Home).
  void _loadPrefs() {
    final p = GuidePrefs.load(_store,
        defaults: GuidePrefs(
            hydrationMin: content.park.param('hydration_default_min').round()));
    onboarded = p.onboarded;
    autoPlay = p.autoPlay;
    voiceGuidance = p.voiceGuidance;
    vibration = p.vibration;
    hydrationMin = p.hydrationMin;
    textScale = p.textScale;
    weightKg = p.weightKg;
    interests
      ..clear()
      ..addAll(p.interests);
    if (content.routes.any((r) => r.id == p.routeId)) routeId = p.routeId;
  }

  GuidePrefs get prefs => GuidePrefs(
        onboarded: onboarded,
        autoPlay: autoPlay,
        voiceGuidance: voiceGuidance,
        vibration: vibration,
        hydrationMin: hydrationMin,
        textScale: textScale,
        weightKg: weightKg,
        interests: {...interests},
        routeId: routeId,
      );

  void _savePrefs() => unawaited(prefs.save(_store));

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
      _debugWeakGps ||
      (!isDemo &&
          sessionActive &&
          access == LocationAccess.granted &&
          _engine.weakBanner);

  // ---- hidden debug menu (T31 / §6.5) -------------------------------------------------------
  bool debugMenuUnlocked = false;
  bool debugOverlay = false;
  bool _debugWeakGps = false;

  bool get debugWeakGps => _debugWeakGps;

  /// Active GPS polling interval (T25 / A06): 3 s while moving, 10 s while stationary.
  Duration get activeGpsInterval =>
      location?.currentInterval ?? _trackingPolicy.interval;

  TrackingMode get trackingMode => _trackingPolicy.mode;

  /// Per-POI geofence diagnostics for the Explore debug overlay (T31).
  List<GeofenceDebugEntry> get geofenceDebug => _engine.debugSnapshot();

  void unlockDebugMenu() {
    if (debugMenuUnlocked) return;
    debugMenuUnlocked = true;
    notifyListeners();
  }

  void lockDebugMenu() {
    debugMenuUnlocked = false;
    debugOverlay = false;
    _debugWeakGps = false;
    notifyListeners();
  }

  void setDebugOverlay(bool on) {
    if (debugOverlay == on) return;
    debugOverlay = on;
    notifyListeners();
  }

  void setDebugWeakGps(bool on) {
    if (_debugWeakGps == on) return;
    _debugWeakGps = on;
    notifyListeners();
  }

  /// Compact plain-text snapshot for QA testing reports (copied from the debug menu).
  String debugLogSummary() {
    final buf = StringBuffer()
      ..writeln(
          'Jelajah Taman v$appVersion (konten v${content.contentVersion})')
      ..writeln('Waktu: ${clockLabel(now())} · Mode: ${mode.name}')
      ..writeln('GPS: ${quality.name}'
          '${accuracyM != null ? " (±${accuracyM!.round()} m)" : ""}'
          ' · Interval: ${activeGpsInterval.inSeconds} dtk (${trackingMode.name})')
      ..writeln('Sesi: ${sessionActive ? "aktif" : "tidak aktif"}'
          ' · Rute: ${route.name}')
      ..writeln('Langkah: ${stepsKnown ? steps : "–"}'
          ' · Jarak: ${walkedM.round()} m'
          ' · Energi: ±${kcal.round()} kkal')
      ..writeln('Dikunjungi (${visited.length}): ${visited.join(", ")}')
      ..writeln('Terpicu (${triggered.length}): ${triggered.join(", ")}')
      ..writeln(
          'Rekomendasi (${recommendationLog.length}): ${recommendationLog.map((e) => "${e.afterPoiId}->${e.poiIds.join("/")}").join("; ")}');
    return buf.toString().trimRight();
  }

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
      if (access == LocationAccess.granted) {
        await loc.start();
        // A session restored at launch needs the foreground service again. Started here,
        // after start(), so the two calls can't race each other.
        if (sessionActive) await loc.startSession();
      }
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
    _recordWalk(f);
    if (!f.isWeak(_weakM)) _navOnFix(f);
    // Geofences only run during a session (D07, #31): before "Mulai jelajah" (or at home)
    // nothing triggers; the map still shows the dot.
    if (sessionActive) {
      _apply(_engine.onFix(f, now()));
      _trackingPolicy.onFix(f, now(), keepFast: _keepFastGps);
      _syncGpsInterval();
    }
    _checkReminders();
    _persist();
    notifyListeners();
  }

  bool get _keepFastGps => approaching != null || navigation != null;

  void _onStepsChanged() {
    final current = stepTracker?.steps ?? 0;
    if (current > _lastPolicySteps) {
      _lastPolicySteps = current;
      if (sessionActive && !isDemo) {
        _trackingPolicy.onStep(now());
        _syncGpsInterval();
      }
    }
  }

  void _syncGpsInterval() {
    final loc = location;
    if (!sessionActive || isDemo || loc == null) return;
    final target = _trackingPolicy.interval;
    if (loc.currentInterval != target) {
      unawaited(loc.setInterval(target));
    }
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

  /// Walked distance, active time and trail during a session (T27): [ActivityMeter] keeps
  /// fixes with accuracy ≤ 20 m that moved more than max(3 m, accuracy / 2) and drops
  /// glitch jumps faster than 3.5 m/s.
  void _recordWalk(LocationFix f) {
    if (!sessionActive) return;
    if (_meter.add(f.position, f.at, accuracyM: f.accuracyM)) {
      _addTrail(f.position);
    }
  }

  void _addTrail(GeoPoint p) {
    if (trail.isEmpty || haversineM(trail.last, p) > 4) trail.add(p);
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    if (isDemo || location == null) return;
    // reminders and the weak-GPS banner depend on time passing, not only on new fixes
    _heartbeat = Timer.periodic(const Duration(seconds: 5), (_) => heartbeat());
  }

  /// One heartbeat (every 5 s during a real-mode session): no fixes at all also count as
  /// weak GPS (D08), and reminders fire on time. Public so tests and goldens can step time.
  void heartbeat() {
    final before = (reminder, gpsWeakBanner, _trackingPolicy.mode);
    _engine.tick(now());
    if (sessionActive && !isDemo) {
      _trackingPolicy.tick(now(), keepFast: _keepFastGps);
      _syncGpsInterval();
    }
    _checkReminders();
    if ((reminder, gpsWeakBanner, _trackingPolicy.mode) != before) {
      notifyListeners();
    }
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

  /// Settings change: applied, remembered on the phone (#32), shown.
  void update(VoidCallback change) {
    change();
    _savePrefs();
    notifyListeners();
  }

  // ---- session ------------------------------------------------------------------------------
  bool sessionActive = false;
  DateTime? sessionStart;
  DateTime? sessionEnd;
  final Set<String> visited = {};
  final Set<String> triggered = {};
  final List<GeoPoint> trail = [];

  /// Walked distance, active time and kcal of the session (F08, D11).
  late final ActivityMeter _meter =
      ActivityMeter(elevationAt: router.elevationAt);

  double get walkedM => _meter.distanceM;

  /// Previews and tests: a distance without the walk (counted as flat walking at 3 km/h).
  set walkedM(double m) => _meter.distanceM = m;

  /// Minutes actually walking (UC-F08-2 "active time"); the summary shows it under the kcal.
  Duration get activeTime => _meter.activeTime;

  /// Of [activeTime], walking up a slope steeper than 8 % (MET 6,0 instead of 3,5).
  Duration get climbTime => _meter.climbTime;

  /// Real mode on a phone: the hardware step counter (TC-12). Demo mode, tests and the web
  /// preview: estimated from the walked distance (0,72 m per step).
  bool get _sensorSteps => !isDemo && stepTracker != null;
  int get steps => _sensorSteps ? stepTracker!.steps : (walkedM / 0.72).round();

  /// False when the phone can't count steps (no sensor, "Aktivitas fisik" not allowed): the
  /// screens then show "–" instead of a number (plan F08 edge case, Risk R4).
  bool get stepsKnown =>
      !_sensorSteps ||
      (stepTracker!.status != StepStatus.denied &&
          stepTracker!.status != StepStatus.noSensor);

  /// Onboarding / Settings "Aktivitas fisik": asks the OS. True when allowed (or nothing to
  /// ask). Allowed during a session: steps are counted from now on.
  Future<bool> requestActivity() async {
    final ok = await stepTracker?.requestAccess() ?? true;
    if (ok) await refreshAccess();
    return ok;
  }

  /// Back from the phone's settings or a permission dialog (Settings → "Izin ponsel"):
  /// location and step counting pick up a permission given meanwhile.
  Future<void> refreshAccess() async {
    if (isDemo || _disposed) return;
    await _initLocation();
    final st = stepTracker;
    if (st != null && sessionActive && st.status == StepStatus.denied) {
      await st.start(restore: st.toJson());
    }
    if (!_disposed) notifyListeners();
  }

  Duration get sessionDuration => sessionStart == null
      ? Duration.zero
      : (sessionEnd ?? now()).difference(sessionStart!);

  /// D11: MET 3,5 on flat or gentle ground, 6,0 on climbs > 8 % (heights from the trail
  /// graph), × body weight (default 60 kg) × active hours. Always labelled as an estimate.
  double get kcal => _meter.kcal(weightKg: weightKg);

  List<Place> get routePois => [
        for (final id in route.poiSequence.toSet())
          if (place(id) case final p? when !p.isGate) p,
      ];

  void startSession() {
    if (_record != null && !_record!.isEnded) _finishRecord();
    sessionActive = true;
    sessionStart = now();
    sessionEnd = null;
    visited.clear();
    triggered.clear();
    // Every session starts with fresh geofences: a POI visited in the previous session must
    // be able to trigger again (D02 is "visited for the session", not forever).
    _engine.reset();
    _queue.clear();
    pendingTrigger = null;
    approaching = null;
    _meter.start();
    trail
      ..clear()
      ..addAll([if (showUser && !outsideZone) position]);
    // Walking starts from here (a usable fix, or the simulated dot).
    if (isDemo) {
      _meter.anchor(position, now());
    } else if (fix case final f?
        when f.accuracyM <= ActivityMeter.maxAccuracyM) {
      _meter.anchor(f.position, f.at);
    }
    _reminders.reset();
    _trackingPolicy.reset();
    _lastPolicySteps = 0;
    _recommendedFor.clear();
    recommendationCue = null;
    _record = SessionRecord(
      id: 's${sessionStart!.millisecondsSinceEpoch}',
      startedAt: sessionStart!,
      mode: mode.name,
      routeId: routeId,
      interests: interests.toList(),
    );
    _persist(force: true);
    _saveReminders();
    bus?.publish(SessionStarted(
        at: sessionStart!,
        sessionId: _record!.id,
        routeId: routeId,
        interests: interests.toList()));
    if (!isDemo) {
      unawaited(location?.startSession());
      unawaited(stepTracker?.start());
      _startHeartbeat();
    }
    notifyListeners();
  }

  void endSession() {
    final wasActive = sessionActive;
    sessionEnd = now();
    sessionActive = false;
    stopWalking();
    navigation = null;
    _heartbeat?.cancel();
    _trackingPolicy.reset();
    _lastPolicySteps = 0;
    if (!isDemo) unawaited(location?.stopSession());
    unawaited(stepTracker?.stop()); // the count stays for the summary
    if (wasActive && _record != null) {
      final id = _record!.id;
      _finishRecord();
      unawaited(_reminderStore.clear());
      bus?.publish(SessionEnded(at: sessionEnd!, sessionId: id));
    }
    notifyListeners();
  }

  // ---- session log + restore (PB06) ---------------------------------------------------------
  /// The running session as stored on the device; null when no session runs.
  SessionRecord? _record;
  DateTime? _lastSave;

  /// What triggered and was visited this session, in order (field-test evidence).
  List<VisitEvent> get visitLog => List.unmodifiable(_record?.events ?? []);

  /// Writes the running session. Events and lifecycle changes save at once ([force]);
  /// walking progress at most every 15 s so a moving visitor doesn't write on every fix.
  void _persist({bool force = false}) {
    final r = _record;
    if (r == null || r.isEnded || !sessionActive) return;
    final stamp = _baseClock.now();
    if (!force &&
        _lastSave != null &&
        stamp.difference(_lastSave!) < const Duration(seconds: 15)) {
      return;
    }
    _lastSave = stamp;
    r
      ..routeId = routeId
      ..interests = interests.toList()
      ..walkedM = walkedM
      ..trail.replaceRange(0, r.trail.length, trail)
      ..triggerState = _engine.toJson()
      ..stepState = _sensorSteps ? stepTracker!.toJson() : null
      ..activityState = _meter.toJson();
    unawaited(_sessions.save(r));
  }

  void _finishRecord() {
    final r = _record;
    if (r == null) return;
    r
      ..endedAt = sessionEnd ?? now()
      ..walkedM = walkedM
      ..trail.replaceRange(0, r.trail.length, trail)
      ..triggerState = _engine.toJson()
      ..stepState = _sensorSteps ? stepTracker!.toJson() : r.stepState
      ..activityState = _meter.toJson();
    unawaited(_sessions.finish(r));
    _record = null;
  }

  /// At launch: continue a session the OS killed (same day, same mode), or archive a stale one.
  void _restoreSession() {
    final r = _sessions.loadCurrent();
    if (r == null) return;
    if (!r.canResume(now: now(), mode: mode.name)) {
      r.endedAt ??= r.startedAt.isAfter(now()) ? r.startedAt : now();
      unawaited(_sessions.finish(r));
      return;
    }
    final known = {for (final p in pois) p.id};
    _record = r;
    sessionActive = true;
    sessionStart = r.startedAt;
    sessionEnd = null;
    onboarded = true; // a session can only have been started after onboarding
    if (content.routes.any((x) => x.id == r.routeId)) routeId = r.routeId;
    interests
      ..clear()
      ..addAll(r.interests);
    _engine.setTargets(buildGeofenceTargets(content, activeRouteId: routeId));
    final state = r.triggerState;
    if (state != null) _engine.restore(state);
    triggered
      ..clear()
      ..addAll(r.triggeredIds.where(known.contains));
    visited
      ..clear()
      ..addAll(r.visitedIds.where(known.contains));
    _meter.restore(r.activityState, walkedM: r.walkedM);
    trail
      ..clear()
      ..addAll(r.trail);
    if (isDemo && trail.isNotEmpty) position = trail.last;
    if (isDemo) _meter.anchor(position, now());
    // What was already shown stays shown: no second closing reminder after a restart.
    final shown = _reminderStore.load(r.id);
    if (shown != null) _reminders.restore(shown);
    // A POI that already got its recommendation doesn't open the sheet again.
    _recommendedFor
      ..clear()
      ..addAll(r.recommendations.map((e) => e.afterPoiId));
    // Real mode: tracking restarts in _initLocation once the GPS is running. Steps continue
    // from the stored count; the sensor kept counting while the app was closed.
    if (!isDemo) {
      _startHeartbeat();
      unawaited(stepTracker?.start(restore: r.stepState));
    }
    AppLog.info('Session ${r.id} restored: ${visited.length} visited, '
        '${walkedM.round()} m walked');
  }

  void _logEvents(List<DomainEvent> events) {
    final r = _record;
    if (r == null || !sessionActive) return;
    var changed = false;
    for (final e in events) {
      switch (e) {
        case PoiTriggered(:final at, :final poiId, :final source):
          r.events.add(VisitEvent(
              at: at,
              poiId: poiId,
              kind: VisitKind.triggered,
              how: source.name));
          changed = true;
        case PoiVisited(:final at, :final poiId, :final how):
          r.events.add(VisitEvent(
              at: at, poiId: poiId, kind: VisitKind.visited, how: how.name));
          changed = true;
        default:
          break;
      }
    }
    if (changed) _persist(force: true);
  }

  void resetAll() {
    endSession();
    sessionStart = null;
    sessionEnd = null;
    visited.clear();
    triggered.clear();
    _meter.start();
    trail.clear();
    if (isDemo) position = content.gate.position;
    _engine.reset();
    unawaited(stepTracker?.reset());
    _queue.clear();
    approaching = null;
    pendingTrigger = null;
    reminder = null;
    reminderDue = null;
    recommendationCue = null;
    _recommendedFor.clear();
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
        // PoiApproached: sound + vibration come from TriggerAlerts (PB07), via the bus.
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
        case PoiFinished(:final poiId, :final reason, :final at):
          // Engine events (leftArea) are already on the bus.
          _onFinished(poiId, reason, at, publish: false);
        default:
          break;
      }
    }
    final a = _engine.approaching;
    approaching = a == null || pendingTrigger != null
        ? null
        : (place: place(a.id)!, distanceM: a.distanceM);
    _logEvents(events);
  }

  /// Speaks the trigger prompt (VoiceAlerts, F04 b); completes when it has been said. Null
  /// without a voice (tests, preview): Auto-Play then starts at once.
  Future<void> Function(Place p)? announceTrigger;

  /// F04 AC2: Auto-Play starts the narration at most this long after the trigger.
  static const autoPlayWithin = Duration(seconds: 3);

  void _showTrigger(Place p) {
    approaching = null;
    pendingTrigger = p;
    recommendationCue = null; // a new place beats "where next" for the last one
    // Vibration (app visible) or the lock-screen notification (app hidden): TriggerAlerts.
    if (navigation != null) _pauseWalk = true;
    final announce = announceTrigger?.call(p);
    if (!autoPlay) return;
    if (announce == null) {
      playAudio(p);
      return;
    }
    // After the short prompt ("Anda tiba di …"), or at 3 s if the voice is slow or stuck.
    unawaited(announce.timeout(autoPlayWithin, onTimeout: () {}).then((_) {
      if (_disposed || !autoPlay || pendingTrigger?.id != p.id) return;
      // Dengarkan pressed meanwhile.
      if (audioPlaying && nowPlaying?.id == p.id) return;
      playAudio(p);
    }));
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

  /// A02: a scanned board. Triggered + Visited at once (PRD §4.2), logged with source `qr`.
  /// No trigger card: scanning already says "show me this place", so the scanner opens POI
  /// Detail itself (UC-A02-1). Starts a session if none runs (the visit must be logged).
  void scanQr(Place p) {
    if (!p.isPoi) return;
    if (!sessionActive) startSession();
    if (isDemo && p.position != position) {
      stopWalking();
      _moveTo(p.position, record: false);
    }
    final events = _engine.qr(p.id, now());
    for (final e in events) {
      bus?.publish(e);
    }
    triggered.add(p.id);
    visited.add(p.id);
    if (pendingTrigger?.id == p.id) pendingTrigger = null;
    _queue.removeWhere((q) => q.id == p.id);
    approaching = null;
    _logEvents(events);
    notifyListeners();
  }

  /// UC-A02-3 "Pilih manual" order: nearest first while the position is known, otherwise
  /// alphabetical (walking distances from the gate would mean nothing). Gate left out.
  List<Place> get manualPickList {
    final list = noPosition
        ? (pois.toList()..sort((a, b) => a.name.compareTo(b.name)))
        : nearest(poisOnly: true);
    return [
      for (final p in list)
        if (!p.isGate) p
    ];
  }

  /// UC-A02-3 / F01 AC4 "Pilih manual": the visitor says where they are when GPS can't
  /// (cave, permission denied). Triggered with source `manual`, and the screen opens POI
  /// Detail at once, which counts as opening it (D05). No trigger card or spoken prompt: the
  /// visitor already chose the place. Starts a session if none runs, like a QR scan, so the
  /// visit is logged.
  void manualPick(Place p) {
    if (!p.isPoi) return;
    if (!sessionActive) startSession();
    if (isDemo && p.position != position) {
      stopWalking();
      _moveTo(p.position, record: false);
    }
    final events = [
      ..._engine.manual(p.id, now()),
      ..._engine.onEngaged(p.id, EngagementKind.opened, now()),
    ];
    for (final e in events) {
      bus?.publish(e);
    }
    triggered.add(p.id);
    if (events.whereType<PoiVisited>().isNotEmpty) visited.add(p.id);
    if (pendingTrigger?.id == p.id) pendingTrigger = null;
    _queue.removeWhere((q) => q.id == p.id);
    approaching = null;
    _logEvents(events);
    notifyListeners();
  }

  /// Dengarkan (`listened`) / Lihat (`opened`) → visited (D05). Nanti → triggered only.
  void resolveTrigger(
      {required bool engaged, EngagementKind how = EngagementKind.opened}) {
    final p = pendingTrigger;
    pendingTrigger = null;
    if (p != null && engaged) {
      _apply(_engine.onEngaged(p.id, how, now()));
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

  /// The visitor is at [p] for sure (arrival screen, UI11): visited, source `nav`. Arrival
  /// never creates a trigger (D06), so this doesn't count as one in the session log.
  void markVisited(Place p) {
    if (!p.isPoi) return;
    _apply(_engine.visitOnArrival(p.id, now()));
    visited.add(p.id);
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
    if (!isDemo) {
      _trackingPolicy.tick(now(), keepFast: true);
      _syncGpsInterval();
    }
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
      _arrivedAt(n.to);
      if (vibration) HapticFeedback.heavyImpact();
    }
    _checkReminders();
    _persist();
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
      _arrivedAt(n.to);
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
    if (record && sessionActive) {
      if (_meter.add(p, now())) _addTrail(p);
    } else {
      _meter.anchor(p, now());
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
  // bound in the composition root). Without a file, or when it fails to play, the voice reads
  // the POI text aloud sentence by sentence (T07). Without either (tests, preview) the
  // progress is simulated with a timer.
  Place? nowPlaying;
  double audioPos = 0; // seconds
  bool audioPlaying = false;

  /// Counts narrations played to the end (VoiceAlerts says "Selesai. Berikutnya: …").
  int narrationsDone = 0;

  /// Paused by a safety voice line (closing reminder); resumed when the voice is done.
  bool _voicePaused = false;
  Timer? _audioTimer;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<void>? _doneSub;
  final Map<String, double> _fileSeconds = {};

  /// Recordings that failed to open or play this run: read aloud instead.
  final Set<String> _fileFailed = {};
  final Map<String, NarrationScript> _scripts = {};
  bool _voiceReady = false;

  /// Bumped to abandon the sentence loop of [_speak] (pause, seek, stop, switch).
  int _spokenRun = 0;
  bool _speaking = false;
  int _spokenIndex = 0;

  bool _usesFile(Place p) =>
      player != null && p.poi?.audio != null && !_fileFailed.contains(p.id);

  NarrationScript _script(Place p) =>
      _scripts[p.id] ??= NarrationScript.fromText(p.poi?.displayText ?? '');

  bool _usesVoice(Place p) =>
      !_usesFile(p) && voice != null && _voiceReady && !_script(p).isEmpty;

  /// Where [p]'s narration comes from now (the audio card says "Dibacakan suara pemandu").
  NarrationSource narrationSource(Place p) => _usesFile(p)
      ? NarrationSource.recording
      : _usesVoice(p)
          ? NarrationSource.voice
          : NarrationSource.simulated;

  double audioLength(Place p) => _usesVoice(p)
      ? _script(p).length
      : _fileSeconds[p.id] ?? (p.poi?.audioSeconds ?? 90).toDouble();
  double get audioProgress => nowPlaying == null
      ? 0
      : (audioPos / audioLength(nowPlaying!)).clamp(0, 1);

  void playAudio(Place p) {
    final switching = nowPlaying?.id != p.id;
    if (switching) {
      // Not stop(): the next file replaces this one, and the media session (lock screen)
      // stays up instead of restarting its service while the phone may be locked.
      _stopPlayback(release: false);
      audioPos = 0;
    }
    nowPlaying = p;
    audioPlaying = true;
    engage(p, EngagementKind.listened);
    _startSource(p, fresh: switching);
    notifyListeners();
  }

  void _startSource(Place p, {required bool fresh}) {
    if (_usesFile(p)) {
      unawaited(_playFile(p, fresh: fresh));
    } else if (_usesVoice(p)) {
      unawaited(_speak(p));
    } else {
      _startTimer();
    }
  }

  Future<void> _playFile(Place p, {required bool fresh}) async {
    final pl = player!;
    try {
      if (fresh) {
        final d = await pl.open(narrationAsset(p.poi!.audio!),
            info: NarrationInfo(
                id: p.id,
                title: p.name,
                subtitle: 'Tahura Djuanda · Dago Pakar'));
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
          narrationsDone++;
          _onFinished(p.id, FinishReason.narrationDone, now());
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
      // T07: a missing or broken file is read aloud instead (simulated without a voice).
      AppLog.info('Narration file failed for ${p.id}: $e — reading the text');
      _fileFailed.add(p.id);
      unawaited(_posSub?.cancel());
      unawaited(_doneSub?.cancel());
      _posSub = null;
      _doneSub = null;
      if (_disposed || nowPlaying?.id != p.id || !audioPlaying) return;
      audioPos = 0;
      _startSource(p, fresh: false);
      notifyListeners();
    }
  }

  /// T07: the POI text through the voice, one sentence per line, so a trigger prompt or a turn
  /// instruction can cut in (the arbiter reads the sentence again afterwards). Progress moves
  /// within the estimated length of the sentence being read and jumps when it ends.
  Future<void> _speak(Place p) async {
    final v = voice!;
    final script = _script(p);
    final run = ++_spokenRun;
    _speaking = true;
    if (audioPos >= script.length - 0.3) audioPos = 0;
    var i = script.indexAt(audioPos);
    audioPos = script.starts[i];
    _spokenIndex = i;
    _audioTimer?.cancel();
    _audioTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (run != _spokenRun) return;
      final cap = script.endOf(_spokenIndex) - 0.2;
      if (audioPos >= cap) return;
      audioPos = math.min(audioPos + 0.2, cap);
      notifyListeners();
    });
    for (; i < script.sentences.length; i++) {
      _spokenIndex = i;
      await v.say(script.sentences[i], priority: VoicePriority.narration);
      if (_disposed || run != _spokenRun) return;
      audioPos = script.endOf(i);
      notifyListeners();
    }
    _audioTimer?.cancel();
    _speaking = false;
    audioPlaying = false;
    narrationsDone++;
    _onFinished(p.id, FinishReason.narrationDone, now());
    notifyListeners();
  }

  /// Stops reading aloud (the sentence being read and the rest).
  void _stopSpeaking() {
    if (!_speaking) return;
    _speaking = false;
    _spokenRun++;
    unawaited(voice?.cancel(VoicePriority.narration));
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
        narrationsDone++;
        _onFinished(nowPlaying!.id, FinishReason.narrationDone, now());
      }
      notifyListeners();
    });
  }

  void _stopPlayback({bool release = true}) {
    _audioTimer?.cancel();
    _stopSpeaking();
    _posSub?.cancel();
    _doneSub?.cancel();
    _posSub = null;
    _doneSub = null;
    if (player != null) {
      unawaited(release ? player!.stop() : player!.pause());
    }
  }

  void toggleAudio(Place p) =>
      (audioPlaying && nowPlaying?.id == p.id) ? pauseAudio() : playAudio(p);

  void pauseAudio() {
    _voicePaused =
        false; // the visitor paused: a voice line ending must not resume it
    _pause();
  }

  void _pause() {
    audioPlaying = false;
    _audioTimer?.cancel();
    _stopSpeaking();
    if (nowPlaying != null && _usesFile(nowPlaying!)) {
      unawaited(player!.pause());
    }
    notifyListeners();
  }

  /// F04 voice arbitration: narration turns down under a spoken line, and pauses for a safety
  /// line (closing reminder) and resumes after it.
  void onVoiceDuck(VoiceDuck d) {
    switch (d) {
      case VoiceDuck.duck:
        if (player != null) unawaited(player!.setVolume(0.2));
      case VoiceDuck.pause:
        if (player != null) unawaited(player!.setVolume(0.2));
        // Read aloud: the arbiter already stops the sentence and reads it again after.
        if (audioPlaying && !_speaking) {
          _voicePaused = true;
          _pause();
        }
      case VoiceDuck.none:
        if (player != null) unawaited(player!.setVolume(1));
        final p = nowPlaying;
        if (_voicePaused && p != null && !audioPlaying) playAudio(p);
        _voicePaused = false;
    }
  }

  /// F04 AC1 / UC-F04-1: buttons outside the app (lock screen, notification, earphones) and
  /// audio interruptions, answered like the in-app buttons.
  /// - play: a trigger waiting for an answer is listened to first (step 3: "presses the
  ///   earphone play button → narration plays"), otherwise the paused narration continues;
  /// - resume (call ended): only the narration that was interrupted, never a new POI.
  void onMediaCommand(MediaCommand c) {
    switch (c) {
      case MediaCommand.play:
        final t = pendingTrigger;
        if (t != null && !(audioPlaying && nowPlaying?.id == t.id)) {
          resolveTrigger(engaged: true, how: EngagementKind.listened);
          playAudio(t);
        } else if (nowPlaying case final p? when !audioPlaying) {
          playAudio(p);
        }
      case MediaCommand.resume:
        if (nowPlaying case final p? when !audioPlaying) playAudio(p);
      case MediaCommand.pause:
        if (audioPlaying) pauseAudio();
      case MediaCommand.stop:
        stopAudio();
        notifyListeners();
      case MediaCommand.rewind:
        skipAudio(-10);
      case MediaCommand.fastForward:
        skipAudio(10);
    }
  }

  void seekAudio(double fraction) {
    final p = nowPlaying;
    if (p == null) return;
    audioPos = fraction * audioLength(p);
    if (_usesFile(p)) {
      unawaited(
          player!.seek(Duration(milliseconds: (audioPos * 1000).round())));
    } else if (_usesVoice(p)) {
      // Read aloud: from the start of the sentence at that point.
      audioPos = _script(p).starts[_script(p).indexAt(audioPos)];
      if (audioPlaying) {
        _stopSpeaking();
        unawaited(_speak(p));
      }
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
    _voicePaused = false;
    audioPlaying = false;
    nowPlaying = null;
    audioPos = 0;
  }

  // ---- reminders (A03 closing, F08 hydration; rules in `reminders` + `TimeBudget`) --------
  GuideReminder? reminder;

  /// What the open reminder says (voice, notification and card use the same words).
  ReminderDue? reminderDue;

  /// The one closing-time rule (T23): reminder, recommendation filter and route chooser.
  late final TimeBudget budget;
  late final ReminderScheduler _reminders;
  late final ReminderStore _reminderStore;

  Duration get walkToGate => budget.walkToGate(origin);

  /// A03: jam tutup − waktu jalan ke gerbang − 15 menit, from where the visitor is now.
  DateTime get closingReminderAt => budget.closingReminderAt(origin, now());

  /// UC-A03-2: jam tutup − waktu jalan ke gerbang (final call threshold).
  DateTime get finalCallAt => budget.finalCallAt(origin, now());

  /// F08 route chooser: the whole route (gate → gate) ends by closing − 15 min.
  bool routeFits(TrailRoute r) =>
      budget.routeFits(Duration(minutes: r.durationMin), now());

  void _checkReminders() {
    if (!sessionActive) return;
    final ctx = ReminderContext(
      now: now(),
      position: origin,
      sessionStart: sessionStart!,
      hydrationEvery: Duration(minutes: hydrationMin),
      navigatingToGate: navigation?.to.isGate ?? false,
    );
    final ReminderDue? due;
    if (reminder == null) {
      due = _reminders.check(ctx);
    } else if (reminder != GuideReminder.finalCall) {
      // UC-A03-2: final call supersedes an open softer reminder card.
      due = _reminders.checkOnly(ReminderKind.finalCall, ctx);
    } else {
      return;
    }
    if (due == null) return;
    reminder = switch (due.kind) {
      ReminderKind.hydration => GuideReminder.hydration,
      ReminderKind.closing => GuideReminder.closing,
      ReminderKind.finalCall => GuideReminder.finalCall,
    };
    reminderDue = due;
    _saveReminders();
    bus?.publish(due);
  }

  /// The nearest rest point (saung, bangku) by walking distance: UC-F08-3 "Titik istirahat
  /// terdekat", destination of the hydration reminder.
  Place get nearestRest {
    final rests = nearest(group: 'fasilitas');
    return rests.firstWhere((p) => p.kind == 'istirahat',
        orElse: () => rests.isEmpty ? gatePlace : rests.first);
  }

  /// Where the reminder's main button goes: the gate (closing/final call) or nearest rest.
  Place reminderDestination(GuideReminder r) =>
      r == GuideReminder.hydration ? nearestRest : gatePlace;

  /// Card / notification title of the hydration reminder ("Sudah 55 menit berjalan. …").
  /// The Settings preview (no reminder fired) reads as if the interval had just passed.
  String get hydrationLine {
    if (reminderDue?.kind == ReminderKind.hydration) return reminderDue!.text;
    final every = Duration(minutes: hydrationMin > 0 ? hydrationMin : 45);
    return hydrationText(sessionDuration > every ? sessionDuration : every);
  }

  /// Reminder "Navigasi …" (card or notification): handled, navigation starts. False when
  /// there is no way there.
  bool navigateForReminder(GuideReminder r) {
    final to = reminderDestination(r);
    if (reminder == r) dismissReminder();
    return startNavigation(to);
  }

  /// Hydration "Ingatkan 10 menit lagi" (#33): back in [hydrationSnooze], not after the full
  /// interval. Other reminders are just dismissed.
  void snoozeReminder() {
    if (reminder != GuideReminder.hydration) return dismissReminder();
    _reminders.snooze(ReminderKind.hydration, now(), hydrationSnooze);
    _saveReminders();
    reminder = null;
    reminderDue = null;
    notifyListeners();
  }

  /// UC-F08-3: reaching a rest point counts as the break, the hydration timer starts again.
  void _arrivedAt(Place p) {
    if (p.isPoi || p.kind != 'istirahat' || !sessionActive) return;
    _reminders.acknowledge(ReminderKind.hydration, now());
    _saveReminders();
  }

  void _saveReminders() {
    final r = _record;
    if (r == null || !sessionActive) return;
    unawaited(_reminderStore.save(r.id, _reminders.toJson()));
  }

  /// Settings → Mode demo preview; doesn't count as shown.
  void showReminder(GuideReminder r) {
    reminder = r;
    reminderDue = null;
    if (vibration) HapticFeedback.mediumImpact();
    notifyListeners();
  }

  void dismissReminder() {
    if (reminder case final r?) {
      final kind = switch (r) {
        GuideReminder.closing => ReminderKind.closing,
        GuideReminder.finalCall => ReminderKind.finalCall,
        GuideReminder.hydration => ReminderKind.hydration,
      };
      _reminders.acknowledge(kind, now());
      _saveReminders();
    }
    reminder = null;
    reminderDue = null;
    notifyListeners();
  }

  // ---- recommendation (F07, T24; rules in `recommendation`) --------------------------------
  late final Recommender _recommender =
      Recommender(weights: content.park.recWeights);

  /// UC-F07-1: a visited POI was just finished and UI08 should open (≤ 2 s, AC2). The overlay
  /// host opens the sheet and calls [takeRecommendationCue]. Not set while navigating: the
  /// visitor already chose where to go.
  ({String afterPoiId, FinishReason reason})? recommendationCue;

  /// The last automatic recommendation and how many there were (VoiceAlerts / TriggerAlerts
  /// react to the count: voice line, silent notification when the screen is off).
  ({
    String afterPoiId,
    FinishReason reason,
    Recommendation rec
  })? lastRecommendation;
  int recommendationCount = 0;

  /// POIs that already got their recommendation this session (once per visited POI).
  final Set<String> _recommendedFor = {};

  Place get gatePlace => place(content.gate.id)!;

  /// The sheet was opened for the cue. False when there was none (already taken).
  bool takeRecommendationCue() {
    if (recommendationCue == null) return false;
    recommendationCue = null;
    return true;
  }

  /// UI08 opened by hand right after [p] (detail "Selesai, lihat berikutnya", arrival "Lihat
  /// tujuan berikutnya"): logged, and it counts as [p]'s recommendation, so closing the
  /// detail or walking away later doesn't open the sheet a second time.
  void recommendationOpened(Place p) {
    if (!sessionActive || !visited.contains(p.id)) return;
    if (_recommendedFor.add(p.id)) {
      _logRecommendation(p.id, 'manual', now(), recommend());
    }
  }

  /// POI Detail closed (UC-F03-4): E7 detailClosed.
  void detailClosed(Place p) {
    if (!p.isPoi) return;
    _onFinished(p.id, FinishReason.detailClosed, now());
    notifyListeners();
  }

  /// E7 from any source (detail closed, narration done, left the area): the first finish of a
  /// visited POI recommends the next one.
  void _onFinished(String poiId, FinishReason reason, DateTime at,
      {bool publish = true}) {
    if (publish) {
      bus?.publish(PoiFinished(at: at, poiId: poiId, reason: reason));
    }
    // D05: walking past ("Nanti") is not a visit, so it doesn't ask "where next".
    if (!sessionActive || !visited.contains(poiId)) return;
    if (!_recommendedFor.add(poiId)) return;
    final rec = recommend();
    _logRecommendation(poiId, reason.name, at, rec);
    if (navigation != null) return;
    recommendationCue = (afterPoiId: poiId, reason: reason);
    lastRecommendation = (afterPoiId: poiId, reason: reason, rec: rec);
    recommendationCount++;
  }

  void _logRecommendation(
      String after, String reason, DateTime finishedAt, Recommendation rec) {
    final r = _record;
    if (r == null) return;
    r.recommendations.add(RecommendationEntry(
      at: now(),
      afterPoiId: after,
      reason: reason,
      finishedAt: finishedAt,
      poiIds: [for (final i in rec.items) i.place.id],
    ));
    _persist(force: true);
  }

  /// What was recommended this session (TC-09 evidence).
  List<RecommendationEntry> get recommendationLog =>
      List.unmodifiable(_record?.recommendations ?? []);

  /// F07 (UC-F07-1…5): same algorithm for the automatic sheet and "Ke mana selanjutnya?".
  Recommendation recommend() {
    final at = now();
    final from = origin;
    final r = _recommender.recommend(
      pois: content.pois,
      visited: visited,
      gateId: content.gate.id,
      interests: interests,
      route: route,
      walkM: (poi) => router.walkingDistanceM(from, poi.graphNode),
      // AC3: walk there + visit + walk to the gate by closing − 15 min (TimeBudget, T23).
      fits: (poi) => budget.fits(
          from, poi.graphNode, Duration(minutes: poi.visitMinutes), at),
    );
    final gate = walkToGate;
    if (r.backToGate) {
      return Recommendation.backToGate(
          allVisited: r.allVisited, gateWalk: gate);
    }
    return Recommendation([
      for (final i in r.items)
        if (place(i.poi.id) case final p?)
          (place: p, reasons: [for (final x in i.reasons) _reasonLabel(x, p)]),
    ], gateWalk: gate);
  }

  String _reasonLabel(RecReason r, Place p) => switch (r) {
        RecReason.nearest => 'Terdekat',
        RecReason.interest => 'Sesuai minat ${categoryLabel(p.kind)}',
        RecReason.onRoute => 'Ada di rute ${route.name}',
        RecReason.difficulty =>
          p.poi!.difficulty <= 1 ? 'Jalur mudah' : 'Sesuai tingkat rute',
      };

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    stepTracker?.onChange = null;
    _walkTimer?.cancel();
    _heartbeat?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _stopPlayback();
    super.dispose();
  }
}

enum GuideReminder { closing, finalCall, hydration }

/// Where a narration comes from (T07).
enum NarrationSource {
  /// The recorded MP3.
  recording,

  /// The POI text read aloud by the guide's voice (no recording, or it failed).
  voice,

  /// Neither available (tests, preview): progress only.
  simulated,
}

class Recommendation {
  const Recommendation(this.items, {this.gateWalk = Duration.zero})
      : allVisited = false;
  const Recommendation.backToGate(
      {this.allVisited = false, this.gateWalk = Duration.zero})
      : items = const [];

  final List<({Place place, List<String> reasons})> items;
  final bool allVisited;

  /// Walk from the visitor to the gate (UC-F07-2 "Kembali ke gerbang — ±25 mnt").
  final Duration gateWalk;
  bool get backToGate => items.isEmpty;
}

final guideProvider = ChangeNotifierProvider<GuideController>((ref) {
  final scene = ref.watch(mapSceneProvider);
  return GuideController(
    content: ref.watch(contentRepositoryProvider),
    router: ref.watch(trailRouterProvider),
    clock: ref.watch(clockProvider),
    player: ref.watch(narrationPlayerProvider),
    voice: ref.watch(ttsServiceProvider),
    location: ref.watch(locationServiceProvider),
    stepTracker: ref.watch(stepTrackerProvider),
    store: ref.watch(keyValueStoreProvider),
    bus: ref.watch(eventBusProvider),
    insideZone: scene.isInsideZone,
    timeBudget: ref.watch(timeBudgetProvider),
  );
});
