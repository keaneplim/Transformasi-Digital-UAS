import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/modules/notify/notify.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/shell/src/state/guide_controller.dart';
import 'package:jelajah_taman/modules/shell/src/state/places.dart';
import 'package:jelajah_taman/modules/shell/src/state/trigger_alerts.dart';
import 'package:jelajah_taman/modules/trigger/trigger.dart';

import '../../helpers/test_content.dart';

/// Records what would reach Android.
class FakeNotifier implements AlertNotifier {
  final calls = <String>[];
  final shown = <String, ({String title, String body})>{};
  final _taps = StreamController<AlertTap>.broadcast(sync: true);
  AlertTap? launchTap;

  void tap(String poi, AlertAction a) => _taps.add(AlertTap(poi, a));
  void tapReminder(ReminderKind k, String to, AlertAction a) =>
      _taps.add(AlertTap(to, a, reminder: k));

  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> showApproach(
      {required String poiId,
      required String title,
      required String body}) async {
    calls.add('approach:$poiId');
    shown['approach'] = (title: title, body: body);
  }

  @override
  Future<void> cancelApproach() async => calls.add('cancelApproach');
  @override
  Future<void> showTrigger(
      {required String poiId,
      required String title,
      required String body,
      required String listenLabel}) async {
    calls.add('trigger:$poiId');
    shown['trigger'] = (title: title, body: body);
  }

  @override
  Future<void> cancelTrigger() async => calls.add('cancelTrigger');
  @override
  Future<void> showNext(
      {required String poiId,
      required String title,
      required String body}) async {
    calls.add('next:$poiId');
    shown['next'] = (title: title, body: body);
  }

  @override
  Future<void> cancelNext() async => calls.add('cancelNext');

  final reminders = <({
    ReminderKind kind,
    String to,
    String title,
    String body,
    String navigateLabel,
    String laterLabel,
    bool snoozes
  })>[];

  @override
  Future<void> showReminder({
    required ReminderKind kind,
    required String destinationId,
    required String title,
    required String body,
    required String navigateLabel,
    required String laterLabel,
    required bool snoozes,
  }) async {
    calls.add('reminder:${kind.name}:$destinationId');
    reminders.add((
      kind: kind,
      to: destinationId,
      title: title,
      body: body,
      navigateLabel: navigateLabel,
      laterLabel: laterLabel,
      snoozes: snoozes
    ));
  }

  @override
  Future<void> cancelReminder() async => calls.add('cancelReminder');

  bool? vibrationOn;
  @override
  void setVibration(bool on) => vibrationOn = on;
  @override
  Future<void> vibrate(List<int> pattern) async =>
      calls.add('vibrate:${pattern.join(",")}');
  @override
  Stream<AlertTap> get taps => _taps.stream;
  @override
  AlertTap? takeLaunchTap() {
    final t = launchTap;
    launchTap = null;
    return t;
  }

  int count(String prefix) => calls.where((c) => c.startsWith(prefix)).length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeClock clock;
  late ProviderContainer c;
  late FakeNotifier n;
  late List<String> routes;
  late GuideController g;
  late TriggerAlerts alerts;

  TriggerAlerts start() => TriggerAlerts(
        guide: g,
        notifier: n,
        bus: c.read(eventBusProvider),
        navigate: routes.add,
      );

  setUp(() {
    clock = FakeClock(DateTime(2026, 11, 14, 10));
    c = ProviderContainer(overrides: [
      ...buildOverrides(
          content: loadTestContent(), clock: clock, basemap: loadTestBasemap()),
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    ]);
    n = FakeNotifier();
    routes = [];
    g = c.read(guideProvider)..setMode(AppMode.demo);
    alerts = start();
  });
  tearDown(() {
    alerts.dispose();
    c.dispose();
  });

  Place poi(String id) => g.place(id)!;

  /// Demo walk: two positions at the POI = two readings inside the radius → trigger.
  void arriveAt(String id) {
    clock.advance(const Duration(seconds: 31)); // clear of the D01 spacing
    g
      ..teleportTo(poi(id))
      ..teleportTo(poi(id));
  }

  test('app visible: the card + a vibration, no system notification', () {
    g.startSession();
    arriveAt('P05');
    expect(g.pendingTrigger?.id, 'P05');
    expect(n.calls, contains('vibrate:0,200,150,200'));
    expect(n.count('trigger:'), 0);
  });

  test('vibration off in Settings: no in-app vibration', () {
    g
      ..vibration = false
      ..startSession();
    arriveAt('P05');
    expect(n.count('vibrate'), 0);
  });

  test('screen locked: the trigger goes to the lock-screen notification', () {
    g.startSession();
    alerts.setVisible(false);
    arriveAt('P05');
    expect(n.calls, contains('trigger:P05'));
    expect(n.shown['trigger']!.title, 'Anda tiba di ${poi('P05').name}');
    expect(n.count('vibrate'), 0, reason: 'the notification channel vibrates');
  });

  test(
      'card still open when the phone is locked → posted once, not on every lock',
      () {
    g.startSession();
    arriveAt('P05');
    alerts.setVisible(false);
    alerts
      ..setVisible(true)
      ..setVisible(false);
    expect(n.count('trigger:P05'), 1);
  });

  test('answered in the app → the notification disappears', () {
    g.startSession();
    alerts.setVisible(false);
    arriveAt('P05');
    alerts.setVisible(true);
    g.resolveTrigger(engaged: false);
    expect(n.calls.last, 'cancelTrigger');
  });

  test(
      'Dengarkan on the lock screen: visited (listened) + narration, card gone',
      () {
    g.startSession();
    alerts.setVisible(false);
    arriveAt('P05');
    n.tap('P05', AlertAction.listen);
    expect(g.pendingTrigger, isNull);
    expect(g.visited, contains('P05'));
    expect(g.nowPlaying?.id, 'P05');
    expect(g.visitLog.last.how, 'listened');
    expect(routes, isEmpty, reason: 'without opening the app');
  });

  test('Lihat detail: visited (opened) and the detail page opens', () {
    g.startSession();
    alerts.setVisible(false);
    arriveAt('P05');
    n.tap('P05', AlertAction.detail);
    expect(g.visited, contains('P05'));
    expect(routes, ['/poi/P05']);
  });

  test('Nanti: triggered but not visited (D05); the next queued POI is posted',
      () {
    g.startSession();
    alerts.setVisible(false);
    arriveAt('P05');
    arriveAt('P06'); // triggers while P05's card is open → queued
    expect(n.count('trigger:'), 1);
    n.tap('P05', AlertAction.later);
    expect(g.visited, isNot(contains('P05')));
    expect(g.triggered, contains('P05'));
    expect(g.pendingTrigger?.id, 'P06');
    expect(n.calls.last, 'trigger:P06');
  });

  test('a stale tap (POI no longer pending) does not resolve the current card',
      () {
    g.startSession();
    alerts.setVisible(false);
    arriveAt('P05');
    n.tap('P06', AlertAction.later);
    expect(g.pendingTrigger?.id, 'P05');
    n.tap('FS01', AlertAction.listen); // a facility is never narrated
    expect(g.nowPlaying, isNull);
  });

  // "Once per approach" is the engine's rule (D03, tested in geofence_engine_test); here: what
  // an approach event turns into.
  void approach(String id, double metres) => c
      .read(eventBusProvider)
      .publish(PoiApproached(at: clock.now(), poiId: id, distanceM: metres));

  test(
      'approaching during a session → quiet notification with the banner wording',
      () async {
    g.startSession();
    approach('P05', 43);
    await pumpEventQueue();
    expect(n.calls, contains('approach:P05'));
    expect(n.shown['approach']!.title, 'Hampir sampai: ${poi('P05').name}');
    expect(n.shown['approach']!.body, 'Sekitar 45 m lagi.');
  });

  test('no approach alert while a trigger card is open; a trigger clears it',
      () async {
    g.startSession();
    approach('P05', 43);
    await pumpEventQueue();
    arriveAt('P05');
    expect(n.calls.sublist(n.calls.indexOf('approach:P05')),
        contains('cancelApproach'));
    approach('P06', 40);
    await pumpEventQueue();
    expect(n.count('approach:P06'), 0);
  });

  test('no session → no system notifications at all', () async {
    alerts.setVisible(false);
    arriveAt('P05');
    await pumpEventQueue();
    expect(n.count('trigger:'), 0);
    expect(n.count('approach:'), 0);
  });

  test('ending the session clears what is still on the lock screen', () {
    g.startSession();
    alerts.setVisible(false);
    arriveAt('P05');
    g.endSession();
    expect(n.calls, containsAll(['cancelTrigger', 'cancelApproach']));
  });

  test('a tap that cold-started the app is handled once the app is up',
      () async {
    alerts.dispose();
    g.startSession();
    n.launchTap = const AlertTap('P05', AlertAction.detail);
    alerts = start();
    await pumpEventQueue();
    expect(routes, ['/poi/P05']);
    expect(n.takeLaunchTap(), isNull, reason: 'taken once');
  });

  test('the engine state reflects Nanti (stays triggered for cooldown)', () {
    g.startSession();
    alerts.setVisible(false);
    arriveAt('P05');
    n.tap('P05', AlertAction.later);
    expect(g.stateOf(poi('P05')), PoiState.triggered);
  });

  group('F07 next suggestion with the screen off', () {
    void visitAndFinish(String id) {
      arriveAt(id);
      g
        ..resolveTrigger(engaged: true)
        ..detailClosed(poi(id));
    }

    test('screen off: one silent "Berikutnya" card; back on screen it goes',
        () {
      g.startSession();
      alerts.setVisible(false);
      visitAndFinish('P06');
      final main = g.lastRecommendation!.rec.items.first.place;
      expect(n.calls, contains('next:${main.id}'));
      expect(n.shown['next']!.title, 'Berikutnya: ${main.name}');
      g.detailClosed(poi('P06'));
      expect(n.count('next:'), 1, reason: 'once per visited POI');
      alerts.setVisible(true);
      expect(n.calls.last, 'cancelNext');
    });

    test('app visible: no notification (the sheet shows it)', () {
      g.startSession();
      visitAndFinish('P06');
      expect(g.recommendationCount, 1);
      expect(n.count('next:'), 0);
    });

    test('no time left: the card says go back to the gate', () {
      g
        ..startSession()
        ..setDemoTime(15, 30);
      alerts.setVisible(false);
      visitAndFinish('P06');
      expect(n.calls, contains('next:${g.content.gate.id}'));
      expect(n.shown['next']!.title, 'Waktunya kembali ke gerbang');
      expect(n.shown['next']!.body, '${gateWalkLabel(g.walkToGate)}.');
    });
  });

  group('reminders (A03, F08 d)', () {
    void closingDue() {
      // At the gate the walk back is ~0: due at 16.00 − 15 min.
      g
        ..update(() => g.hydrationMin = 0)
        ..startSession()
        ..setDemoTime(15, 50)
        ..heartbeat();
      expect(g.reminder, GuideReminder.closing);
    }

    void hydrationDue() {
      g
        ..update(() => g.hydrationMin = 30)
        ..startSession();
      clock.advance(const Duration(minutes: 31));
      g.heartbeat();
      expect(g.reminder, GuideReminder.hydration);
    }

    test('app visible: one buzz, no notification (the card is on screen)', () {
      closingDue();
      expect(n.calls,
          contains('vibrate:${TriggerAlerts.reminderVibration.join(",")}'));
      expect(n.count('reminder:'), 0);
    });

    test(
        'screen off: closing notification with the card\'s words + Navigasi / Nanti',
        () {
      alerts.setVisible(false);
      closingDue();
      final r = n.reminders.single;
      expect(r.kind, ReminderKind.closing);
      expect(r.to, 'P01');
      expect(r.title, 'Kawasan tutup pukul 16.00');
      expect(r.body, contains(minutesLabel(g.walkToGate)));
      expect((r.navigateLabel, r.laterLabel, r.snoozes),
          ('Navigasi ke gerbang', 'Nanti', false));
    });

    test('a card still open when the phone is locked is posted then', () {
      closingDue();
      expect(n.count('reminder:'), 0);
      alerts.setVisible(false);
      expect(n.count('reminder:closing:P01'), 1);
      alerts
        ..setVisible(true)
        ..setVisible(false);
      expect(n.count('reminder:'), 1, reason: 'posted once');
    });

    test('answered in the app → the notification goes', () {
      alerts.setVisible(false);
      closingDue();
      g.dismissReminder();
      expect(n.calls.last, 'cancelReminder');
    });

    test('hydration: nearest rest point + "Ingatkan 10 menit lagi" snoozes',
        () {
      alerts.setVisible(false);
      hydrationDue();
      final r = n.reminders.single;
      expect(r.kind, ReminderKind.hydration);
      expect(r.to, g.nearestRest.id);
      expect(r.title, 'Sudah 31 menit berjalan. Minum air dulu, yuk.');
      expect(r.body,
          startsWith('Tempat istirahat terdekat: ${g.nearestRest.name}'));
      expect(r.snoozes, isTrue);
      n.tapReminder(ReminderKind.hydration, r.to, AlertAction.snooze);
      expect(g.reminder, isNull);
      clock.advance(const Duration(minutes: 9));
      g.heartbeat();
      expect(g.reminder, isNull);
      clock.advance(const Duration(minutes: 1));
      g.heartbeat();
      expect(g.reminder, GuideReminder.hydration, reason: '10 min, not 30');
      expect(n.reminders.last.title,
          'Sudah 41 menit berjalan. Minum air dulu, yuk.');
    });

    test('Navigasi on the notification: handled, navigating, app opens there',
        () {
      alerts.setVisible(false);
      closingDue();
      n.tapReminder(ReminderKind.closing, 'P01', AlertAction.navigate);
      expect(g.reminder, isNull);
      expect(g.navigation?.to.id, 'P01');
      expect(routes, ['/navigate']);
    });

    test('Nanti on the notification dismisses; a body tap leaves the card', () {
      alerts.setVisible(false);
      closingDue();
      n.tapReminder(ReminderKind.closing, 'P01', AlertAction.show);
      expect(g.reminder, GuideReminder.closing);
      n.tapReminder(ReminderKind.closing, 'P01', AlertAction.later);
      expect(g.reminder, isNull);
      expect(routes, isEmpty);
    });

    test('session ended: the reminder notification goes', () {
      alerts.setVisible(false);
      closingDue();
      g.endSession();
      expect(n.calls, contains('cancelReminder'));
    });

    test('UC-A03-2 final call: urgent buzz visible, urgent notification locked',
        () {
      // Stand at P06 (> 200 m from gate) so final call is eligible.
      final p06 = poi('P06');
      g
        ..update(() => g.hydrationMin = 0)
        ..teleportTo(p06)
        ..startSession();
      final finalAt = g.finalCallAt;
      // Visible: closing fires first, then final call supersedes it with stronger buzz.
      clock.setNow(g.closingReminderAt);
      g.heartbeat();
      expect(g.reminder, GuideReminder.closing);
      clock.setNow(finalAt);
      g.heartbeat();
      expect(g.reminder, GuideReminder.finalCall);
      expect(n.calls,
          contains('vibrate:${TriggerAlerts.finalCallVibration.join(",")}'));

      // Lock screen: urgent finalCall notification is posted and Navigasi goes to P01.
      alerts.setVisible(false);
      final r = n.reminders.last;
      expect(r.kind, ReminderKind.finalCall);
      expect(r.to, 'P01');
      expect(r.title, 'Segera menuju gerbang sekarang');
      expect(r.snoozes, isFalse);
      n.tapReminder(ReminderKind.finalCall, 'P01', AlertAction.navigate);
      expect(g.reminder, isNull);
      expect(g.navigation?.to.id, 'P01');
      expect(routes, ['/navigate']);
    });
  });

  test('Settings "Getar" also switches the notification vibration (PB07)', () {
    expect(n.vibrationOn, isTrue);
    g.update(() => g.vibration = false);
    expect(n.vibrationOn, isFalse);
    g.startSession();
    arriveAt('P06');
    expect(n.count('vibrate:'), 0, reason: 'no in-app buzz either');
  });
}
