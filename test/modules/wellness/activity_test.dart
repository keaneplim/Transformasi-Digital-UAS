import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/routing/routing.dart';
import 'package:jelajah_taman/modules/wellness/wellness.dart';

import '../../helpers/test_content.dart';

/// T27 / D11: distance filter (accuracy ≤ 20 m, step > max(3 m, accuracy / 2)), active time,
/// kcal with MET 3,5 flat / 6,0 on climbs > 8 %, restore.
void main() {
  final t0 = DateTime(2026, 11, 22, 9);
  const a = GeoPoint(-6.8580, 107.6300);

  /// [m] metres north of [a].
  GeoPoint north(double m) => GeoPoint(a.lat + m / 110540, a.lng);

  DateTime at(int s) => t0.add(Duration(seconds: s));

  test('counts steps at walking pace; the first position is only the start',
      () {
    final m = ActivityMeter();
    expect(m.add(a, at(0)), isFalse);
    expect(m.add(north(5), at(6)), isTrue);
    expect(m.add(north(10), at(12)), isTrue);
    expect(m.distanceM, closeTo(10, 0.1));
    expect(m.activeTime, const Duration(seconds: 12));
  });

  test('accuracy worse than 20 m never counts (canopy, cave mouth)', () {
    final m = ActivityMeter()..add(a, at(0));
    expect(m.add(north(8), at(6), accuracyM: 25), isFalse);
    expect(m.distanceM, 0);
    expect(m.add(north(8), at(12), accuracyM: 15), isTrue,
        reason: 'the anchor stayed at the last good position');
  });

  test('jitter smaller than half the accuracy is not walking', () {
    final m = ActivityMeter()..add(a, at(0), accuracyM: 16);
    // 7 m < 16 / 2 = 8 m: someone standing still with a wobbly fix
    for (var i = 1; i <= 20; i++) {
      m.add(north(i.isEven ? 7 : 0), at(i * 3), accuracyM: 16);
    }
    expect(m.distanceM, 0);
    expect(m.add(north(9), at(70), accuracyM: 16), isTrue);
  });

  test('a jump faster than 3,5 m/s moves the anchor without counting', () {
    final m = ActivityMeter()..add(a, at(0));
    expect(m.add(north(200), at(3)), isFalse);
    expect(m.distanceM, 0);
    expect(m.add(north(205), at(9)), isTrue,
        reason: 'walking goes on from where the glitch landed');
    expect(m.distanceM, closeTo(5, 0.1));
  });

  test('standing for minutes, then one step: only the step\'s time is active',
      () {
    final m = ActivityMeter()..add(a, at(0));
    m.add(north(4), at(600)); // 10 minutes later
    expect(
        m.activeTime.inSeconds, (4 / ActivityMeter.minActiveSpeedMps).round());
  });

  test('kcal = MET × kg × active hours; climbs > 8 % count as MET 6,0', () {
    // flat: 1 h of walking
    final flat = ActivityMeter()..add(a, at(0));
    for (var i = 1; i <= 720; i++) {
      flat.add(north(i * 4.0), at(i * 5));
    }
    expect(flat.activeTime, const Duration(hours: 1));
    expect(flat.kcal(), closeTo(3.5 * 60, 0.5));
    expect(flat.kcal(weightKg: 80), closeTo(3.5 * 80, 0.5));

    // the same walk up a 10 % slope
    double? slope(GeoPoint p) => (p.lat - a.lat) * 110540 * 0.10;
    final up = ActivityMeter(elevationAt: slope)..add(a, at(0));
    for (var i = 1; i <= 720; i++) {
      up.add(north(i * 4.0), at(i * 5));
    }
    expect(up.climbTime, const Duration(hours: 1));
    expect(up.kcal(), closeTo(6.0 * 60, 0.5));

    // and down it: not a climb
    double? down(GeoPoint p) => -(slope(p)!);
    final dn = ActivityMeter(elevationAt: down)..add(a, at(0));
    for (var i = 1; i <= 10; i++) {
      dn.add(north(i * 4.0), at(i * 5));
    }
    expect(dn.climbTime, Duration.zero);
  });

  test('slope from the real trail graph (heights between nodes)', () {
    final content = loadTestContent();
    final router = GraphTrailRouter.fromContent(content);
    final node = content.graph.nodes.values.first;
    expect(router.elevationAt(node.position), closeTo(node.elevationM, 0.01));
    expect(router.elevationAt(const GeoPoint(-6.8915, 107.6107)), isNull,
        reason: 'far from every trail (ITB)');
  });

  test('snapshot survives a restart; an old record keeps its distance', () {
    final m = ActivityMeter()..add(a, at(0));
    m
      ..add(north(5), at(6))
      ..add(north(10), at(12));
    final again = ActivityMeter()..restore(m.toJson());
    expect(again.distanceM, closeTo(10, 0.1));
    expect(again.activeTime, const Duration(seconds: 12));
    expect(again.kcal(), closeTo(m.kcal(), 0.01));

    final legacy = ActivityMeter()..restore(null, walkedM: 500);
    expect(legacy.distanceM, 500);
    expect(legacy.activeTime.inSeconds, 600, reason: '500 m at 3 km/h');

    expect(() => ActivityMeter().restore({'distance_m': 'x', 'flat_s': -3}),
        returnsNormally);
  });
}
