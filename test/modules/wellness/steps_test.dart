import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/modules/session/session.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/shell/src/state/guide_controller.dart';
import 'package:jelajah_taman/modules/wellness/wellness.dart';

import '../../helpers/test_content.dart';

/// The hardware counter: the test pushes cumulative "since boot" values.
class FakeStepSource implements StepSource {
  StreamController<int>? _c;
  int listens = 0;
  bool noSensor = false;

  void push(int raw) => _c!.add(raw);
  bool get listening => _c != null && _c!.hasListener;

  @override
  Stream<int> cumulativeSteps() {
    listens++;
    _c = StreamController<int>(sync: true);
    if (noSensor) {
      scheduleMicrotask(
          () => _c!.addError(StateError('StepCount not available')));
    }
    return _c!.stream;
  }
}

class FakePermissions implements StepPermissions {
  FakePermissions({this.allowed = true});
  bool allowed;
  int requests = 0;

  @override
  Future<bool> granted() async => allowed;
  @override
  Future<bool> request() async {
    requests++;
    return allowed;
  }
}

void main() {
  group('StepCounter (TC-12 rules)', () {
    test('the first reading is the baseline; steps are the increase after it',
        () {
      final c = StepCounter()..start();
      c.onReading(51200); // steps since boot when the session starts
      expect(c.steps, 0);
      c.onReading(51290);
      c.onReading(51400);
      expect(c.steps, 200);
    });

    test('a reboot mid-session (counter back near 0) loses nothing', () {
      final c = StepCounter()..start();
      c
        ..onReading(9000)
        ..onReading(9150) // 150
        ..onReading(30) // rebooted: 30 new steps since boot
        ..onReading(80); // +50
      expect(c.steps, 230);
    });

    test(
        'restore continues from the stored count, incl. steps while the app was closed',
        () {
      final c = StepCounter()
        ..start()
        ..onReading(1000)
        ..onReading(1120);
      final saved = c.toJson();
      final again = StepCounter()..restore(saved);
      again.onReading(1300); // the sensor kept counting while the app was dead
      expect(again.steps, 300);
    });

    test('malformed stored state starts from zero', () {
      final c = StepCounter()..restore({'steps': 'x', 'last_raw': -4});
      expect(c.steps, 0);
      expect(c.hasBaseline, isFalse);
    });
  });

  group('StepTracker', () {
    late FakeStepSource source;
    late FakePermissions perms;
    late StepTracker t;
    var changes = 0;

    setUp(() {
      source = FakeStepSource();
      perms = FakePermissions();
      t = StepTracker(source: source, permissions: perms)
        ..onChange = () => changes++;
      changes = 0;
    });

    test('allowed + sensor: counts, and stop keeps the count for the summary',
        () async {
      await t.start();
      expect(t.status, StepStatus.starting);
      source
        ..push(500)
        ..push(540);
      expect(t.status, StepStatus.counting);
      expect(t.steps, 40);
      expect(changes, greaterThan(1));
      await t.stop();
      expect(source.listening, isFalse);
      expect(t.steps, 40);
    });

    test('"Aktivitas fisik" not allowed: denied, the sensor is never read',
        () async {
      perms.allowed = false;
      await t.start();
      expect(t.status, StepStatus.denied);
      expect(source.listens, 0);
      expect(perms.requests, 0, reason: 'the module never prompts by itself');
    });

    test('no step counter on the phone: noSensor', () async {
      source.noSensor = true;
      await t.start();
      await pumpEventQueue();
      expect(t.status, StepStatus.noSensor);
    });

    test('a new session starts from zero; reset forgets', () async {
      await t.start();
      source
        ..push(100)
        ..push(160);
      await t.start();
      source.push(170); // new baseline
      expect(t.steps, 0);
      source.push(175);
      expect(t.steps, 5);
      await t.reset();
      expect(t.steps, 0);
      expect(t.status, StepStatus.off);
    });
  });

  group('GuideController steps (real mode)', () {
    late FakeStepSource source;
    late FakePermissions perms;
    late MemoryKeyValueStore store;
    late FakeClock clock;
    final containers = <ProviderContainer>[];

    GuideController launch({StepTracker? tracker}) {
      final c = ProviderContainer(overrides: [
        ...buildOverrides(content: loadTestContent(), clock: clock),
        keyValueStoreProvider.overrideWithValue(store),
        stepTrackerProvider.overrideWithValue(
            tracker ?? StepTracker(source: source, permissions: perms)),
      ]);
      containers.add(c);
      return c.read(guideProvider);
    }

    setUp(() {
      source = FakeStepSource();
      perms = FakePermissions();
      store = MemoryKeyValueStore();
      clock = FakeClock(DateTime(2026, 11, 21, 9));
    });
    tearDown(() {
      for (final c in containers) {
        c.dispose();
      }
      containers.clear();
    });

    test('steps come from the sensor, not from the distance', () async {
      final g = launch()..startSession();
      await pumpEventQueue();
      source
        ..push(20000)
        ..push(20200);
      expect(g.steps, 200);
      expect(g.stepsKnown, isTrue);
      g.walkedM = 1000; // distance no longer drives the step count
      expect(g.steps, 200);
      g.endSession();
      await pumpEventQueue();
      expect(g.steps, 200, reason: 'the summary shows the session total');
      expect(SessionStore(store).loadLast()?.stepState?['steps'], 200);
    });

    test('not allowed → steps unknown ("–"), distance still counts', () async {
      perms.allowed = false;
      final g = launch()..startSession();
      await pumpEventQueue();
      expect(g.stepsKnown, isFalse);
    });

    test('demo mode keeps the simulated steps (no sensor read)', () async {
      final g = launch()..setMode(AppMode.demo);
      g.startSession();
      await pumpEventQueue();
      expect(source.listens, 0);
      g.walkedM = 720;
      expect(g.steps, 1000);
      expect(g.stepsKnown, isTrue);
    });

    test('PB06: after the app is killed, steps continue from the stored count',
        () async {
      final g = launch()..startSession();
      await pumpEventQueue();
      source
        ..push(5000)
        ..push(5300);
      clock.advance(const Duration(seconds: 20)); // past the 15 s save throttle
      source.push(5310);
      await pumpEventQueue();
      expect(g.steps, 310);

      // relaunch: new controller and tracker, same storage
      final source2 = FakeStepSource();
      final again =
          launch(tracker: StepTracker(source: source2, permissions: perms));
      await pumpEventQueue();
      expect(again.sessionActive, isTrue);
      expect(again.steps, 310);
      source2.push(5400); // 90 more, some taken while the app was closed
      expect(again.steps, 400);
    });
  });
}
