import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';

void main() {
  test('FakeClock can be set and advanced (used for TC-10)', () {
    final clock = FakeClock(DateTime(2026, 11, 7, 15, 0));
    clock.advance(const Duration(minutes: 30));
    expect(clock.now(), DateTime(2026, 11, 7, 15, 30));
    clock.setNow(DateTime(2026, 11, 7, 9, 0));
    expect(clock.now().hour, 9);
  });

  test('EventBus delivers only the subscribed event type', () async {
    final bus = EventBus();
    final at = DateTime(2026, 11, 7, 10, 0);
    final received = <PoiTriggered>[];
    final sub = bus.on<PoiTriggered>().listen(received.add);

    bus.publish(SessionEnded(at: at, sessionId: 's1'));
    bus.publish(PoiTriggered(at: at, poiId: 'P05', source: TriggerSource.qr));
    await Future<void>.delayed(Duration.zero);

    expect(received, hasLength(1));
    expect(received.single.poiId, 'P05');
    expect(received.single.source, TriggerSource.qr);

    await sub.cancel();
    await bus.dispose();
  });
}
