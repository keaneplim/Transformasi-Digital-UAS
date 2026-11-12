import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/models/location_models.dart';
import 'package:jelajah_taman/modules/trigger/src/domain/trigger_engine.dart';
// Note: Assuming a MockContentRepository and FakeClock are available in test helpers.

void main() {
  late TriggerEngine engine;
  late FakeClock clock;
  late MockContentRepository content;

  setUp(() {
    clock = FakeClock(DateTime(2026, 11, 7, 10, 0));
    content = MockContentRepository(); // Configured with P05 (radius 20m) & P06 (radius 20m)
    engine = TriggerEngine(content, clock);
  });

  LocationFix makeFix(double distanceToP05, {double accuracy = 10.0}) {
    // Helper to generate fixes at specific distances for testing
    return LocationFix(
      position: GeoPoint.offsetFrom(content.poiById('P05')!.position, distanceToP05),
      accuracyM: accuracy,
      at: clock.now(),
    );
  }

  test('1. Walk-in replay: exactly one Approaching, then one Triggered', () {
    // 50m (Outside) -> 45m (Approaching) -> 10m (Debounce 1) -> 10m (Triggered)
    expect(engine.processFix(makeFix(50)), isEmpty);
    
    final approachEvents = engine.processFix(makeFix(45));
    expect(approachEvents.length, 1);
    expect(approachEvents.first, isA<PoiApproached>());
    
    expect(engine.processFix(makeFix(10)), isEmpty); // Debounce 1
    
    final triggerEvents = engine.processFix(makeFix(10)); // Debounce 2
    expect(triggerEvents.length, 1);
    expect(triggerEvents.first, isA<PoiTriggered>());
  });

  test('2. Single fix inside r then outside: no trigger (debounce)', () {
    engine.processFix(makeFix(45)); // Approaching
    engine.processFix(makeFix(10)); // Debounce 1
    final events = engine.processFix(makeFix(50)); // Outside, resets debounce
    
    expect(events, isEmpty);
    expect(engine.states['P05'], PoiState.outside);
  });

  test('3. 3 min of jitter inside r: one trigger only (TC-03)', () {
    engine.processFix(makeFix(45));
    engine.processFix(makeFix(10));
    engine.processFix(makeFix(10)); // Triggered here
    
    // Simulate 3 minutes of wandering inside the radius
    for (int i = 0; i < 60; i++) {
      clock.advance(const Duration(seconds: 3));
      final events = engine.processFix(makeFix(15));
      expect(events, isEmpty, reason: 'Should not re-trigger while inside');
    }
  });

  test('4. Exit > r+15 and re-enter: respects 10 min cooldown (D04)', () {
    // Trigger
    engine.processFix(makeFix(10));
    engine.processFix(makeFix(10));
    engine.states['P05'] = PoiState.cooldown; // Simulate transitioning to cooldown
    
    // Exit > r+15m (Radius 20 + 15 = 35m)
    engine.processFix(makeFix(40)); 
    
    // Re-enter at 5 minutes -> No trigger
    clock.advance(const Duration(minutes: 5));
    expect(engine.processFix(makeFix(10)), isEmpty);
    
    // Exit again, re-enter at 11 minutes -> Trigger
    engine.processFix(makeFix(40));
    clock.advance(const Duration(minutes: 6));
    engine.processFix(makeFix(10)); // Debounce 1
    final events = engine.processFix(makeFix(10)); // Debounce 2
    expect(events.first, isA<PoiTriggered>());
  });

  test('5. Two overlapping POIs, A visited -> B triggers (D01)', () {
    // Setup: P05 is visited, P06 overlaps P05.
    engine.states['P05'] = PoiState.visited;
    
    // Fix is 10m from P05 and 15m from P06
    final fix = LocationFix(
      position: GeoPoint.between(content.poiById('P05')!.position, content.poiById('P06')!.position),
      accuracyM: 5.0,
      at: clock.now(),
    );
    
    engine.processFix(fix); // Debounce 1 for P06
    final events = engine.processFix(fix); // Debounce 2
    
    expect((events.first as PoiTriggered).poiId, 'P06'); // P05 skipped
  });

  test('6. Visited POI walk-by: no approaching buzz (D02)', () {
    engine.states['P05'] = PoiState.visited;
    final events = engine.processFix(makeFix(45)); // Enter approaching zone
    expect(events, isEmpty); // No PoiApproached event
  });

  test('7. Boundary oscillation r+28 <-> r+35: one buzz only (D03)', () {
    // Radius 20m. Approaching at 50m (r+30), Exit at 60m (r+40)
    expect(engine.processFix(makeFix(48)).length, 1); // Buzz
    expect(engine.processFix(makeFix(55)), isEmpty); // No exit yet (needs > 60m)
    expect(engine.processFix(makeFix(48)), isEmpty); // Already buzzed
    
    engine.processFix(makeFix(65)); // Exit approaching
    final events = engine.processFix(makeFix(48)); // Re-enter
    expect(events.length, 1); // Buzz again
  });

  test('8. Weak fixes ignored, but do not cancel good debounce', () {
    engine.processFix(makeFix(45)); // Approaching
    engine.processFix(makeFix(10)); // Debounce 1 (Good)
    
    // Weak fix in between
    engine.processFix(makeFix(10, accuracy: 45.0)); 
    
    final events = engine.processFix(makeFix(10)); // Debounce 2 (Good)
    expect(events.first, isA<PoiTriggered>());
  });

  test('9. QR scan -> Triggered regardless of GPS state', () {
    engine.onQrScanned('P05');
    expect(engine.states['P05'], PoiState.visited); // Direct to visited per PRD §4.2
  });
}