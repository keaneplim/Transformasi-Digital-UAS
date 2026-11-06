// Smoke test. Also keeps `flutter create .` from generating its default widget_test.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/modules/shell/shell.dart';

import 'helpers/test_content.dart';

void main() {
  testWidgets('app starts and Home shows content', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(content: loadTestContent()),
        child: const JelajahTamanApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jelajah Taman'), findsWidgets);
    expect(find.textContaining('Jam operasional'), findsOneWidget);
  });
}
