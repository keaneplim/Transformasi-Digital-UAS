import 'dart:async';

import 'package:jelajah_taman/core/core.dart';

import '../domain/location_contracts.dart';

/// [LocationService] over any [LocationSource] (GPS, replay, fake): keeps `last`, derives
/// [GpsQuality] (weak > 30 m, none after 10 s without a fix) and merges compass + GPS course.
/// It never filters fixes for triggers; that's the trigger engine's job (F01).
class LocationServiceImpl implements LocationService {
  LocationServiceImpl({
    required LocationSource source,
    required LocationPermissions permissions,
    HeadingSource? headingSource,
    this.interval = const Duration(seconds: 3),
    this.weakAccuracyM = 30,
    this.noFixAfter = const Duration(seconds: 10),
  })  : _source = source,
        _permissions = permissions,
        _headingSource = headingSource;

  final LocationSource _source;
  final LocationPermissions _permissions;
  final HeadingSource? _headingSource;
  final Duration interval;
  final double weakAccuracyM;
  final Duration noFixAfter;

  final _fixes = StreamController<LocationFix>.broadcast();
  final _quality = StreamController<GpsQuality>.broadcast();
  final _headings = StreamController<double>.broadcast();
  StreamSubscription<LocationFix>? _sub;
  StreamSubscription<double?>? _compassSub;
  Timer? _noFix;
  bool _background = false;
  bool _compassAlive = false;

  LocationFix? _last;
  GpsQuality _currentQuality = GpsQuality.none;

  @override
  Stream<LocationFix> get fixes => _fixes.stream;

  @override
  Stream<GpsQuality> get quality => _quality.stream;

  @override
  Stream<double> get headings => _headings.stream;

  @override
  LocationFix? get last => _last;

  @override
  GpsQuality get currentQuality => _currentQuality;

  @override
  bool get isRunning => _sub != null;

  @override
  Future<LocationAccess> access() => _permissions.check();

  @override
  Future<LocationAccess> requestAccess() => _permissions.request();

  @override
  Future<void> openSettings() async {
    final a = await _permissions.check();
    if (a == LocationAccess.serviceOff) {
      await _permissions.openLocationSettings();
    } else {
      await _permissions.openSettings();
    }
  }

  @override
  Future<void> start() => _listen(background: _background);

  @override
  Future<void> startSession() => _listen(background: true);

  @override
  Future<void> stopSession() => _listen(background: false);

  Future<void> _listen({required bool background}) async {
    if (_sub != null && background == _background) return;
    if (await _permissions.check() != LocationAccess.granted) return;
    await _sub?.cancel();
    _background = background;
    _sub = _source.fixes(interval: interval, background: background).listen(
      _onFix,
      onError: (Object e) {
        AppLog.info('location stream error: $e');
        _setQuality(GpsQuality.none);
      },
    );
    _compassSub ??= _headingSource?.headings().listen(
      (h) {
        if (h == null) return;
        _compassAlive = true;
        _headings.add((h + 360) % 360);
      },
      // no compass: the GPS course stands in while walking
      onError: (Object e) => AppLog.info('compass error: $e'),
    );
    _armNoFix();
  }

  void _onFix(LocationFix fix) {
    _last = fix;
    _fixes.add(fix);
    _setQuality(fix.isWeak(weakAccuracyM) ? GpsQuality.weak : GpsQuality.good);
    if (!_compassAlive && fix.headingDeg != null) {
      _headings.add(fix.headingDeg!);
    }
    _armNoFix();
  }

  void _armNoFix() {
    _noFix?.cancel();
    _noFix = Timer(noFixAfter, () => _setQuality(GpsQuality.none));
  }

  void _setQuality(GpsQuality q) {
    if (q == _currentQuality) return;
    _currentQuality = q;
    _quality.add(q);
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _compassSub?.cancel();
    _compassSub = null;
    _noFix?.cancel();
    _background = false;
  }

  Future<void> dispose() async {
    await stop();
    await _fixes.close();
    await _quality.close();
    await _headings.close();
  }
}
