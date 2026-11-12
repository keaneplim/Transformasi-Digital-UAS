// Smoke test. Also keeps `flutter create .` from generating its default widget_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';

import 'helpers/test_content.dart';

void main() {
  testWidgets('splash leads to onboarding, skip leads to personalisation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(content: loadTestContent()),
        child: const JelajahTamanApp(),
      ),
    );
    // The UI has looping ambient motion (mascot, doodles), so pump fixed frames, never settle.
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump(const Duration(milliseconds: 900));
    expect(
        find.textContaining('lebih dekat', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Lewati'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 900));
    expect(
        find.textContaining('berangkat', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Nanti saja'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.textContaining('temukan?', findRichText: true), findsOneWidget);
  });
}
