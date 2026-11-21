import 'dart:async';

import 'package:jelajah_taman/core/core.dart';

import '../domain/steps.dart';

/// Counts steps during a session (F08 b, TC-12): sensor + permission + [StepCounter].
/// The guide starts it with the session and reads [steps] / [status]; [onChange] fires when
/// either changes.
class StepTracker {
  StepTracker(
      {required StepSource source, required StepPermissions permissions})
      : _source = source,
        _permissions = permissions;

  final StepSource _source;
  final StepPermissions _permissions;
  final StepCounter _counter = StepCounter();
  StreamSubscription<int>? _sub;
  StepStatus _status = StepStatus.off;
  int _run = 0;

  /// Called on every step update and status change.
  void Function()? onChange;

  StepStatus get status => _status;
  int get steps => _counter.steps;

  /// Snapshot for the session record (restore after an app restart).
  Map<String, Object?> toJson() => _counter.toJson();

  /// Asks for "Aktivitas fisik" (onboarding only). True when allowed.
  Future<bool> requestAccess() async {
    try {
      return await _permissions.request();
    } on Object catch (e) {
      AppLog.info('Activity permission request failed: $e');
      return false;
    }
  }

  /// Session start ([restore] = a session continued after an app restart).
  Future<void> start({Map<String, Object?>? restore}) async {
    await _cancel();
    final run = ++_run;
    restore != null ? _counter.restore(restore) : _counter.start();
    _set(StepStatus.starting);
    bool allowed;
    try {
      allowed = await _permissions.granted();
    } on Object catch (e) {
      AppLog.info('Activity permission check failed: $e');
      allowed = false;
    }
    if (run != _run) return; // stopped or restarted meanwhile
    if (!allowed) {
      _set(StepStatus.denied);
      return;
    }
    _sub = _source.cumulativeSteps().listen(
      (raw) {
        _counter.onReading(raw);
        _set(StepStatus.counting, force: true);
      },
      onError: (Object e) {
        AppLog.info('Step counter unavailable: $e');
        _set(StepStatus.noSensor);
        unawaited(_cancel());
      },
    );
  }

  /// Session end: stop listening, keep the count for the summary.
  Future<void> stop() async {
    _run++;
    await _cancel();
    if (_status == StepStatus.starting || _status == StepStatus.counting) {
      _status = StepStatus.off;
    }
  }

  /// Forget everything ("Reset", mode switch).
  Future<void> reset() async {
    await stop();
    _counter.start();
    _status = StepStatus.off;
    onChange?.call();
  }

  Future<void> _cancel() async {
    final s = _sub;
    _sub = null;
    await s?.cancel();
  }

  void _set(StepStatus s, {bool force = false}) {
    if (s == _status && !force) return;
    _status = s;
    onChange?.call();
  }

  Future<void> dispose() async {
    onChange = null;
    await stop();
  }
}
