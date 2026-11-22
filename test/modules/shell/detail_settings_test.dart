import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/shell/src/data/device_permissions.dart';
import 'package:jelajah_taman/modules/shell/src/state/guide_controller.dart';
import 'package:jelajah_taman/modules/shell/src/ui/overlays.dart';
import 'package:jelajah_taman/modules/shell/src/ui/poi_detail_screen.dart';
import 'package:jelajah_taman/modules/shell/src/ui/settings_screen.dart';

import '../../helpers/test_content.dart';

/// Content with key facts on P05 only (the real content has none until the survey).
ContentRepository _contentWithFacts() {
  Map<String, Object?> read(String name) =>
      jsonDecode(File('assets/content/$name').readAsStringSync())
          as Map<String, Object?>;
  final pois = read('pois.json');
  for (final p in pois['pois']! as List<Object?>) {
    final m = p! as Map<String, Object?>;
    if (m['id'] == 'P05') {
      m['key_facts'] = ['Fakta uji pertama.', 'Fakta uji kedua.'];
    }
  }
  return ContentRepository.fromJson(
    pois: pois,
    facilities: read('facilities.json'),
    routes: read('routes.json'),
    park: read('park.json'),
    graph: read('trail_graph.json'),
  );
}

class _FakePermissions implements DevicePermissions {
  PermissionState notify = PermissionState.denied;
  PermissionState act = PermissionState.granted;
  final calls = <String>[];

  @override
  Future<PermissionState> notifications() async => notify;
  @override
  Future<PermissionState> requestNotifications() async {
    calls.add('requestNotifications');
    return notify = PermissionState.granted;
  }

  @override
  Future<PermissionState> activity() async => act;
  @override
  Future<PermissionState> requestActivity() async {
    calls.add('requestActivity');
    return act;
  }

  @override
  Future<void> openAppSettings() async => calls.add('openAppSettings');
}

void main() {
  late ProviderContainer c;

  Future<GuideController> pump(WidgetTester tester, String location,
      {ContentRepository? content, DevicePermissions? perms}) async {
    tester.view.physicalSize = const Size(390, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    c = ProviderContainer(overrides: [
      ...buildOverrides(
          content: content ?? loadTestContent(),
          basemap: loadTestBasemap(),
          clock: FakeClock(DateTime(2026, 11, 22, 10))),
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      if (perms != null) devicePermissionsProvider.overrideWithValue(perms),
    ]);
    addTearDown(c.dispose);
    final g = c.read(guideProvider)
      ..setMode(AppMode.demo)
      ..onboarded = true;
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: location,
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const Scaffold()),
        GoRoute(
            path: '/poi/:id',
            builder: (_, s) => PoiDetailScreen(id: s.pathParameters['id']!)),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(path: '/navigate', builder: (_, __) => const Text('navigate')),
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
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
    return g;
  }

  testWidgets('POI detail lists the key facts, numbered (F03)', (tester) async {
    await pump(tester, '/poi/P05', content: _contentWithFacts());
    await tester.scrollUntilVisible(find.text('Fakta kunci'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('2 fakta'), findsOneWidget);
    expect(
        find.bySemanticsLabel('Fakta 1: Fakta uji pertama.'), findsOneWidget);
    expect(find.bySemanticsLabel('Fakta 2: Fakta uji kedua.'), findsOneWidget);
  });

  testWidgets('no key facts in the content: no empty section', (tester) async {
    await pump(tester, '/poi/P06', content: _contentWithFacts());
    await tester.scrollUntilVisible(find.text('Sekilas'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Fakta kunci'), findsNothing);
  });

  testWidgets(
      'hydration card: nearest rest point, "Ingatkan 10 menit lagi" snoozes (#33)',
      (tester) async {
    final g = await pump(tester, '/home');
    g
      ..update(() => g.hydrationMin = 30)
      ..startSession();
    g.setDemoTime(10, 31);
    g.heartbeat();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // slides in
    }
    expect(find.text('TEMPAT ISTIRAHAT TERDEKAT'), findsOneWidget);
    expect(find.text(g.nearestRest.name), findsOneWidget);
    await tester.tap(find.text('Ingatkan 10 menit lagi'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(g.reminder, isNull);
    g.setDemoTime(10, 40);
    g.heartbeat();
    expect(g.reminder, isNull, reason: 'not before 10 minutes');
    g.setDemoTime(10, 42);
    g.heartbeat();
    expect(g.reminder, GuideReminder.hydration);
  });

  testWidgets('Settings → Izin ponsel: allow notifications again (PB07)',
      (tester) async {
    final perms = _FakePermissions();
    await pump(tester, '/settings', perms: perms);
    expect(find.text('Izin ponsel'.toUpperCase()), findsOneWidget);
    expect(find.text('Nonaktif'), findsOneWidget);
    expect(find.textContaining('Pemberitahuan di layar kunci tidak muncul'),
        findsOneWidget);
    await tester.tap(find.text('Izinkan'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(perms.calls, ['requestNotifications']);
    expect(find.text('Nonaktif'), findsNothing);
    expect(find.text('Izinkan'), findsNothing);
  });

  testWidgets('refused for good: the button opens the phone settings',
      (tester) async {
    final perms = _FakePermissions()..notify = PermissionState.blocked;
    await pump(tester, '/settings', perms: perms);
    await tester.tap(find.text('Buka pengaturan ponsel'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(perms.calls, ['openAppSettings']);
  });
}
