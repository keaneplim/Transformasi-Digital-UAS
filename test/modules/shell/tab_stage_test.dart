import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/shell/src/ui/main_shell.dart';
import 'package:jelajah_taman/modules/shell/src/ui/tab_stage.dart';

import '../../helpers/test_content.dart';

// The UI has looping ambient motion, so these pump fixed frames and never settle.
Future<void> _ms(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 20) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// The pages are laid out for the app's own fonts (the test font is far wider).
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

const _home = BandGeometry(shift: 0, bottom: 318, edge: 64);
const _search = BandGeometry(shift: 0, bottom: 184, edge: 56);

TabStage _stage(WidgetTester tester) {
  final stage = TabStage(vsync: tester)
    ..attach(TabStage.home, () => _home)
    ..attach(TabStage.search, () => _search);
  addTearDown(stage.dispose);
  return stage;
}

Future<ProviderContainer> _pumpShell(WidgetTester tester,
    {bool reduced = false}) async {
  tester.view.physicalSize = const Size(390, 844) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    ...buildOverrides(
      content: loadTestContent(),
      basemap: loadTestBasemap(),
      clock: FakeClock(DateTime(2026, 11, 14, 10, 30)),
    ),
    keyValueStoreProvider
        .overrideWithValue(MemoryKeyValueStore({'app_mode': 'demo'})),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: const MainShell(),
    ),
  ));
  await _ms(tester, 800);
  // Unmount before the test ends so nothing that ticks outlives it.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
  return container;
}

void main() {
  group('TabStage', () {
    testWidgets('content leaves, the canopy travels, content arrives',
        (tester) async {
      final stage = _stage(tester);
      final home = stage.presence[TabStage.home];
      final search = stage.presence[TabStage.search];

      stage.go(TabStage.search);
      await _ms(tester, 100);
      // act 1: Home is still the page, its content on the way out, its own band in place
      expect(stage.shown, TabStage.home);
      expect(home.exit, inExclusiveRange(0, 1));
      expect(stage.bare.value, isFalse);
      expect(stage.blocking, isTrue);

      await _ms(tester, 100);
      // act 2: the stage has the band, starting exactly where Home had it
      expect(stage.shown, TabStage.search);
      expect(stage.bare.value, isTrue);
      expect(search.enter, 0);
      expect(stage.geometry!.bottom, inExclusiveRange(184, 318.0001));

      await _ms(tester, 240);
      // act 3 overlaps the end of act 2: the header is arriving, the canopy nearly home
      expect(stage.bare.value, isTrue);
      expect(search.enter, inExclusiveRange(0, TabStage.settled));
      expect(stage.geometry!.bottom, closeTo(184, 6));

      await _ms(tester, 100);
      // landed: the page draws its own band again and can be touched
      expect(stage.bare.value, isFalse);
      expect(stage.blocking, isFalse);
      expect(search.enter, greaterThanOrEqualTo(TabStage.settled));

      await _ms(tester, 300);
      expect(search.enter, 1);
      expect(search.exit, 0);
    });

    testWidgets('the map has no band: the canopy lifts off and the body clears',
        (tester) async {
      final stage = _stage(tester);
      stage.go(TabStage.map);
      await _ms(tester, 260);
      expect(stage.shown, TabStage.map);
      final g = stage.geometry!;
      expect(g.body, inExclusiveRange(0, 1));
      expect(g.bottom, lessThan(318));
      await _ms(tester, 600);
      expect(stage.geometry, isNull);
      expect(stage.cover, 0);

      // and back: the map stays underneath until the body has covered it
      stage.go(TabStage.home);
      await _ms(tester, 300);
      expect(stage.shown, TabStage.home);
      expect(stage.mapVisible, isTrue);
      await _ms(tester, 600);
      expect(stage.mapVisible, isFalse);
    });

    testWidgets('a redirect carries on from where the canopy is',
        (tester) async {
      final stage = _stage(tester);
      stage.go(TabStage.search);
      await _ms(tester, 300);
      final mid = stage.geometry!;
      expect(mid.bottom, inExclusiveRange(184, 318));

      stage.go(TabStage.map);
      expect(stage.geometry!.bottom, mid.bottom);
      await _ms(tester, 100);
      // Search clears out first; the canopy waits where it was
      expect(stage.shown, TabStage.search);
      expect(stage.geometry!.bottom, mid.bottom);
      await _ms(tester, 800);
      expect(stage.shown, TabStage.map);
      expect(stage.bare.value, isFalse);
      expect(stage.presence[TabStage.map].enter, 1);
    });

    testWidgets('turning back before the page has left just restores it',
        (tester) async {
      final stage = _stage(tester);
      final home = stage.presence[TabStage.home];
      stage.go(TabStage.search);
      await _ms(tester, 80);
      expect(home.exit, greaterThan(0));

      stage.go(TabStage.home);
      await _ms(tester, 800);
      expect(stage.shown, TabStage.home);
      expect(stage.bare.value, isFalse);
      expect(home.enter, 1);
      expect(home.exit, 0);
    });

    testWidgets('turning back to the map lets the canopy finish lifting off',
        (tester) async {
      final stage = _stage(tester);
      stage.go(TabStage.map);
      await _ms(tester, 240); // the map is on, the canopy still above it
      stage.go(TabStage.home);
      await _ms(tester, 60); // the map's controls are clearing out
      stage.go(TabStage.map);
      expect(stage.shown, TabStage.map);
      final before = stage.geometry!.bottom;
      await _ms(tester, 200);
      expect(stage.geometry!.bottom, lessThan(before));
      await _ms(tester, 700);
      expect(stage.geometry, isNull);
      expect(stage.presence[TabStage.map].enter, 1);
      expect(stage.presence[TabStage.map].exit, 0);
    });

    testWidgets('reduced motion switches at once', (tester) async {
      final stage = _stage(tester);
      var arrived = false;
      stage.go(TabStage.search, reduced: true);
      stage.afterArrival(() => arrived = true);
      expect(stage.shown, TabStage.search);
      expect(stage.bare.value, isFalse);
      expect(stage.blocking, isFalse);
      expect(arrived, isTrue);
    });

    testWidgets('afterArrival waits for the canopy to land', (tester) async {
      final stage = _stage(tester);
      var arrived = false;
      stage.go(TabStage.search);
      stage.afterArrival(() => arrived = true);
      await _ms(tester, 400);
      expect(arrived, isFalse);
      await _ms(tester, 200);
      expect(arrived, isTrue);
      await _ms(tester, 300);
    });
  });

  group('MainShell', () {
    setUpAll(_loadFonts);

    testWidgets('switching tabs swaps the page once the old one has cleared',
        (tester) async {
      final container = await _pumpShell(tester);
      expect(find.text('Mulai Jelajah').hitTestable(), findsOneWidget);

      container.read(tabProvider.notifier).state = TabStage.search;
      await _ms(tester, 100);
      expect(find.text('Mulai Jelajah'), findsOneWidget);
      expect(find.text('Cepat temukan'), findsNothing);
      await _ms(tester, 900);
      expect(find.text('Mulai Jelajah'), findsNothing);
      expect(find.text('Cepat temukan').hitTestable(), findsOneWidget);

      container.read(tabProvider.notifier).state = TabStage.home;
      await _ms(tester, 900);
      expect(find.text('Mulai Jelajah').hitTestable(), findsOneWidget);
      expect(find.text('Cepat temukan'), findsNothing);
    });

    testWidgets('the map search bar opens Search folded and ready to type',
        (tester) async {
      final container = await _pumpShell(tester);
      container.read(tabProvider.notifier).state = TabStage.map;
      await _ms(tester, 900);

      await tester.tap(find.text('Cari tempat atau fasilitas'));
      await _ms(tester, 300);
      final field = tester.widget<TextField>(find.byType(TextField));
      // not while the canopy is still on its way
      expect(field.focusNode!.hasFocus, isFalse);
      await _ms(tester, 700);
      expect(container.read(tabProvider), TabStage.search);
      expect(field.focusNode!.hasFocus, isTrue);
      // the band is folded: the headline has faded out
      final headline = tester.widget<Opacity>(find
          .ancestor(
              of: find.textContaining('Mau ke', findRichText: true),
              matching: find.byType(Opacity))
          .last);
      expect(headline.opacity, 0);
    });

    testWidgets('typing makes Pako react', (tester) async {
      final container = await _pumpShell(tester);
      container.read(tabProvider.notifier).state = TabStage.search;
      await _ms(tester, 900);
      int beat() => tester.widget<Pako>(find.byType(Pako).first).reaction;
      final before = beat();
      await tester.enterText(find.byType(TextField), 'g');
      await _ms(tester, 100);
      expect(beat(), before + 1);
      expect(tester.widget<Pako>(find.byType(Pako).first).pose, PakoPose.peek);
      await _ms(tester, 600);
    });

    testWidgets('reduced motion: the new page is simply there', (tester) async {
      final container = await _pumpShell(tester, reduced: true);
      container.read(tabProvider.notifier).state = TabStage.search;
      await tester.pump();
      await tester.pump();
      expect(find.text('Cepat temukan').hitTestable(), findsOneWidget);
      expect(find.text('Mulai Jelajah'), findsNothing);
    });
  });
}
