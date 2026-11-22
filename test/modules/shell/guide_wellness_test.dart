import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/modules/audio/audio.dart';
import 'package:jelajah_taman/modules/location/location.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/shell/src/state/guide_controller.dart';
import 'package:jelajah_taman/modules/shell/src/state/guide_prefs.dart';
import 'package:jelajah_taman/modules/shell/src/state/places.dart';

import '../../helpers/test_content.dart';
import 'guide_controller_test.dart' show FakeLocation;
import 'voice_alerts_test.dart' show FakeTts;

/// #32 preferences across restarts, T27/D11 walking + kcal, #33 snooze, UC-F08-3 rest point,
/// T07 narration read aloud.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeLocation gps;
  late FakeClock clock;
  late MemoryKeyValueStore store;
  late ProviderContainer c;
  FakeTts? tts;

  ProviderContainer container() => ProviderContainer(overrides: [
        ...buildOverrides(
            content: loadTestContent(),
            clock: clock,
            basemap: loadTestBasemap()),
        locationServiceProvider.overrideWithValue(gps),
        keyValueStoreProvider.overrideWithValue(store),
        if (tts != null) ttsServiceProvider.overrideWithValue(tts!),
      ]);

  setUp(() {
    gps = FakeLocation();
    clock = FakeClock(DateTime(2026, 11, 22, 9));
    store = MemoryKeyValueStore();
    tts = null;
    c = container();
  });
  tearDown(() => c.dispose());

  GuideController guide() => c.read(guideProvider);

  /// The app is killed and opened again on the same phone storage.
  GuideController relaunch() {
    c.dispose();
    c = container();
    return guide();
  }

  void walk(GeoPoint p, {int s = 3, double acc = 6}) {
    clock.advance(Duration(seconds: s));
    gps.push(p, clock.now(), acc: acc);
  }

  GeoPoint lerp(GeoPoint a, GeoPoint b, double t) =>
      GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);

  group('preferences survive closing the app (#32)', () {
    test('first launch: defaults, not onboarded', () {
      final g = guide();
      expect(g.onboarded, isFalse);
      expect((g.autoPlay, g.voiceGuidance, g.vibration), (false, true, true));
      expect(g.hydrationMin, 45);
      expect(g.textScale, 1.0);
      expect(g.weightKg, isNull);
    });

    test('onboarding, Settings and Home choices come back after a restart', () {
      guide()
        ..finishOnboarding()
        ..toggleInterest('rekreasi')
        ..chooseRoute('sedang')
        ..update(() => guide()
          ..autoPlay = true
          ..voiceGuidance = false
          ..vibration = false
          ..hydrationMin = 30
          ..textScale = 1.3
          ..weightKg = 72);
      final g = relaunch();
      expect(g.onboarded, isTrue);
      expect(g.interests, {'sejarah', 'alam', 'rekreasi'});
      expect(g.routeId, 'sedang');
      expect((g.autoPlay, g.voiceGuidance, g.vibration), (true, false, false));
      expect(g.hydrationMin, 30);
      expect(g.textScale, 1.3);
      expect(g.weightKg, 72);
    });

    test('"Ulangi perkenalan" is remembered too', () {
      guide().finishOnboarding();
      relaunch().update(() => guide().onboarded = false);
      expect(relaunch().onboarded, isFalse);
    });

    test('a broken or strange stored value falls back, the rest is kept', () {
      store.setString(
          GuidePrefs.key,
          '{"onboarded": true, "hydration_min": 17, "text_scale": "big", '
          '"weight_kg": 400, "route_id": "nope", "vibration": false}');
      final g = relaunch();
      expect(g.onboarded, isTrue);
      expect(g.vibration, isFalse);
      expect(g.hydrationMin, 45);
      expect(g.textScale, 1.0);
      expect(g.weightKg, isNull);
      expect(g.routeId, 'santai', reason: 'unknown route');
      store.setString(GuidePrefs.key, '{oops');
      expect(relaunch().onboarded, isFalse);
    });
  });

  group('walking and kcal (T27, D11)', () {
    test('fixes worse than 20 m don\'t add distance (real mode)', () {
      final g = guide();
      final a = g.content.gate.position;
      final b = g.place('P05')!.position;
      walk(a);
      g.startSession();
      for (var i = 1; i <= 6; i++) {
        walk(lerp(a, b, i / 20), s: 10, acc: 25);
      }
      expect(g.walkedM, 0);
      expect(g.kcal, 0);
      for (var i = 7; i <= 12; i++) {
        walk(lerp(a, b, i / 20), s: 10, acc: 8);
      }
      expect(g.walkedM, greaterThan(0));
      expect(g.activeTime, greaterThan(Duration.zero));
      expect(g.kcal, greaterThan(0));
    });

    test(
        'standing still for an hour burns nothing extra (kcal from active time)',
        () {
      final g = guide();
      final a = g.content.gate.position;
      walk(a);
      g.startSession();
      for (var i = 0; i < 1200; i++) {
        walk(a, s: 3, acc: 12);
      }
      expect(g.sessionDuration, greaterThan(const Duration(minutes: 59)));
      expect(g.kcal, 0);
    });

    test('kcal = 3,5 × kg × active hours on flat ground; weight from Settings',
        () {
      final g = guide();
      g.walkedM = 2500; // 50 min at 3 km/h, flat
      expect(g.kcal, closeTo(3.5 * 60 * 50 / 60, 0.5));
      g.update(() => g.weightKg = 80);
      expect(g.kcal, closeTo(3.5 * 80 * 50 / 60, 0.5));
    });

    test('active time is restored with the session', () {
      final g = guide();
      final a = g.content.gate.position;
      final b = g.place('P05')!.position;
      walk(a);
      g.startSession();
      for (var i = 1; i <= 10; i++) {
        walk(lerp(a, b, i / 20), s: 10);
      }
      final (walked, active) = (g.walkedM, g.activeTime);
      clock.advance(const Duration(seconds: 20)); // past the 15 s save spacing
      walk(lerp(a, b, 11 / 20), s: 10);
      final again = relaunch();
      expect(again.sessionActive, isTrue);
      expect(again.walkedM, greaterThan(walked));
      expect(again.activeTime, greaterThan(active));
    });
  });

  group('reminders', () {
    test('#33 "Ingatkan 10 menit lagi" brings hydration back in 10 min', () {
      final g = guide()..setMode(AppMode.demo);
      g
        ..update(() => g.hydrationMin = 30)
        ..startSession();
      clock.advance(const Duration(minutes: 30));
      g.heartbeat();
      expect(g.reminder, GuideReminder.hydration);
      expect(g.hydrationLine, 'Sudah 30 menit berjalan. Minum air dulu, yuk.');
      g.snoozeReminder();
      expect(g.reminder, isNull);
      clock.advance(const Duration(minutes: 9, seconds: 59));
      g.heartbeat();
      expect(g.reminder, isNull);
      clock.advance(const Duration(seconds: 1));
      g.heartbeat();
      expect(g.reminder, GuideReminder.hydration);
      expect(g.hydrationLine, 'Sudah 40 menit berjalan. Minum air dulu, yuk.');
    });

    test('a snooze survives an app restart', () {
      final g = guide()..setMode(AppMode.demo);
      g
        ..update(() => g.hydrationMin = 30)
        ..startSession();
      clock.advance(const Duration(minutes: 30));
      g
        ..heartbeat()
        ..snoozeReminder();
      final again = relaunch();
      clock.advance(const Duration(minutes: 10));
      again.heartbeat();
      expect(again.reminder, GuideReminder.hydration);
    });

    test('UC-F08-3: arriving at a rest point restarts the hydration timer', () {
      final g = guide();
      final gate = g.content.gate.position;
      walk(gate);
      g
        ..update(() => g.hydrationMin = 30)
        ..startSession();
      final rest = g.nearestRest;
      expect(rest.kind, 'istirahat');
      expect(g.startNavigation(rest), isTrue);
      clock.advance(const Duration(minutes: 25));
      walk(rest.position);
      walk(rest.position);
      expect(g.arrivedAt?.id, rest.id);
      g.finishArrival();
      clock.advance(const Duration(minutes: 10)); // 35 min into the session
      g.heartbeat();
      expect(g.reminder, isNull, reason: 'the break was taken at minute 25');
      clock.advance(const Duration(minutes: 20)); // 30 min after the rest point
      g.heartbeat();
      expect(g.reminder, GuideReminder.hydration);
    });

    test('the hydration reminder navigates to the nearest rest point', () {
      final g = guide()..setMode(AppMode.demo);
      g
        ..update(() => g.hydrationMin = 30)
        ..startSession();
      clock.advance(const Duration(minutes: 30));
      g.heartbeat();
      final rest = g.reminderDestination(GuideReminder.hydration);
      expect(g.navigateForReminder(GuideReminder.hydration), isTrue);
      expect(g.reminder, isNull);
      expect(g.navigation?.to.id, rest.id);
      expect(g.reminderDestination(GuideReminder.closing).id, 'P01');
    });
  });

  group('narration read aloud when there is no recording (T07)', () {
    late GuideController g;
    late Place p05;

    setUp(() async {
      tts = FakeTts()..hold = true;
      c.dispose();
      c = container(); // no narration player bound: no file can play
      g = guide()..setMode(AppMode.demo);
      p05 = g.place('P05')!;
      await Future<void>.delayed(Duration.zero); // voice support check
    });

    test('sentence by sentence through the voice, at narration priority',
        () async {
      expect(g.narrationSource(p05), NarrationSource.voice);
      final script = NarrationScript.fromText(p05.poi!.displayText);
      expect(script.sentences.length, greaterThan(1));
      expect(g.audioLength(p05), script.length);
      g.playAudio(p05);
      await Future<void>.delayed(Duration.zero);
      expect(tts!.said.single, (script.sentences[0], VoicePriority.narration));
      tts!.release();
      await Future<void>.delayed(Duration.zero);
      expect(tts!.said.last.$1, script.sentences[1]);
      expect(g.audioPos, script.endOf(0));
    });

    test('pause stops the voice; play goes on from that sentence', () async {
      final script = NarrationScript.fromText(p05.poi!.displayText);
      g.playAudio(p05);
      await Future<void>.delayed(Duration.zero);
      tts!.release();
      await Future<void>.delayed(Duration.zero);
      g.pauseAudio();
      await Future<void>.delayed(Duration.zero);
      expect(tts!.cancelled, [VoicePriority.narration]);
      final said = tts!.said.length;
      await Future<void>.delayed(Duration.zero);
      expect(tts!.said.length, said, reason: 'nothing more after the pause');
      g.playAudio(p05);
      await Future<void>.delayed(Duration.zero);
      expect(tts!.said.last.$1, script.sentences[1]);
    });

    test('read to the end = narration done (E7 → recommendation)', () async {
      tts!.hold = false;
      g
        ..startSession()
        ..playAudio(p05);
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(g.audioPlaying, isFalse);
      expect(g.narrationsDone, 1);
      expect(g.audioProgress, 1);
    });

    test('without an Indonesian voice: simulated, never rushed through',
        () async {
      c.dispose();
      tts = _MuteTts();
      c = container();
      final g2 = guide();
      await Future<void>.delayed(Duration.zero);
      expect(g2.narrationSource(g2.place('P05')!), NarrationSource.simulated);
    });
  });
}

class _MuteTts extends FakeTts {
  @override
  Future<VoiceSupport> get support async => VoiceSupport.missing;
}
