import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/routing/routing.dart';

import '../../helpers/test_content.dart';

/// T23: the one closing-time rule (PRD A03, F07 AC3, D13) on the real content.
/// Hours 08.00–16.00 and a 15 min buffer (park.json).
void main() {
  late ContentRepository content;
  late GraphTrailRouter router;
  late TimeBudget budget;
  final day = DateTime(2026, 11, 20);
  DateTime at(int h, int m, [int s = 0]) =>
      DateTime(day.year, day.month, day.day, h, m, s);

  setUp(() {
    content = loadTestContent();
    router = GraphTrailRouter.fromContent(content);
    budget = TimeBudget.fromContent(content, router);
  });

  Poi poi(String id) => content.pois.firstWhere((p) => p.id == id);

  test('deadline and remaining time: closing 16.00 − 15 min', () {
    expect(budget.buffer, const Duration(minutes: 15));
    expect(budget.deadline(at(10, 0)), at(15, 45));
    expect(budget.remaining(at(15, 0)), const Duration(minutes: 45));
    expect(budget.remaining(at(15, 50)), const Duration(minutes: -5),
        reason: 'negative once past the deadline');
  });

  test('walk to gate: zero at the gate, the router time elsewhere', () {
    expect(budget.walkToGate(content.gate.position).inSeconds, lessThan(60));
    final p06 = poi('P06');
    expect(budget.walkToGate(p06.position),
        router.walkingTime(p06.position, content.gate.graphNode));
    expect(budget.walkToGate(p06.position), greaterThan(Duration.zero));
  });

  test(
      'fits: walk + visit + walk back to the gate, equal to the deadline still fits',
      () {
    final from = content.gate.position;
    final p05 = poi('P05');
    final visit = Duration(minutes: p05.visitMinutes);
    final trip = budget.tripVia(from, p05.graphNode, visit);
    expect(
        trip,
        router.walkingTime(from, p05.graphNode) +
            visit +
            router.walkingTimeBetween(p05.graphNode, content.gate.graphNode));

    final latest = budget.deadline(day).subtract(trip);
    expect(budget.fits(from, p05.graphNode, visit, latest), isTrue);
    expect(
        budget.fits(
            from, p05.graphNode, visit, latest.add(const Duration(seconds: 1))),
        isFalse);
  });

  test('routeFits: the whole gate-to-gate route ends by 15.45', () {
    const route = Duration(minutes: 138); // Santai
    expect(budget.routeFits(route, at(13, 27)), isTrue,
        reason: '13.27 + 2 j 18 m = 15.45');
    expect(budget.routeFits(route, at(13, 28)), isFalse,
        reason: 'ends 15.46: before closing, but inside the 15 min buffer');
  });

  test('TC-10 threshold at P06 = 16.00 − walk(P06→gate) − 15 min', () {
    final p06 = poi('P06').position;
    final walk = router.walkingTime(p06, content.gate.graphNode);
    expect(budget.closingReminderAt(p06, day),
        at(16, 0).subtract(walk).subtract(const Duration(minutes: 15)));
  });

  test(
      'the reminder moves with the visitor: closer to the gate, later reminder',
      () {
    final far = budget.closingReminderAt(poi('P06').position, day);
    final near = budget.closingReminderAt(content.gate.position, day);
    expect(near.isAfter(far), isTrue);
  });

  test('finalCallAt is closing − walk (15 min after closingReminderAt)', () {
    final p06 = poi('P06').position;
    final walk = router.walkingTime(p06, content.gate.graphNode);
    expect(budget.finalCallAt(p06, day), at(16, 0).subtract(walk));
    expect(
      budget
          .finalCallAt(p06, day)
          .difference(budget.closingReminderAt(p06, day)),
      budget.buffer,
    );
    expect(budget.distanceToGateM(p06), greaterThan(200));
    expect(budget.distanceToGateM(content.gate.position), lessThan(200));
  });
}
