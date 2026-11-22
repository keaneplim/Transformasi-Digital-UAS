import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/reminders/reminders.dart';
import 'package:jelajah_taman/modules/routing/routing.dart';

import '../../helpers/test_content.dart';

/// T23 / A03 "Verify": fires at the computed minute, once, at once when late, follows the
/// position, survives a restart. Hydration (F08 d) keeps its interval.
void main() {
  late ContentRepository content;
  late TimeBudget budget;
  late GeoPoint p06;
  late DateTime threshold;
  final start = DateTime(2026, 11, 20, 13);

  ReminderScheduler scheduler() => ReminderScheduler([
        ClosingReminder(budget, gatePoiId: content.gate.id),
        const HydrationReminder(),
      ]);

  ReminderContext ctx(DateTime now,
          {GeoPoint? at,
          DateTime? sessionStart,
          Duration hydration = Duration.zero}) =>
      ReminderContext(
        now: now,
        position: at ?? p06,
        sessionStart: sessionStart ?? start,
        hydrationEvery: hydration,
      );

  setUp(() {
    content = loadTestContent();
    budget =
        TimeBudget.fromContent(content, GraphTrailRouter.fromContent(content));
    p06 = content.pois.firstWhere((p) => p.id == 'P06').position;
    threshold = budget.closingReminderAt(p06, start);
  });

  group('closing reminder', () {
    test(
        'not a minute early; at the threshold, with closing time and walk time',
        () {
      final s = scheduler();
      expect(
          s.check(ctx(threshold.subtract(const Duration(minutes: 1)))), isNull);
      expect(
          s.check(ctx(threshold.subtract(const Duration(seconds: 1)))), isNull);
      final due = s.check(ctx(threshold));
      expect(due, isNotNull);
      expect(due!.kind, ReminderKind.closing);
      expect(due.at, threshold);
      expect(due.actionDestinationId, 'P01');
      expect(due.text, startsWith('Kawasan tutup pukul 16.00.'));
      expect(due.text, contains(minutesText(budget.walkToGate(p06))));
    });

    test('fires once per session', () {
      final s = scheduler();
      expect(s.check(ctx(threshold)), isNotNull);
      expect(s.check(ctx(threshold.add(const Duration(minutes: 5)))), isNull);
      s.acknowledge(ReminderKind.closing, threshold);
      expect(s.check(ctx(threshold.add(const Duration(minutes: 10)))), isNull);
    });

    test('a session started after the threshold is reminded at once (UC-A03-3)',
        () {
      final late = threshold.add(const Duration(minutes: 20));
      final due = scheduler().check(ctx(late, sessionStart: late));
      expect(due?.kind, ReminderKind.closing);
    });

    test('follows the position: due at P06, not yet at the gate', () {
      final now = threshold.add(const Duration(minutes: 1));
      expect(scheduler().check(ctx(now, at: content.gate.position)), isNull);
      expect(scheduler().check(ctx(now)), isNotNull);
    });

    test('a restored session does not repeat it', () {
      final s = scheduler()..check(ctx(threshold));
      final again = scheduler()..restore(s.toJson());
      expect(again.hasFired(ReminderKind.closing), isTrue);
      expect(
          again.check(ctx(threshold.add(const Duration(minutes: 2)))), isNull);
    });

    test('reset starts a new session', () {
      final s = scheduler()..check(ctx(threshold));
      s.reset();
      expect(s.check(ctx(threshold))?.kind, ReminderKind.closing);
    });
  });

  group('hydration reminder', () {
    const every = Duration(minutes: 45);
    final morning = DateTime(2026, 11, 20, 9);

    test(
        'every 45 min from the session start, counted again from each reminder',
        () {
      final s = scheduler();
      DateTime t(int min) => morning.add(Duration(minutes: min));
      ReminderDue? at(int min) =>
          s.check(ctx(t(min), sessionStart: morning, hydration: every));
      expect(at(44), isNull);
      expect(at(45)?.kind, ReminderKind.hydration);
      expect(at(46), isNull);
      expect(at(89), isNull);
      expect(at(90)?.text, 'Sudah 90 menit berjalan. Minum air dulu, yuk.',
          reason: 'the walked time, not the interval');
    });

    test('snooze (#33): back 10 min later, not after the full interval', () {
      final s = scheduler();
      DateTime t(int min) => morning.add(Duration(minutes: min));
      ReminderDue? at(int min) =>
          s.check(ctx(t(min), sessionStart: morning, hydration: every));
      expect(at(45), isNotNull);
      s.snooze(ReminderKind.hydration, t(45), hydrationSnooze);
      expect(s.snoozedUntil(ReminderKind.hydration), t(55));
      expect(at(54), isNull);
      final again = at(55);
      expect(again?.kind, ReminderKind.hydration);
      expect(again?.text, 'Sudah 55 menit berjalan. Minum air dulu, yuk.');
      expect(s.snoozedUntil(ReminderKind.hydration), isNull);
      expect(at(56), isNull);
      // after the snoozed one, the normal interval counts from when it came back
      expect(at(99), isNull);
      expect(at(100), isNotNull);
    });

    test('dismissing a snoozed reminder cancels the snooze', () {
      final s = scheduler();
      final first = morning.add(every);
      s.check(ctx(first, sessionStart: morning, hydration: every));
      s.snooze(ReminderKind.hydration, first, hydrationSnooze);
      s.acknowledge(
          ReminderKind.hydration, first.add(const Duration(minutes: 2)));
      expect(
          s.check(ctx(first.add(const Duration(minutes: 10)),
              sessionStart: morning, hydration: every)),
          isNull);
    });

    test('a snooze survives a restart', () {
      final s = scheduler();
      final first = morning.add(every);
      s.check(ctx(first, sessionStart: morning, hydration: every));
      s.snooze(ReminderKind.hydration, first, hydrationSnooze);
      final again = scheduler()..restore(s.toJson());
      expect(again.snoozedUntil(ReminderKind.hydration),
          first.add(hydrationSnooze));
      expect(
          again.check(ctx(first.add(hydrationSnooze),
              sessionStart: morning, hydration: every)),
          isNotNull);
    });

    test('dismissing counts the interval again from then', () {
      final s = scheduler();
      final first = morning.add(every);
      expect(s.check(ctx(first, sessionStart: morning, hydration: every)),
          isNotNull);
      s.acknowledge(
          ReminderKind.hydration, first.add(const Duration(minutes: 10)));
      expect(
          s.check(
              ctx(first.add(every), sessionStart: morning, hydration: every)),
          isNull);
      expect(
          s.check(ctx(first.add(every).add(const Duration(minutes: 10)),
              sessionStart: morning, hydration: every)),
          isNotNull);
    });

    test('interval 0 = off', () {
      expect(
          scheduler().check(ctx(morning.add(const Duration(hours: 3)),
              sessionStart: morning)),
          isNull);
    });
  });

  test('both due: closing first (safety), hydration at the next check', () {
    final s = scheduler();
    final now = threshold;
    final first = s.check(ctx(now,
        sessionStart: DateTime(2026, 11, 20, 8),
        hydration: const Duration(minutes: 45)));
    expect(first?.kind, ReminderKind.closing);
    final second = s.check(ctx(now,
        sessionStart: DateTime(2026, 11, 20, 8),
        hydration: const Duration(minutes: 45)));
    expect(second?.kind, ReminderKind.hydration);
  });

  group('ReminderStore', () {
    test('keeps the state of one session only', () async {
      final kv = MemoryKeyValueStore();
      final store = ReminderStore(kv);
      final s = scheduler()..check(ctx(threshold));
      await store.save('s1', s.toJson());
      expect(store.load('s2'), isNull, reason: 'another session starts clean');
      final again = scheduler()..restore(store.load('s1')!);
      expect(again.hasFired(ReminderKind.closing), isTrue);
      await store.clear();
      expect(store.load('s1'), isNull);
    });

    test('a broken value is ignored, not a crash', () {
      final store =
          ReminderStore(MemoryKeyValueStore({ReminderStore.key: '{oops'}));
      expect(store.load('s1'), isNull);
      expect(
          () => scheduler().restore({
                'fired': ['nope'],
                'handled': 3
              }),
          returnsNormally);
    });
  });
}
