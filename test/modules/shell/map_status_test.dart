import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:jelajah_taman/modules/location/location.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/shell/src/state/guide_controller.dart';
import 'package:jelajah_taman/modules/shell/src/ui/map_tab.dart';

import '../../helpers/test_content.dart';

/// GPS stand-in: permission is set by the test, fixes are pushed by hand.
class _Gps implements LocationService {
  _Gps(this.granted);
  LocationAccess granted;
  final _fixes = StreamController<LocationFix>.broadcast(sync: true);

  @override
  Stream<LocationFix> get fixes => _fixes.stream;
  @override
  Stream<GpsQuality> get quality => const Stream.empty();
  @override
  Stream<double> get headings => const Stream.empty();
  @override
  LocationFix? get last => null;
  @override
  GpsQuality get currentQuality => GpsQuality.none;
  @override
  bool get isRunning => true;
  @override
  Duration get currentInterval => const Duration(seconds: 3);
  @override
  Future<void> setInterval(Duration interval) async {}
  @override
  Future<LocationAccess> access() async => granted;
  @override
  Future<LocationAccess> requestAccess() async => granted;
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> start() async {}
  @override
  Future<void> startSession() async {}
  @override
  Future<void> stopSession() async {}
  @override
  Future<void> stop() async {}
}

Future<void> _frames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The map is laid out for the app's own fonts (the test font is far wider).
Future<void> _loadFonts() async {
  Future<ByteData> file(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());
  await (FontLoader('Bricolage')
        ..addFont(file('assets/fonts/BricolageGrotesque.ttf')))
      .load();
  await (FontLoader('Jakarta')
        ..addFont(file('assets/fonts/PlusJakartaSans.ttf')))
      .load();
}

void main() {
  setUpAll(_loadFonts);
  late FakeClock clock;
  late ProviderContainer c;

  Future<void> open(WidgetTester tester, LocationAccess access) async {
    tester.view.physicalSize = const Size(390, 1000) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    clock = FakeClock(DateTime(2026, 11, 20, 10, 30));
    c = ProviderContainer(overrides: [
      ...buildOverrides(
          content: loadTestContent(), basemap: loadTestBasemap(), clock: clock),
      locationServiceProvider.overrideWithValue(_Gps(access)),
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    ]);
    addTearDown(c.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: MapTab())),
        GoRoute(path: '/scan', builder: (_, __) => const Text('scanner')),
        GoRoute(
            path: '/poi/:id',
            builder: (_, s) => Text('detail ${s.pathParameters['id']}')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ));
    await _frames(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  }

  GuideController guide() => c.read(guideProvider);

  testWidgets(
      'F01 AC4: location denied → card with Pilih manual; the pick opens the detail',
      (tester) async {
    await open(tester, LocationAccess.denied);
    expect(find.text('Lokasi belum diizinkan'), findsOneWidget);
    expect(find.text('Izinkan lokasi'), findsOneWidget);
    await tester.tap(find.text('Pilih manual'));
    await _frames(tester);
    expect(find.text('Anda sedang di mana?'), findsOneWidget);
    // no position: A–Z, so the first row is the alphabetically first POI
    final first = guide().manualPickList.first;
    await tester.tap(find
        .descendant(
            of: find.byType(BottomSheet), matching: find.text(first.name))
        .first);
    await _frames(tester, 10);
    expect(find.text('detail ${first.id}'), findsOneWidget);
    expect(guide().visitLog.map((e) => (e.poiId, e.how)),
        [(first.id, 'manual'), (first.id, 'opened')]);
    guide().endSession(); // stops the 5 s heartbeat
  });

  testWidgets(
      'D08: granted but no fix → "Mencari posisi", then after 60 s the QR / manual card',
      (tester) async {
    await open(tester, LocationAccess.granted);
    expect(find.text('Mencari posisi Anda…'), findsOneWidget);
    guide().startSession();
    guide().heartbeat();
    clock.advance(const Duration(seconds: 60));
    guide().heartbeat();
    await _frames(tester);
    expect(find.text('GPS lemah, posisi kurang akurat'), findsOneWidget);
    await tester.tap(find.text('Pindai QR'));
    await _frames(tester);
    expect(find.text('scanner'), findsOneWidget);
    guide().endSession();
  });

  testWidgets('T31 debug overlay shows GPS interval & POI states on Explore',
      (tester) async {
    await open(tester, LocationAccess.granted);
    expect(find.textContaining('3 dtk (bergerak)'), findsNothing);
    guide().setDebugOverlay(true);
    await _frames(tester);
    expect(find.textContaining('3 dtk (bergerak)'), findsOneWidget);
    expect(find.textContaining('db 0'), findsWidgets);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await _frames(tester);
    expect(guide().debugOverlay, isFalse);
    expect(find.textContaining('3 dtk (bergerak)'), findsNothing);
  });
}
