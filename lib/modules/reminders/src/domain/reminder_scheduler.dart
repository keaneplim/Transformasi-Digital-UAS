import 'package:jelajah_taman/core/core.dart';

import 'reminder.dart';

/// Runs the [Reminder]s of one session (T23). The list order is the priority: when two are
/// due at the same check, the first one wins and the other waits for the next check
/// (closing before hydration: safety first).
///
/// It remembers what was shown and what was snoozed, so "once per session" and "in 10
/// minutes" also hold after the app is killed and the session restored ([toJson] /
/// [restore]).
class ReminderScheduler {
  ReminderScheduler(List<Reminder> reminders)
      : _reminders = List.unmodifiable(reminders);

  final List<Reminder> _reminders;
  final Set<ReminderKind> _fired = {};
  final Map<ReminderKind, DateTime> _handled = {};
  final Map<ReminderKind, DateTime> _snoozed = {};

  /// The reminder due now, or null. A returned reminder counts as shown at [ReminderContext.now].
  /// A snoozed reminder waits for its time, then comes back once whatever its own rule says.
  ReminderDue? check(ReminderContext ctx) {
    for (final r in _reminders) {
      final due = _checkOne(r, ctx);
      if (due != null) return due;
    }
    return null;
  }

  /// Evaluates a single [kind] (e.g. UC-A03-2 final call superseding an open softer card).
  ReminderDue? checkOnly(ReminderKind kind, ReminderContext ctx) {
    for (final r in _reminders) {
      if (r.kind != kind) continue;
      return _checkOne(r, ctx);
    }
    return null;
  }

  ReminderDue? _checkOne(Reminder r, ReminderContext ctx) {
    final until = _snoozed[r.kind];
    if (until != null && ctx.now.isBefore(until)) return null;
    if (until == null && r.oncePerSession && _fired.contains(r.kind)) {
      return null;
    }
    final due = until != null ? r.due(ctx) : r.check(ctx, _handled[r.kind]);
    if (due == null) return null;
    _snoozed.remove(r.kind);
    _fired.add(r.kind);
    _handled[r.kind] = ctx.now;
    return due;
  }

  /// The visitor closed the reminder: repeating reminders count again from [now].
  void acknowledge(ReminderKind kind, DateTime now) {
    _handled[kind] = now;
    _snoozed.remove(kind);
  }

  /// "Ingatkan 10 menit lagi": the reminder comes back at [now] + [delay], not after its
  /// full interval (#33). Snoozing again moves the time.
  void snooze(ReminderKind kind, DateTime now, Duration delay) {
    _handled[kind] = now;
    _snoozed[kind] = now.add(delay);
  }

  /// When a snoozed reminder comes back; null when it isn't snoozed.
  DateTime? snoozedUntil(ReminderKind kind) => _snoozed[kind];

  bool hasFired(ReminderKind kind) => _fired.contains(kind);

  /// New session: nothing shown yet.
  void reset() {
    _fired.clear();
    _handled.clear();
    _snoozed.clear();
  }

  static Map<String, String> _times(Map<ReminderKind, DateTime> m) =>
      {for (final e in m.entries) e.key.name: e.value.toIso8601String()};

  Map<String, Object?> toJson() => {
        'fired': [for (final k in _fired) k.name],
        'handled': _times(_handled),
        if (_snoozed.isNotEmpty) 'snoozed': _times(_snoozed),
      };

  /// Restores what [toJson] wrote; unknown kinds and malformed values are skipped.
  void restore(Map<String, Object?> json) {
    reset();
    final kinds = ReminderKind.values.asNameMap();
    final fired = json['fired'];
    if (fired is List) {
      for (final name in fired) {
        if (kinds[name] case final k?) _fired.add(k);
      }
    }
    void times(Object? raw, Map<ReminderKind, DateTime> into) {
      if (raw is! Map) return;
      for (final MapEntry(:key, :value) in raw.entries) {
        final k = kinds[key];
        final at = value is String ? DateTime.tryParse(value) : null;
        if (k != null && at != null) into[k] = at;
      }
    }

    times(json['handled'], _handled);
    times(json['snoozed'], _snoozed);
  }
}
