import 'dart:async';

import 'package:jelajah_taman/core/core.dart';

import '../domain/location_contracts.dart';

/// [LocationService] over any [LocationSource] (GPS, replay, fake): keeps `last`, derives
/// [GpsQuality] (weak > 30 m, none after 10 s without a fix) and merges compass + GPS course.
/// It never filters fixes for triggers; that's the trigger engine's job (F01).
///
/// Subscription changes ([start], [startSession], [stopSession], [setInterval], [stop]) are
/// serialized with a generation guard so overlapping platform calls can never leak a second
/// GPS stream or restart foreground tracking after a session ends.
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
        _headingSource = headingSource,
        _activeInterval = interval,
        _desiredInterval = interval;

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
  bool _disposed = false;
  Duration _activeInterval;
  Duration _desiredInterval;

  /// Serializes subscription lifecycles; [_op] invalidates any superseded in-flight call.
  Future<void> _serial = Future<void>.value();
  int _op = 0;

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
  Duration get currentInterval => _activeInterval;

  Future<void> _enqueue(Future<void> Function(int gen) action) {
    final gen = ++_op;
    final next = _serial.then((_) async {
      if (_disposed || gen != _op) return;
      await action(gen);
    });
    _serial = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<void> setInterval(Duration interval) {
    if (interval == _desiredInterval && interval == _activeInterval) {
      return Future<void>.value();
    }
    _desiredInterval = interval;
    return _enqueue((gen) async {
      if (_sub == null) return;
      await _applyListen(
        background: _background,
        targetInterval: _desiredInterval,
        force: false,
        gen: gen,
      );
    });
  }

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
  Future<void> start() => _enqueue((gen) => _applyListen(
        background: _background,
        targetInterval: _desiredInterval,
        force: false,
        gen: gen,
      ));

  @override
  Future<void> startSession() => _enqueue((gen) => _applyListen(
        background: true,
        targetInterval: _desiredInterval,
        force: false,
        gen: gen,
      ));

  @override
  Future<void> stopSession() {
    _desiredInterval = interval;
    return _enqueue((gen) async {
      if (_sub == null) {
        _background = false;
        _activeInterval = interval;
        return;
      }
      await _applyListen(
        background: false,
        targetInterval: interval,
        force: false,
        gen: gen,
      );
    });
  }

  Future<void> _applyListen({
    required bool background,
    required Duration targetInterval,
    required bool force,
    required int gen,
  }) async {
    if (_sub != null &&
        background == _background &&
        targetInterval == _activeInterval &&
        !force) {
      return;
    }
    if (await _permissions.check() != LocationAccess.granted) return;
    if (_disposed || gen != _op) return;
    final old = _sub;
    _sub = null;
    await old?.cancel();
    if (_disposed || gen != _op) return;
    _background = background;
    _activeInterval = targetInterval;
    _sub =
        _source.fixes(interval: _activeInterval, background: background).listen(
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

  Duration get _effectiveNoFixAfter {
    final adaptive = _activeInterval * 2 + const Duration(seconds: 4);
    return adaptive > noFixAfter ? adaptive : noFixAfter;
  }

  void _armNoFix() {
    _noFix?.cancel();
    _noFix = Timer(_effectiveNoFixAfter, () => _setQuality(GpsQuality.none));
  }

  void _setQuality(GpsQuality q) {
    if (q == _currentQuality) return;
    _currentQuality = q;
    _quality.add(q);
  }

  @override
  Future<void> stop() {
    _desiredInterval = interval;
    _noFix?.cancel();
    _noFix = null;
    return _enqueue((gen) async {
      final sub = _sub;
      _sub = null;
      await sub?.cancel();
      final compass = _compassSub;
      _compassSub = null;
      await compass?.cancel();
      _noFix?.cancel();
      _noFix = null;
      _background = false;
      _activeInterval = interval;
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _op++;
    _noFix?.cancel();
    _noFix = null;
    await _serial;
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
    final compass = _compassSub;
    _compassSub = null;
    await compass?.cancel();
    await _fixes.close();
    await _quality.close();
    await _headings.close();
  }
}
