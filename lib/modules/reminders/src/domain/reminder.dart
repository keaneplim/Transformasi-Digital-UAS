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
    this.navigatingToGate = false,
  });

  final DateTime now;

  /// Where walking times are counted from (the visitor, or the gate without a position).
  final GeoPoint position;
  final DateTime sessionStart;

  /// Settings → hydration interval; zero = off.
  final Duration hydrationEvery;

  /// True when the visitor is already actively navigating to the gate (UC-A03-2 stays quiet).
  final bool navigatingToGate;
}

/// One kind of reminder (ARCHITECTURE §6.2, Open/Closed): a new reminder is a new class plus
/// one entry in the scheduler's list; [ReminderScheduler] isn't edited.
abstract interface class Reminder {
  ReminderKind get kind;

  /// True: shown at most once per session (the scheduler remembers it, also across a restart).
  bool get oncePerSession;

  /// Softer reminder kinds already covered when this reminder fires (e.g. final call covers
  /// the regular closing reminder so a very late start never plays two alarms in a row).
  Set<ReminderKind> get supersedes => const {};

  /// The reminder to show now, or null. [lastHandledAt] = when this reminder was last shown
  /// or dismissed in this session (null if never).
  ReminderDue? check(ReminderContext ctx, DateTime? lastHandledAt);

  /// The reminder as it reads at [ReminderContext.now], whether or not it is due ([check]
  /// decides *when*, this decides *what*). Used when a snoozed reminder comes back.
  ReminderDue due(ReminderContext ctx);
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
  Set<ReminderKind> get supersedes => const {};

  @override
  ReminderDue? check(ReminderContext ctx, DateTime? lastHandledAt) {
    if (ctx.now.isBefore(_budget.closingReminderAt(ctx.position, ctx.now))) {
      return null;
    }
    return due(ctx);
  }

  @override
  ReminderDue due(ReminderContext ctx) {
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

/// UC-A03-2 final call: a second, stronger reminder once `close − walk to gate` is reached
/// while the visitor is still farther than [minDistanceM] (default 200 m) from the gate and
/// not already navigating back to it. Fires at most once per session.
class FinalCallReminder implements Reminder {
  FinalCallReminder(
    this._budget, {
    required this.gatePoiId,
    this.minDistanceM = 200,
  });

  final TimeBudget _budget;

  /// Destination of "Navigasi ke gerbang" (P01).
  final String gatePoiId;

  /// Only fires when the visitor is farther than this from the gate.
  final double minDistanceM;

  @override
  ReminderKind get kind => ReminderKind.finalCall;

  @override
  bool get oncePerSession => true;

  @override
  Set<ReminderKind> get supersedes => const {ReminderKind.closing};

  @override
  ReminderDue? check(ReminderContext ctx, DateTime? lastHandledAt) {
    if (ctx.navigatingToGate) return null;
    if (_budget.distanceToGateM(ctx.position) <= minDistanceM) return null;
    if (ctx.now.isBefore(_budget.finalCallAt(ctx.position, ctx.now))) {
      return null;
    }
    return due(ctx);
  }

  @override
  ReminderDue due(ReminderContext ctx) {
    final close = _budget.closingTime(ctx.now);
    final walk = _budget.walkToGate(ctx.position);
    return ReminderDue(
      at: ctx.now,
      kind: kind,
      text: 'Segera menuju gerbang sekarang. Kawasan tutup pukul '
          '${clockText(close)}, waktu jalan sekitar ${minutesText(walk)}.',
      actionDestinationId: gatePoiId,
    );
  }
}

/// F08(d): drink/rest reminder every [ReminderContext.hydrationEvery], counted from the
/// session start or from the last time it was shown or dismissed (owner C). The text says how
/// long the visitor has really been walking ("Sudah 90 menit berjalan" the second time, 55
/// after a 10-minute snooze), not the interval.
class HydrationReminder implements Reminder {
  const HydrationReminder();

  @override
  ReminderKind get kind => ReminderKind.hydration;

  @override
  bool get oncePerSession => false;

  @override
  Set<ReminderKind> get supersedes => const {};

  @override
  ReminderDue? check(ReminderContext ctx, DateTime? lastHandledAt) {
    final every = ctx.hydrationEvery;
    if (every <= Duration.zero) return null;
    final since = lastHandledAt ?? ctx.sessionStart;
    if (ctx.now.difference(since) < every) return null;
    return due(ctx);
  }

  @override
  ReminderDue due(ReminderContext ctx) => ReminderDue(
        at: ctx.now,
        kind: kind,
        text: hydrationText(ctx.now.difference(ctx.sessionStart)),
      );
}

/// UI13 / voice / notification copy for the hydration reminder (one wording everywhere).
String hydrationText(Duration walked) {
  final m = walked.inMinutes < 1 ? 1 : walked.inMinutes;
  return 'Sudah $m menit berjalan. Minum air dulu, yuk.';
}

/// Snoozing a hydration reminder ("Ingatkan 10 menit lagi", UC-F08-3).
const hydrationSnooze = Duration(minutes: 10);

/// "16.00" (Indonesian time format).
String clockText(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

/// Whole minutes, rounded up so the walk is never promised shorter than it is: "25 menit".
String minutesText(Duration d) {
  final m = (d.inSeconds / 60).ceil();
  return '${m < 1 ? 1 : m} menit';
}
