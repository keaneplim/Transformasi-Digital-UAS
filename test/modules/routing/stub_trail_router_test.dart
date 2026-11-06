import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/routing/routing.dart';

import '../../helpers/test_content.dart';

void main() {
  final content = loadTestContent();
  final router = StubTrailRouter(content);
  final gate = content.gate;
  final cave = content.poiById('P05')!;

  test('walking distance is straight line × 1.3', () {
    final straight = haversineM(gate.position, cave.position);
    expect(router.walkingDistanceM(gate.position, cave.graphNode),
        closeTo(straight * StubTrailRouter.detourFactor, 1e-6));
  });

  test('walking time uses park walk speed', () {
    final d = router.walkingDistanceM(gate.position, cave.graphNode);
    final speed = content.park.param('walk_speed_m_per_min');
    expect(router.walkingTime(gate.position, cave.graphNode).inSeconds,
        (d / speed * 60).round());
  });

  test('unknown node: route is null, distance throws', () {
    expect(router.route(gate.position, 'NOPE'), isNull);
    expect(() => router.walkingDistanceM(gate.position, 'NOPE'),
        throwsArgumentError);
  });
}
