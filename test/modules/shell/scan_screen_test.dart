import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/shell/src/state/guide_controller.dart';
import 'package:jelajah_taman/modules/shell/src/ui/scan_screen.dart';
import 'package:jelajah_taman/modules/trigger/trigger.dart';

import '../../helpers/test_content.dart';

/// UI12 with a stand-in camera: the test plays the role of the plugin and "decodes" codes.
class _FakeCamera {
  ValueChanged<String>? send;
  bool? torch;
  QrCameraProblem? problem;

  Widget build({
    required ValueChanged<String> onCode,
    required bool torch,
    required Widget Function(QrCameraProblem) problemBuilder,
  }) {
    send = onCode;
    this.torch = torch;
    final p = problem;
    return p == null
        ? const ColoredBox(color: Colors.black)
        : problemBuilder(p);
  }
}

Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late _FakeCamera camera;
  late ProviderContainer c;

  Future<void> open(WidgetTester tester,
      {bool withCamera = true, String mode = 'real'}) async {
    // Taller than a phone: the test font is wider than the bundled fonts and would wrap
    // the list past the bottom (the 390×844 layout is checked by golden 21_pindai_qr).
    tester.view.physicalSize = const Size(390, 1000) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    c = ProviderContainer(overrides: [
      ...buildOverrides(
          content: loadTestContent(),
          clock: FakeClock(DateTime(2026, 11, 20, 10, 30))),
      keyValueStoreProvider
          .overrideWithValue(MemoryKeyValueStore({'app_mode': mode})),
      if (withCamera) qrCameraProvider.overrideWithValue(camera.build),
    ]);
    addTearDown(c.dispose);
    final router = GoRouter(
      initialLocation: '/scan',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('home')),
        GoRoute(path: '/scan', builder: (_, __) => const ScanScreen()),
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
      await tester.pump(const Duration(seconds: 5));
    });
  }

  GuideController guide() => c.read(guideProvider);

  setUp(() => camera = _FakeCamera());

  testWidgets('scanning the Gua Jepang board opens its detail as a QR visit',
      (tester) async {
    await open(tester);
    expect(find.text('KODE DI TAMAN'), findsNothing,
        reason: 'with a real camera the tap-to-scan list is a demo tool only');
    camera.send!('jelajahtaman://poi/P05');
    await _frames(tester, 10);
    expect(find.text('detail P05'), findsOneWidget);
    final g = guide();
    expect(g.sessionActive, isTrue);
    expect(g.visited, contains('P05'));
    expect(g.pendingTrigger, isNull,
        reason: 'no trigger card on top of the detail');
    expect(g.visitLog.map((e) => (e.kind.name, e.how)),
        [('triggered', 'qr'), ('visited', 'qr')]);
  });

  testWidgets('a foreign code shows a message and the scanner stays open',
      (tester) async {
    await open(tester);
    camera.send!('https://example.com');
    await _frames(tester);
    expect(
        find.text(
            'QR tidak dikenali. Pastikan Anda memindai papan Jelajah Taman.'),
        findsOneWidget);
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(guide().sessionActive, isFalse);

    camera.send!('jelajahtaman://poi/P99'); // unknown ID: same message
    await _frames(tester);
    expect(find.textContaining('QR tidak dikenali'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('QR tidak dikenali'), findsNothing,
        reason: 'the message clears itself');

    camera.send!(
        'jelajahtaman://poi/P06'); // and a real board still works afterwards
    await _frames(tester, 10);
    expect(find.text('detail P06'), findsOneWidget);
  });

  testWidgets('camera permission denied: explanation and the list way out',
      (tester) async {
    camera.problem = QrCameraProblem.permissionDenied;
    await open(tester);
    expect(find.textContaining('Kamera belum diizinkan'), findsOneWidget);
    expect(find.text('Pilih tempat dari daftar'), findsOneWidget);
  });

  testWidgets(
      'UC-A02-3: the list way out picks a place by hand and opens it as a manual visit',
      (tester) async {
    camera.problem = QrCameraProblem.permissionDenied;
    await open(tester);
    await tester.tap(find.text('Pilih tempat dari daftar'));
    await _frames(tester, 8);
    expect(find.text('Anda sedang di mana?'), findsOneWidget);
    final g = guide();
    final name = g.place('P06')!.name;
    final row = find.descendant(
        of: find.byType(BottomSheet), matching: find.text(name));
    await tester.scrollUntilVisible(row, 120,
        scrollable: find
            .descendant(
                of: find.byType(BottomSheet), matching: find.byType(Scrollable))
            .first);
    await tester.tap(row);
    await _frames(tester, 10);
    expect(find.text('detail P06'), findsOneWidget);
    expect(g.sessionActive, isTrue);
    expect(g.visitLog.map((e) => (e.kind.name, e.how)),
        [('triggered', 'manual'), ('visited', 'opened')]);
  });

  testWidgets('the torch button switches the camera torch', (tester) async {
    await open(tester);
    expect(camera.torch, isFalse);
    await tester.tap(find.byTooltip('Nyalakan senter'));
    await _frames(tester);
    expect(camera.torch, isTrue);
  });

  testWidgets('without a camera (preview) the list of codes scans by tap',
      (tester) async {
    await open(tester, withCamera: false);
    expect(find.text('KODE DI TAMAN'), findsOneWidget);
    await tester.tap(find.text('Gua Belanda'));
    await _frames(tester, 10);
    expect(find.text('detail P06'), findsOneWidget);
    expect(guide().visited, contains('P06'));
  });
}
