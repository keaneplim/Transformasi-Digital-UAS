import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/location/location.dart';
import 'package:jelajah_taman/modules/map/map.dart';

import '../../helpers/test_content.dart';

void main() {
  final content = loadTestContent();

  Future<void> pumpMap(WidgetTester tester, ExploreMap map) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentRepositoryProvider.overrideWithValue(content)],
        child: MaterialApp(home: Scaffold(body: map)),
      ),
    );
    await tester.pump();
  }

  LocationFix fixAt(GeoPoint p) =>
      LocationFix(position: p, accuracyM: 8, at: DateTime(2026, 11, 9, 13));

  testWidgets('every POI and facility has a marker', (tester) async {
    await pumpMap(tester, const ExploreMap());
    for (final p in content.pois) {
      expect(find.byKey(ValueKey('poi-${p.id}')), findsOneWidget, reason: p.id);
    }
    for (final f in content.facilities) {
      expect(find.byKey(ValueKey('facility-${f.id}')), findsOneWidget,
          reason: f.id);
    }
  });

  testWidgets('tapping a POI marker reports that POI', (tester) async {
    Poi? tapped;
    await pumpMap(tester, ExploreMap(onPoiTap: (p) => tapped = p));
    // Pick the most isolated POI: at the zone-wide zoom, close markers overlap (see PROGRESS).
    double nearestOther(Poi p) => [
          for (final q in content.pois)
            if (q.id != p.id) haversineM(p.position, q.position),
          for (final f in content.facilities)
            haversineM(p.position, f.position),
        ].reduce((a, b) => a < b ? a : b);
    final target = content.pois
        .reduce((a, b) => nearestOther(a) >= nearestOther(b) ? a : b);
    await tester.tap(find.byKey(ValueKey('poi-${target.id}')));
    expect(tapped?.id, target.id);
  });

  testWidgets('no "outside the zone" chip when the user is inside',
      (tester) async {
    await pumpMap(tester, ExploreMap(userFix: fixAt(content.gate.position)));
    expect(find.text('Anda di luar zona Dago Pakar'), findsNothing);
    expect(find.bySemanticsLabel('Posisi Anda'), findsOneWidget);
  });

  testWidgets('"outside the zone" chip when the user is far away',
      (tester) async {
    await pumpMap(
      tester,
      ExploreMap(
          userFix:
              fixAt(const GeoPoint(-6.9175, 107.6191))), // Bandung city centre
    );
    expect(find.text('Anda di luar zona Dago Pakar'), findsOneWidget);
  });

  testWidgets('weak GPS fix is announced as weak', (tester) async {
    await pumpMap(
      tester,
      ExploreMap(
        userFix: LocationFix(
          position: content.gate.position,
          accuracyM: 45,
          at: DateTime(2026, 11, 9, 13),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Posisi Anda, GPS lemah'), findsOneWidget);
  });

  testWidgets('visited POI is announced as visited', (tester) async {
    final p = content.pois.first;
    await pumpMap(tester, ExploreMap(visitedPoiIds: {p.id}));
    expect(
        find.bySemanticsLabel('${p.name}, sudah dikunjungi'), findsOneWidget);
  });
}
