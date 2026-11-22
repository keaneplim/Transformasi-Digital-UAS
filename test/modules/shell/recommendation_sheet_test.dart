import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/shell/src/state/guide_controller.dart';
import 'package:jelajah_taman/modules/shell/src/state/places.dart';
import 'package:jelajah_taman/modules/shell/src/ui/map_tab.dart';
import 'package:jelajah_taman/modules/shell/src/ui/overlays.dart';

import '../../helpers/test_content.dart';

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

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

/// UI08 through the real overlay host (F07 UC-F07-1/2/5, AC5), in demo mode.
void main() {
  setUpAll(_loadFonts);
  late ProviderContainer c;

  Future<GuideController> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1000) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    c = ProviderContainer(overrides: [
      ...buildOverrides(
          content: loadTestContent(),
          basemap: loadTestBasemap(),
          clock: FakeClock(DateTime(2026, 11, 20, 10, 30))),
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    ]);
    addTearDown(c.dispose);
    final g = c.read(guideProvider)
      ..setMode(AppMode.demo)
      ..onboarded = true;
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/home',
      routes: [
        GoRoute(
            path: '/home', builder: (_, __) => const Scaffold(body: MapTab())),
        GoRoute(path: '/navigate', builder: (_, __) => const Text('navigate')),
        GoRoute(path: '/summary', builder: (_, __) => const Text('summary')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) =>
            DemoOverlayHost(router: router, child: child!),
      ),
    ));
    await _frames(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
    return g;
  }

  /// "Saya di sini" at [id] → trigger card → "Lihat" (visited).
  void visit(GuideController g, String id) {
    g
      ..triggerNow(g.place(id)!)
      ..resolveTrigger(engaged: true);
  }

  testWidgets(
      'closing a visited POI opens UI08 by itself; one tap navigates (AC5)',
      (tester) async {
    final g = await open(tester);
    g.startSession();
    visit(g, 'P06');
    await _frames(tester);
    expect(find.text('Navigasi ke sini'), findsNothing);

    g.detailClosed(g.place('P06')!);
    await _frames(tester);
    expect(find.text('Navigasi ke sini'), findsOneWidget);
    expect(find.text('Terdekat'), findsWidgets);
    final main = g.recommend().items.first.place;
    await tester.tap(find.text('Navigasi ke sini'));
    await _frames(tester);
    expect(find.text('navigate'), findsOneWidget);
    expect(g.navigation?.to.id, main.id);
    g.endSession();
  });

  testWidgets(
      'a new trigger replaces a waiting suggestion (the trigger card wins)',
      (tester) async {
    final g = await open(tester);
    g.startSession();
    visit(g, 'P06');
    g.detailClosed(g.place('P06')!);
    g.triggerNow(g.place('P05')!); // a new place first
    await _frames(tester);
    expect(find.text('Navigasi ke sini'), findsNothing,
        reason: 'the trigger card wins, and replaces the old suggestion');
    g.resolveTrigger(engaged: false);
    await _frames(tester);
    expect(find.text('Navigasi ke sini'), findsNothing);
    g.endSession();
  });

  testWidgets(
      'UC-F07-2: at 15.30 the sheet says go back, with the walk and Navigasi ke gerbang',
      (tester) async {
    final g = await open(tester);
    g.startSession();
    visit(g, 'P06');
    g.setDemoTime(15, 30);
    g.detailClosed(g.place('P06')!);
    await _frames(tester);
    expect(find.text('Navigasi ke gerbang'), findsOneWidget);
    expect(find.text(gateWalkLabel(g.walkToGate)), findsOneWidget);
    await tester.tap(find.text('Navigasi ke gerbang'));
    await _frames(tester);
    expect(g.navigation?.to.id, g.content.gate.id);
    g.endSession();
  });

  testWidgets('UC-F07-5: "Ke mana selanjutnya?" on the map during a session',
      (tester) async {
    final g = await open(tester);
    expect(find.byTooltip('Ke mana selanjutnya?'), findsNothing);
    g.startSession();
    await _frames(tester);
    await tester.tap(find.byTooltip('Ke mana selanjutnya?'));
    await _frames(tester);
    expect(find.text('Navigasi ke sini'), findsOneWidget);
    g.endSession();
  });
}
