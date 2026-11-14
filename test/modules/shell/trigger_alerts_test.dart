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
}
