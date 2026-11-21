import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/modules/audio/audio.dart';
import 'package:jelajah_taman/modules/location/location.dart';
import 'package:jelajah_taman/modules/routing/routing.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/shell/src/state/guide_controller.dart';
import 'package:jelajah_taman/modules/shell/src/state/places.dart';
import 'package:jelajah_taman/modules/shell/src/state/voice_alerts.dart';

import '../../helpers/test_content.dart';
import 'guide_controller_test.dart' show FakeLocation;

/// Records what would be said. Lines end at once unless [hold] is set; then [release] ends them.
class FakeTts implements TtsService {
  final said = <(String, VoicePriority)>[];
  final _duck = StreamController<VoiceDuck>.broadcast(sync: true);
  final _held = <Completer<void>>[];
  bool hold = false;
  int stopAlls = 0;

  List<String> texts([VoicePriority? p]) => [
        for (final (t, pr) in said)
          if (p == null || pr == p) t
      ];

  void duckTo(VoiceDuck d) => _duck.add(d);

  void release() {
    for (final c in _held) {
      c.complete();
    }
    _held.clear();
  }

  @override
  Future<void> say(String text,
      {VoicePriority priority = VoicePriority.triggerPrompt}) {
    said.add((text, priority));
    if (!hold) return Future.value();
    final c = Completer<void>();
    _held.add(c);
    return c.future;
  }

  @override
  Stream<VoiceDuck> get duck => _duck.stream;

  @override
  Future<VoiceSupport> get support async => VoiceSupport.ready;

  @override
  Future<void> stopAll() async => stopAlls++;
}

void main() {
  TestWidgetsFlutterBinding
      .ensureInitialized(); // haptics use a platform channel
  late FakeLocation gps;
  late FakeClock clock;
  late ProviderContainer c;
  late FakeTts tts;
  late VoiceAlerts voice;
  GuideController guide() => c.read(guideProvider);

  void setUpGuide() {
    gps = FakeLocation();
    clock = FakeClock(DateTime(2026, 11, 14, 10));
    tts = FakeTts();
    c = ProviderContainer(overrides: [
      ...buildOverrides(
          content: loadTestContent(), clock: clock, basemap: loadTestBasemap()),
      locationServiceProvider.overrideWithValue(gps),
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    ]);
    voice =
        VoiceAlerts(guide: guide(), tts: tts, bus: c.read(eventBusProvider));
  }

  void tearDownGuide() {
    voice.dispose();
    c.dispose();
  }

  void walk(GeoPoint p, {int s = 3}) {
    clock.advance(Duration(seconds: s));
    gps.push(p, clock.now());
  }

  /// Two good fixes at [p]: the real engine triggers it (debounce D02).
  void arriveAt(Place p) {
    walk(p.position);
    walk(p.position);
  }

  group('with the real clock', () {
    setUp(setUpGuide);
    tearDown(tearDownGuide);

    test('F07: walking away from a visited place names the next one', () {
      final g = guide()..startSession();
      final p05 = g.place('P05')!;
      arriveAt(p05);
      g.resolveTrigger(engaged: true);
      final away = GeoPoint(
          (p05.position.lat + g.content.gate.position.lat) / 2,
          (p05.position.lng + g.content.gate.position.lng) / 2);
      walk(away, s: 31);
      walk(away);
      final next = g.lastRecommendation!.rec.items.first.place.name;
      expect(tts.said.last, ('Berikutnya: $next.', VoicePriority.reminder));
    });

    test('F07: closing the detail shows the sheet but says nothing', () {
      final g = guide()..startSession();
      final p05 = g.place('P05')!;
      arriveAt(p05);
      g.resolveTrigger(engaged: true);
      final said = tts.said.length;
      g.detailClosed(p05);
      expect(g.recommendationCue, isNotNull);
      expect(tts.said.length, said);
    });

    test('trigger prompt names the place and asks (F04 b)', () {
      final g = guide()..startSession();
      final p05 = g.place('P05')!;
      arriveAt(p05);
      expect(g.pendingTrigger?.id, 'P05');
      expect(tts.said, [
        (
          'Anda tiba di ${p05.name}. Ingin mendengar ceritanya?',
          VoicePriority.triggerPrompt
        ),
      ]);
    });

    test('silent outside a session', () {
      final g = guide();
      g.triggerNow(g.place('P06')!);
      expect(g.pendingTrigger?.id, 'P06');
      expect(tts.said, isEmpty);
    });

    test('Auto-Play: short prompt, the narration starts once it has been said',
        () async {
      final g = guide()
        ..autoPlay = true
        ..startSession();
      tts.hold = true;
      final p05 = g.place('P05')!;
      arriveAt(p05);
      expect(tts.texts(), ['Anda tiba di ${p05.name}.']);
      await pumpEventQueue();
      expect(g.audioPlaying, isFalse, reason: 'not over the prompt');
      tts.release();
      await pumpEventQueue();
      expect(g.audioPlaying, isTrue);
      expect(g.nowPlaying?.id, 'P05');
      expect(g.visited, contains('P05'), reason: 'listened = visited (D05)');
      g.stopAudio();
    });

    test('Auto-Play does not start after the visitor chose Nanti', () async {
      final g = guide()
        ..autoPlay = true
        ..startSession();
      tts.hold = true;
      arriveAt(g.place('P05')!);
      g.resolveTrigger(engaged: false);
      tts.release();
      await pumpEventQueue();
      expect(g.audioPlaying, isFalse);
    });

    test(
        'navigation: start, every turn once ~20 m ahead in order, arrival (F04 e, TC-08)',
        () {
      final g = guide();
      final gate = g.content.gate.position;
      walk(gate);
      g.startSession();
      final to = g.place('FS08')!; // a facility: arrival never triggers it
      expect(g.startNavigation(to), isTrue);
      final route = g.navigation!.route;
      final min = (route.eta.inSeconds / 60).ceil();
      expect(tts.texts(VoicePriority.navigation),
          ['Menuju ${to.name}, sekitar $min menit.']);

      final turns = [
        for (final t in route.turns)
          if (t.direction != TurnDirection.arrive) t
      ];
      expect(turns, isNotEmpty, reason: 'the test route has turns');
      // Walk the route in 5 m steps (1.7 m/s): each turn is announced before it is reached.
      final spokenAt = <double>[];
      var heard = 1;
      for (var m = 0.0; m <= route.distanceM + 15; m += 5) {
        walk(
            m <= route.distanceM ? pointAlong(route.polyline, m) : to.position);
        if (g.arrivedAt != null) break;
        final nav = tts.texts(VoicePriority.navigation);
        for (; heard < nav.length; heard++) {
          spokenAt.add(g.navProgressM);
        }
      }
      final nav = tts.texts(VoicePriority.navigation);
      expect(nav.sublist(1, 1 + turns.length), [for (final t in turns) t.text]);
      for (var i = 0; i < turns.length; i++) {
        final ahead = turns[i].distanceFromStartM - spokenAt[i];
        expect(ahead, inInclusiveRange(-5, VoiceAlerts.turnAheadM),
            reason: 'turn $i heard ${ahead.toStringAsFixed(0)} m before it');
      }
      expect(g.arrivedAt?.id, 'FS08');
      expect(nav.last, 'Anda tiba di ${to.name}.');
      expect(nav.length, turns.length + 2, reason: 'nothing said twice');
    });

    test('arriving at a POI that triggers: one "Anda tiba di", from the prompt',
        () {
      final g = guide();
      walk(g.content.gate.position);
      g.startSession();
      final to = g.place('P06')!;
      g.startNavigation(to);
      final route = g.navigation!.route;
      for (var m = 0.0; m <= route.distanceM + 15; m += 5) {
        walk(
            m <= route.distanceM ? pointAlong(route.polyline, m) : to.position);
        // Answer the cards of POIs on the way, as a visitor would.
        if (g.pendingTrigger case final p? when p.id != 'P06') {
          g.resolveTrigger(engaged: false);
        }
      }
      expect(g.arrivedAt?.id, 'P06');
      expect(tts.texts().where((t) => t.startsWith('Anda tiba di ${to.name}')),
          ['Anda tiba di ${to.name}. Ingin mendengar ceritanya?']);
    });

    test('arriving while another card is still open: the arrival line is said',
        () {
      final g = guide();
      walk(g.content.gate.position);
      g.startSession();
      final to = g.place('P06')!;
      g.startNavigation(to);
      final route = g.navigation!.route;
      for (var m = 0.0; m <= route.distanceM + 15; m += 5) {
        walk(
            m <= route.distanceM ? pointAlong(route.polyline, m) : to.position);
      }
      expect(g.arrivedAt?.id, 'P06');
      expect(g.pendingTrigger?.id, isNot('P06'),
          reason: 'P06 waits behind an unanswered card');
      expect(
          tts.texts(VoicePriority.navigation).last, 'Anda tiba di ${to.name}.');
    });

    test(
        '"Arahan suara" off: no navigation voice, the trigger prompt still speaks',
        () {
      final g = guide()..voiceGuidance = false;
      walk(g.content.gate.position);
      g
        ..startSession()
        ..startNavigation(g.place('P06')!);
      final route = g.navigation!.route;
      for (var m = 0.0; m <= route.distanceM; m += 5) {
        walk(pointAlong(route.polyline, m));
      }
      expect(tts.texts(VoicePriority.navigation), isEmpty);
      expect(tts.texts(VoicePriority.triggerPrompt), isNotEmpty,
          reason: 'POIs on the way still announce themselves');
    });

    test('closing reminder is a safety line, hydration a reminder (F04 f)',
        () async {
      guide().startSession();
      final bus = c.read(eventBusProvider);
      bus
        ..publish(ReminderDue(
            at: clock.now(),
            kind: ReminderKind.closing,
            text: 'Kawasan tutup pukul 16.00.'))
        ..publish(ReminderDue(
            at: clock.now(),
            kind: ReminderKind.hydration,
            text: 'Minum air dulu, yuk.'));
      await pumpEventQueue();
      expect(tts.said, [
        ('Kawasan tutup pukul 16.00.', VoicePriority.safety),
        ('Minum air dulu, yuk.', VoicePriority.reminder),
      ]);
    });

    test('ending the session silences the voice', () {
      final g = guide()..startSession();
      g.endSession();
      expect(tts.stopAlls, 1);
    });

    test('a safety line pauses the narration and resumes it after', () {
      final g = guide()..startSession();
      final p = g.place('P05')!;
      g.playAudio(p);
      tts.duckTo(VoiceDuck.pause);
      expect(g.audioPlaying, isFalse);
      tts.duckTo(VoiceDuck.none);
      expect(g.audioPlaying, isTrue);
      expect(g.nowPlaying?.id, 'P05');

      tts.duckTo(VoiceDuck.pause);
      g.pauseAudio(); // the visitor pauses meanwhile: their choice wins
      tts.duckTo(VoiceDuck.none);
      expect(g.audioPlaying, isFalse);
      g.stopAudio();
    });
  });

  group('with fake time', () {
    test('Auto-Play starts at 3 s even if the voice never finishes (AC2)', () {
      fakeAsync((async) {
        setUpGuide();
        final g = guide()
          ..autoPlay = true
          ..startSession();
        tts.hold = true; // never released
        arriveAt(g.place('P05')!);
        async.elapse(const Duration(milliseconds: 2900));
        expect(g.audioPlaying, isFalse);
        async.elapse(const Duration(milliseconds: 200));
        expect(g.audioPlaying, isTrue);
        g.stopAudio();
        tearDownGuide();
        async.flushMicrotasks();
      });
    });

    test('narration to the end: "Selesai. Berikutnya: â€¦" (UC-F04-1 step 5)',
        () {
      fakeAsync((async) {
        setUpGuide();
        final g = guide()..startSession();
        final p = g.place('P05')!;
        arriveAt(p);
        async.flushMicrotasks();
        g.resolveTrigger(engaged: true, how: EngagementKind.listened);
        g.playAudio(p);
        async.elapse(Duration(seconds: g.audioLength(p).ceil() + 1));
        expect(g.audioPlaying, isFalse);
        final next = g.recommend().items.first.place.name;
        expect(tts.said.last,
            ('Selesai. Berikutnya: $next.', VoicePriority.reminder));
        // F07 once per visited POI: listening again says nothing new.
        final said = tts.said.length;
        g.playAudio(p);
        async.elapse(Duration(seconds: g.audioLength(p).ceil() + 1));
        expect(tts.said.length, said);
        g.stopAudio();
        tearDownGuide();
        async.flushMicrotasks();
      });
    });

    test('a narration of a place not visited (D05) recommends nothing', () {
      fakeAsync((async) {
        setUpGuide();
        final g = guide()..startSession();
        final p = g.place('P05')!; // played from Search, never triggered
        g.playAudio(p);
        async.elapse(Duration(seconds: g.audioLength(p).ceil() + 1));
        expect(tts.said.where((s) => s.$1.contains('Berikutnya')), isEmpty);
        expect(g.recommendationCue, isNull);
        tearDownGuide();
        async.flushMicrotasks();
      });
    });
  });
}

GeoPoint pointAlong(List<GeoPoint> line, double m) {
  var left = m;
  for (var i = 1; i < line.length; i++) {
    final a = line[i - 1], b = line[i];
    final seg = haversineM(a, b);
    if (left <= seg && seg > 0) {
      final f = left / seg;
      return GeoPoint(a.lat + (b.lat - a.lat) * f, a.lng + (b.lng - a.lng) * f);
    }
    left -= seg;
  }
  return line.last;
}
