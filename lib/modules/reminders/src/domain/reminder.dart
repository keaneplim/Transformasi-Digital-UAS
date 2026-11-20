import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/routing/routing.dart';

/// What a [Reminder] may look at. Built by the caller on every check (each fix and a timer
/// while a session runs), so reminders follow both the clock and the visitor's position.
class ReminderContext {
  const ReminderContext({
    required this.now,
    required this.position,
    required this.sessionStart,
    this.hydrationEvery = Duration.zero,
  });

  final DateTime now;

  /// Where walking times are counted from (the visitor, or the gate without a position).
  final GeoPoint position;
  final DateTime sessionStart;

  /// Settings → hydration interval; zero = off.
  final Duration hydrationEvery;
}

/// One kind of reminder (ARCHITECTURE §6.2, Open/Closed): a new reminder is a new class plus
/// one entry in the scheduler's list; [ReminderScheduler] isn't edited.
abstract interface class Reminder {
  ReminderKind get kind;

  /// True: shown at most once per session (the scheduler remembers it, also across a restart).
  bool get oncePerSession;

  /// The reminder to show now, or null. [lastHandledAt] = when this reminder was last shown
  /// or dismissed in this session (null if never).
  ReminderDue? check(ReminderContext ctx, DateTime? lastHandledAt);
}

/// A03: "Kawasan tutup pukul 16.00. Waktu jalan ke gerbang sekitar 25 menit." once the clock
/// reaches closing − walk to gate − 15 min. A session started after that moment is reminded
/// at once (UC-A03-3).
class ClosingReminder implements Reminder {
  ClosingReminder(this._budget, {required this.gatePoiId});

  final TimeBudget _budget;

  /// Destination of "Navigasi ke gerbang" (P01).
  final String gatePoiId;

  @override
  ReminderKind get kind => ReminderKind.closing;

  @override
  bool get oncePerSession => true;

  @override
  ReminderDue? check(ReminderContext ctx, DateTime? lastHandledAt) {
    if (ctx.now.isBefore(_budget.closingReminderAt(ctx.position, ctx.now))) {
      return null;
    }
    final close = _budget.closingTime(ctx.now);
    final walk = _budget.walkToGate(ctx.position);
    return ReminderDue(
      at: ctx.now,
      kind: kind,
      text: 'Kawasan tutup pukul ${clockText(close)}. '
          'Waktu jalan ke gerbang sekitar ${minutesText(walk)}.',
      actionDestinationId: gatePoiId,
    );
  }
}

/// F08(d): drink/rest reminder every [ReminderContext.hydrationEvery], counted from the
/// session start or from the last time it was shown or dismissed (owner C).
class HydrationReminder implements Reminder {
  const HydrationReminder();

  @override
  ReminderKind get kind => ReminderKind.hydration;

  @override
  bool get oncePerSession => false;

  @override
  ReminderDue? check(ReminderContext ctx, DateTime? lastHandledAt) {
    final every = ctx.hydrationEvery;
    if (every <= Duration.zero) return null;
    final since = lastHandledAt ?? ctx.sessionStart;
    if (ctx.now.difference(since) < every) return null;
    return ReminderDue(
      at: ctx.now,
      kind: kind,
      text: 'Sudah ${every.inMinutes} menit berjalan. Minum air dulu, yuk.',
    );
  }
}

/// "16.00" (Indonesian time format).
String clockText(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

/// Whole minutes, rounded up so the walk is never promised shorter than it is: "25 menit".
String minutesText(Duration d) {
  final m = (d.inSeconds / 60).ceil();
  return '${m < 1 ? 1 : m} menit';
}
