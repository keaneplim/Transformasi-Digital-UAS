// Visual baselines of every screen (390×844 phone, mock data, fixed clock).
//
// Not part of CI on purpose: golden pixels differ per OS/font rasteriser. Regenerate with
//   flutter test test_goldens --update-goldens
// and inspect test_goldens/baselines/*.png. Run without the flag to diff against them.
// The harness drives the app from outside the widget tree.
// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/shell/src/demo/demo_controller.dart';
import 'package:jelajah_taman/modules/shell/src/ui/main_shell.dart';
import 'package:jelajah_taman/modules/shell/src/ui/overlays.dart';

import '../test/helpers/test_content.dart';

const _phone = Size(390, 844);
const _small = Size(360, 780);
const _dpr = 2.0;

Future<void> _loadFonts() async {
  Future<ByteData> file(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  final material = '$flutterRoot/bin/cache/artifacts/material_fonts';
  await (FontLoader('Bricolage')
        ..addFont(file('assets/fonts/BricolageGrotesque.ttf')))
      .load();
  await (FontLoader('Jakarta')
        ..addFont(file('assets/fonts/PlusJakartaSans.ttf')))
      .load();
  await (FontLoader('MaterialIcons')
        ..addFont(file('$material/MaterialIcons-Regular.otf')))
      .load();
  await (FontLoader('Roboto')..addFont(file('$material/Roboto-Regular.ttf')))
      .load();
}

class _Harness {
  _Harness(this.tester, this.container);

  final WidgetTester tester;
  final ProviderContainer container;

  DemoController get demo => container.read(demoProvider);
  BuildContext get nav => rootNavigatorKey.currentContext!;
  GoRouter get router => GoRouter.of(nav);

  Future<void> frames([int ms = 1400]) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> go(String path, {List<String> push = const []}) async {
    router.go(path);
    await frames(700);
    for (final p in push) {
      unawaited(router.push(p));
      await frames(700);
    }
    await frames();
  }

  Future<void> onboarded() async {
    demo.chooseRoute('santai');
    demo.finishOnboarding();
  }
}

Future<void> _precache(WidgetTester tester) async {
  final dir = Directory('assets/images');
  final ctx = rootNavigatorKey.currentContext!;
  await tester.runAsync(() async {
    for (final f in dir.listSync().whereType<File>()) {
      await precacheImage(
          AssetImage('assets/images/${f.uri.pathSegments.last}'), ctx);
    }
  });
}

void _shot(String name, Future<void> Function(_Harness h) setup,
    {bool splash = false, Size size = _phone}) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = size * _dpr;
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: buildOverrides(
        content: loadTestContent(),
        clock: FakeClock(DateTime(2026, 11, 14, 10, 30)),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
          container: container, child: const JelajahTamanApp()),
    );
    final h = _Harness(tester, container);
    if (splash) {
      await h.frames(1700);
    } else {
      await h.frames(3200); // splash → /welcome
      await _precache(tester);
      await setup(h);
    }
    await expectLater(
      find.byType(JelajahTamanApp),
      matchesGoldenFile('baselines/$name.png'),
    );
    // Stop anything that ticks so no timer outlives the test.
    h.demo
      ..pauseAudio()
      ..stopWalking();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}

/// Pako blinks on a random timer, so allow a tiny pixel difference.
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  static const _tolerance = 0.005;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
        imageBytes, await getGoldenBytes(golden));
    if (result.passed || result.diffPercent <= _tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

void main() {
  final local = goldenFileComparator as LocalFileComparator;
  goldenFileComparator =
      _TolerantComparator(local.basedir.resolve('screens_golden_test.dart'));
  setUpAll(_loadFonts);

  _shot('01_splash', (_) async {}, splash: true);
  _shot('02_onboarding_1', (h) async => h.frames());
  _shot('03_onboarding_izin', (h) async {
    await h.tester.tap(find.text('Lewati'));
    await h.frames(1600);
  });
  _shot('04_setup_minat', (h) async => h.go('/setup'));
  _shot('05_setup_rute', (h) async {
    await h.go('/setup');
    await h.tester.tap(find.text('Lanjut'));
    await h.frames(1600);
  });
  _shot('06_home', (h) async {
    await h.onboarded();
    await h.go('/home');
  });
  _shot('07_home_sesi_aktif', (h) async {
    await h.onboarded();
    final d = h.demo..startSession();
    for (final id in ['P02', 'P03']) {
      d.markVisited(d.place(id)!);
    }
    d.update(() => d.walkedM = 860);
    await h.go('/home');
  });
  _shot('08_peta', (h) async {
    await h.onboarded();
    await h.go('/home');
    h.container.read(tabProvider.notifier).state = 1;
    await h.frames(2200);
  });
  _shot('09_peta_preview', (h) async {
    await h.onboarded();
    await h.go('/home');
    h.container.read(tabProvider.notifier).state = 1;
    await h.frames(600);
    h.container.read(mapFocusProvider.notifier).state = 'P05';
    await h.frames(2200);
  });
  _shot('10_cari', (h) async {
    await h.onboarded();
    await h.go('/home');
    h.container.read(tabProvider.notifier).state = 2;
    await h.frames();
  });
  _shot('11_cari_kosong', (h) async {
    await h.onboarded();
    await h.go('/home');
    h.container.read(tabProvider.notifier).state = 2;
    await h.frames(600);
    await h.tester.enterText(find.byType(TextField), 'kolam renang');
    await h.frames();
  });
  _shot('12_detail_foto', (h) async {
    await h.onboarded();
    await h.go('/home', push: ['/poi/P06']);
  });
  _shot('13_detail_ilustrasi', (h) async {
    await h.onboarded();
    await h.go('/home', push: ['/poi/P02']);
  });
  _shot('14_mode_dengar', (h) async {
    await h.onboarded();
    h.demo
      ..playAudio(h.demo.place('P06')!)
      ..seekAudio(0.34);
    await h.go('/home', push: ['/play/P06']);
  });
  _shot('15_mendekati', (h) async {
    await h.onboarded();
    await h.go('/home');
    final d = h.demo..startSession();
    d.update(() => d.approaching = (place: d.place('P04')!, distanceM: 42));
    await h.frames();
  });
  _shot('16_kartu_trigger', (h) async {
    await h.onboarded();
    await h.go('/home');
    final d = h.demo..startSession();
    d.triggerNow(d.place('P05')!);
    await h.frames();
  });
  _shot('17_rekomendasi', (h) async {
    await h.onboarded();
    await h.go('/home');
    h.demo
      ..startSession()
      ..markVisited(h.demo.place('P02')!);
    unawaited(showRecommendations(h.nav));
    await h.frames();
  });
  _shot('18_rekomendasi_pulang', (h) async {
    await h.onboarded();
    h.demo
      ..setDemoTime(15, 40)
      ..startSession();
    await h.go('/home');
    unawaited(showRecommendations(h.nav));
    await h.frames();
  });
  _shot('19_navigasi', (h) async {
    await h.onboarded();
    await h.go('/home');
    h.demo.startNavigation(h.demo.place('P06')!);
    await h.go('/home', push: ['/navigate']);
  });
  _shot('20_tiba', (h) async {
    await h.onboarded();
    final d = h.demo..startSession();
    d.update(() {
      d.walkedM = 1240;
      d.arrivedAt = d.place('P06');
    });
    await h.go('/home', push: ['/arrived']);
  });
  _shot('21_pindai_qr', (h) async {
    await h.onboarded();
    await h.go('/home', push: ['/scan']);
  });
  _shot('22_pengingat_tutup', (h) async {
    await h.onboarded();
    h.demo
      ..setDemoTime(15, 20)
      ..teleportTo(h.demo.place('P06')!);
    await h.go('/home');
    h.demo.showReminder(DemoReminder.closing);
    await h.frames();
  });
  _shot('23_pengingat_minum', (h) async {
    await h.onboarded();
    await h.go('/home');
    h.demo.showReminder(DemoReminder.hydration);
    await h.frames();
  });
  _shot('24_ringkasan', (h) async {
    await h.onboarded();
    final d = h.demo..startSession();
    final r = d.router.route(d.position, d.place('P06')!.node)!;
    d.update(() {
      d.trail
        ..clear()
        ..addAll(r.polyline);
      d.walkedM = r.distanceM;
      d.visited.addAll(['P02', 'P03', 'P06']);
      d.sessionStart = d.now().subtract(const Duration(minutes: 52));
    });
    await h.go('/home', push: ['/summary']);
  });
  _shot('25_pengaturan', (h) async {
    await h.onboarded();
    await h.go('/home', push: ['/settings']);
  });
  _shot('26_pengaturan_demo', (h) async {
    await h.onboarded();
    await h.go('/home', push: ['/settings']);
    await h.tester.scrollUntilVisible(find.text('Mode demo'), 300);
    await h.tester.tap(find.text('Mode demo'));
    await h.frames();
    await h.tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await h.frames(800);
  });

  // Narrow phone (360×780): catches overflow on the densest screens.
  _shot('s360_home_sesi', (h) async {
    await h.onboarded();
    h.demo.startSession();
    await h.go('/home');
  }, size: _small);
  _shot('s360_setup_rute', (h) async {
    await h.go('/setup');
    await h.tester.tap(find.text('Lanjut'));
    await h.frames(1600);
  }, size: _small);
  _shot('s360_detail', (h) async {
    await h.onboarded();
    await h.go('/home', push: ['/poi/P05']);
  }, size: _small);
  _shot('s360_navigasi', (h) async {
    await h.onboarded();
    await h.go('/home');
    h.demo.startNavigation(h.demo.place('P07')!);
    await h.go('/home', push: ['/navigate']);
  }, size: _small);
  _shot('s360_tiba', (h) async {
    await h.onboarded();
    h.demo.update(() => h.demo.arrivedAt = h.demo.place('P07'));
    await h.go('/home', push: ['/arrived']);
  }, size: _small);
  _shot('s360_mode_dengar', (h) async {
    await h.onboarded();
    await h.go('/home', push: ['/play/P07']);
  }, size: _small);
  _shot('s360_pindai_qr', (h) async {
    await h.onboarded();
    await h.go('/home', push: ['/scan']);
  }, size: _small);
}
