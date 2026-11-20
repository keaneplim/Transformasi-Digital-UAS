import 'package:jelajah_taman/core/core.dart';

import 'reminder.dart';

/// Runs the [Reminder]s of one session (T23). The list order is the priority: when two are
/// due at the same check, the first one wins and the other waits for the next check
/// (closing before hydration: safety first).
///
/// It remembers what was shown, so "once per session" also holds after the app is killed and
/// the session restored ([toJson] / [restore]).
class ReminderScheduler {
  ReminderScheduler(List<Reminder> reminders)
      : _reminders = List.unmodifiable(reminders);

  final List<Reminder> _reminders;
  final Set<ReminderKind> _fired = {};
  final Map<ReminderKind, DateTime> _handled = {};

  /// The reminder due now, or null. A returned reminder counts as shown at [ReminderContext.now].
  ReminderDue? check(ReminderContext ctx) {
    for (final r in _reminders) {
      if (r.oncePerSession && _fired.contains(r.kind)) continue;
      final due = r.check(ctx, _handled[r.kind]);
      if (due == null) continue;
      _fired.add(r.kind);
      _handled[r.kind] = ctx.now;
      return due;
    }
    return null;
  }

  /// The visitor closed the reminder: repeating reminders count again from [now].
  void acknowledge(ReminderKind kind, DateTime now) => _handled[kind] = now;

  bool hasFired(ReminderKind kind) => _fired.contains(kind);

  /// New session: nothing shown yet.
  void reset() {
    _fired.clear();
    _handled.clear();
  }

  Map<String, Object?> toJson() => {
        'fired': [for (final k in _fired) k.name],
        'handled': {
          for (final e in _handled.entries)
            e.key.name: e.value.toIso8601String()
        },
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
    final handled = json['handled'];
    if (handled is Map) {
      for (final MapEntry(:key, :value) in handled.entries) {
        final k = kinds[key];
        final at = value is String ? DateTime.tryParse(value) : null;
        if (k != null && at != null) _handled[k] = at;
      }
    }
  }
}
