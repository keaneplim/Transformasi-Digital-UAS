import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';
import 'package:jelajah_taman/modules/shell/src/state/search.dart';
import 'package:jelajah_taman/modules/shell/src/ui/search_header.dart';
import 'package:jelajah_taman/modules/shell/src/ui/search_sections.dart';
import 'package:jelajah_taman/modules/shell/src/ui/search_tab.dart';

import '../../helpers/test_content.dart';

// The UI has looping ambient motion, so these pump fixed frames and never settle.
Future<void> _frames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<ProviderContainer> _pump(WidgetTester tester,
    {Map<String, String> stored = const {}}) async {
  tester.view.physicalSize = const Size(390, 844) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    ...buildOverrides(
      content: loadTestContent(),
      clock: FakeClock(DateTime(2026, 11, 14, 10, 30)),
    ),
    keyValueStoreProvider.overrideWithValue(
        MemoryKeyValueStore({'app_mode': 'demo', ...stored})),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: SearchTab()),
    ),
  ));
  await _frames(tester);
  // Unmount before the test ends so nothing that ticks outlives it.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
  return container;
}

Finder _rich(String text) => find.textContaining(text, findRichText: true);

void main() {
  testWidgets('browsing shows quick finds, a place to visit and every place',
      (tester) async {
    await _pump(tester);
    expect(_rich('Mau ke'), findsOneWidget);
    expect(find.text('Cepat temukan'), findsOneWidget);
    expect(find.text('Terdekat dari Anda'), findsOneWidget);
    expect(find.byType(SearchFeatureCard), findsOneWidget);
    expect(find.text('Terakhir dicari'), findsNothing);
  });

  testWidgets('typing ranks the best match first and counts per category',
      (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'gua');
    await _frames(tester);
    expect(_rich('5 hasil'), findsOneWidget);
    expect(find.text('Cepat temukan'), findsNothing);
    final card =
        tester.widget<SearchFeatureCard>(find.byType(SearchFeatureCard));
    expect(card.place.name, 'Gua Jepang');
    expect(find.bySemanticsLabel('Sejarah, 2 tempat'), findsOneWidget);
    expect(find.bySemanticsLabel('Semua, 5 tempat'), findsOneWidget);
  });

  testWidgets('focusing the field folds the sun band away', (tester) async {
    await _pump(tester);
    double headerHeight() =>
        tester.getSize(find.byType(SearchField)).height +
        tester.getTopLeft(find.byType(SearchField)).dy;
    final open = headerHeight();
    await tester.tap(find.byType(TextField));
    await _frames(tester);
    expect(headerHeight(), lessThan(open - 100));
  });

  testWidgets('a synonym explains itself and a typo is corrected',
      (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'wc');
    await _frames(tester);
    expect(_rich('Cocok dengan “wc”'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'pinsu');
    await _frames(tester);
    expect(find.byType(SearchCorrection), findsOneWidget);
    expect(_rich('untuk “pinus”'), findsWidgets);
  });

  testWidgets('nothing found offers suggestions, or the other categories',
      (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'kolam renang');
    await _frames(tester);
    expect(_rich('belum ketemu'), findsOneWidget);
    await tester.tap(find.text('rusa'));
    await _frames(tester);
    expect(_rich('hasil'), findsOneWidget);
    expect(find.text('Penangkaran Rusa'), findsOneWidget);

    // the same query inside a category that has no match
    await tester.tap(find.bySemanticsLabel(RegExp('^Sejarah, ')));
    await _frames(tester);
    expect(_rich('belum ketemu di Sejarah'), findsOneWidget);
    await tester.tap(find.text('Lihat di semua kategori'));
    await _frames(tester);
    expect(find.text('Penangkaran Rusa'), findsOneWidget);
  });

  testWidgets('the sort sheet reorders the list', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'gua');
    await _frames(tester);
    await tester.tap(find.text('Paling cocok'));
    await _frames(tester);
    expect(find.text('Urutkan'), findsOneWidget);
    await tester.tap(find.text('Nama A–Z').last);
    await _frames(tester);
    expect(find.text('Urutkan'), findsNothing);
    // no feature card outside best-match order: the list is a plain A–Z list
    expect(find.byType(SearchFeatureCard), findsNothing);
    expect(find.text('Nama A–Z'), findsOneWidget);
  });

  testWidgets('long-press opens the preview sheet', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'gua');
    await _frames(tester);
    await tester.longPress(_rich('Belanda').first);
    await _frames(tester);
    expect(find.text('Navigasi ke sini'), findsOneWidget);
    expect(find.text('Lihat di peta'), findsOneWidget);
  });

  testWidgets('submitted searches come back as recent chips', (tester) async {
    final container = await _pump(tester);
    await tester.enterText(find.byType(TextField), 'saung');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _frames(tester);
    expect(container.read(recentSearchesProvider).items, ['saung']);

    await tester.enterText(find.byType(TextField), '');
    await _frames(tester);
    expect(find.text('Terakhir dicari'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Cari lagi saung'));
    await _frames(tester);
    expect(_rich('untuk “saung”'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await _frames(tester);
    await tester.tap(find.text('Hapus semua'));
    await _frames(tester);
    expect(find.text('Terakhir dicari'), findsNothing);
  });

  testWidgets('recent searches are restored from storage', (tester) async {
    await _pump(tester, stored: {'recent_searches': '["gua","toilet"]'});
    expect(find.text('Terakhir dicari'), findsOneWidget);
    expect(find.bySemanticsLabel('Cari lagi gua'), findsOneWidget);
  });
}
