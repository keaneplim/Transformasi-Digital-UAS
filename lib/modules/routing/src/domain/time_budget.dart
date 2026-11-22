import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/content/content.dart';

import 'trail_router.dart';

/// "Is there still time before the park closes?", answered in one place (T23).
///
/// The closing reminder (A03), the recommendation filter (F07) and the route chooser (F08)
/// all use this, so they can never disagree about the same minute (TC-10 checks two of them
/// at once). The rule is PRD A03 / F07 AC3: everything must be done, including the walk back
/// to the gate, by **closing time − closing buffer** (15 min, `closing_buffer_min`).
///
/// Pure Dart: time is passed in (rule R7), walking times come from the [TrailRouter].
class TimeBudget {
  TimeBudget({
    required TrailRouter router,
    required ParkConfig park,
    required this.gateNodeId,
    required this.buffer,
  })  : _router = router,
        _park = park;

  factory TimeBudget.fromContent(
          ContentRepository content, TrailRouter router) =>
      TimeBudget(
        router: router,
        park: content.park,
        gateNodeId: content.gate.graphNode,
        buffer:
            Duration(minutes: content.park.param('closing_buffer_min').round()),
      );

  final TrailRouter _router;
  final ParkConfig _park;

  /// Graph node of the gate (P01): every visit ends with the walk back to it.
  final String gateNodeId;

  /// Safety margin before closing (15 min in park.json).
  final Duration buffer;

  /// Closing time on the day of [now].
  DateTime closingTime(DateTime now) => _park.closingTimeOn(now);

  /// The latest moment the visitor should be back at the gate: closing − buffer.
  DateTime deadline(DateTime now) => closingTime(now).subtract(buffer);

  /// Walking time from [from] to the gate, slope included (D09).
  Duration walkToGate(GeoPoint from) => _router.walkingTime(from, gateNodeId);

  /// Walking distance in metres from [from] to the gate (used by UC-A03-2 final call).
  double distanceToGateM(GeoPoint from) =>
      _router.walkingDistanceM(from, gateNodeId);

  /// Time left for walking and visiting: closing − now − buffer. Negative once past it.
  Duration remaining(DateTime now) => deadline(now).difference(now);

  /// Walk to the POI, stay [visit], walk back to the gate.
  Duration tripVia(GeoPoint from, String poiNodeId, Duration visit) =>
      _router.walkingTime(from, poiNodeId) +
      visit +
      _router.walkingTimeBetween(poiNodeId, gateNodeId);

  /// F07 filter: the trip via this POI ends no later than [deadline] (equal still fits).
  bool fits(GeoPoint from, String poiNodeId, Duration visit, DateTime now) =>
      tripVia(from, poiNodeId, visit) <= remaining(now);

  /// F08 route chooser: routes start and end at the gate, so the whole route has to fit.
  bool routeFits(Duration routeDuration, DateTime now) =>
      routeDuration <= remaining(now);

  /// A03: the moment to start walking back, closing − walk to gate − buffer. It moves with
  /// the visitor: closer to the gate, later reminder.
  DateTime closingReminderAt(GeoPoint from, DateTime now) =>
      deadline(now).subtract(walkToGate(from));

  /// UC-A03-2 final call: closing − walk to gate (no buffer left).
  DateTime finalCallAt(GeoPoint from, DateTime now) =>
      closingTime(now).subtract(walkToGate(from));
}
