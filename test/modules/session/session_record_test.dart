import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/session/session.dart';

SessionRecord _record({DateTime? start, String mode = 'real'}) => SessionRecord(
      id: 's1',
      startedAt: start ?? DateTime(2026, 11, 14, 9, 30),
      mode: mode,
      routeId: 'sedang',
      interests: ['sejarah'],
      walkedM: 812.34,
      trail: const [
        GeoPoint(-6.8581234567, 107.6307),
        GeoPoint(-6.857, 107.631)
      ],
      events: [
        VisitEvent(
            at: DateTime(2026, 11, 14, 9, 50),
            poiId: 'P05',
            kind: VisitKind.triggered,
            how: 'gps'),
        VisitEvent(
            at: DateTime(2026, 11, 14, 9, 51),
            poiId: 'P05',
            kind: VisitKind.visited,
            how: 'opened'),
        VisitEvent(
            at: DateTime(2026, 11, 14, 10, 5),
            poiId: 'P06',
            kind: VisitKind.triggered,
            how: 'qr'),
      ],
      triggerState: {
        'pois': {
          'P05': {'state': 'visited'}
        }
      },
    );

void main() {
  test('JSON round trip keeps the log, trail and trigger snapshot', () {
    final back = SessionRecord.fromJson(_record().toJson());
    expect(back.routeId, 'sedang');
    expect(back.walkedM, closeTo(812.3, 0.01));
    expect(back.trail, hasLength(2));
    expect(back.trail.first.lat, closeTo(-6.858123, 1e-9),
        reason: 'stored with 6 decimals');
    expect(back.events.map((e) => (e.poiId, e.kind, e.how)), [
      ('P05', VisitKind.triggered, 'gps'),
      ('P05', VisitKind.visited, 'opened'),
      ('P06', VisitKind.triggered, 'qr'),
    ]);
    expect(back.triggerState?['pois'], isA<Map<String, Object?>>());
    expect(back.isEnded, isFalse);
  });

  test('triggered and visited stay separate (D05)', () {
    final r = _record();
    expect(r.triggeredIds, {'P05', 'P06'});
    expect(r.visitedIds, {'P05'});
  });

  test('resume only an unfinished session of the same mode from today, < 12 h',
      () {
    final now = DateTime(2026, 11, 14, 11);
    expect(_record().canResume(now: now, mode: 'real'), isTrue);
    expect(_record().canResume(now: now, mode: 'demo'), isFalse,
        reason: 'GPS and demo positions must not mix');
    expect(
        _record(start: DateTime(2026, 11, 13, 15))
            .canResume(now: now, mode: 'real'),
        isFalse,
        reason: 'yesterday');
    expect(
        _record(start: DateTime(2026, 11, 14, 12))
            .canResume(now: now, mode: 'real'),
        isFalse,
        reason: 'starts in the future (clock changed)');
    final ended = _record()..endedAt = DateTime(2026, 11, 14, 10);
    expect(ended.canResume(now: now, mode: 'real'), isFalse);
  });

  test('store: current → finish → last; unreadable values are ignored',
      () async {
    final kv = MemoryKeyValueStore();
    final store = SessionStore(kv);
    final r = _record();
    await store.save(r);
    expect(store.loadCurrent()?.id, 's1');
    await store.finish(r..endedAt = DateTime(2026, 11, 14, 12));
    expect(store.loadCurrent(), isNull);
    expect(store.loadLast()?.isEnded, isTrue);

    await kv.setString(SessionStore.currentKey, '{"id": 42');
    expect(store.loadCurrent(), isNull);
  });
}
