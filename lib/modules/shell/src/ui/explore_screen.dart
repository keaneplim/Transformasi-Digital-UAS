import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/core/theme/app_theme.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/location/location.dart';
import 'package:jelajah_taman/modules/map/map.dart';
import 'package:jelajah_taman/modules/routing/routing.dart';

/// Explore screen (UI03), first slice (T04): the map + a tap preview card.
///
/// TODO(B, T21): feed the real LocationService fix, session stats strip (C), approaching banner (A).
/// Until A's LocationService exists, debug builds can long-press the map to place a simulated
/// position, so markers, rings, distances and the "di luar zona" chip can be checked at a desk.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  LocationFix? _simulatedFix;
  Object? _selected; // Poi or Facility

  void _simulateAt(GeoPoint p) {
    if (!kDebugMode) return;
    setState(() => _simulatedFix = LocationFix(
          position: p,
          accuracyM: 8,
          at: ref.read(clockProvider).now(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentRepositoryProvider);
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Jelajah'),
        actions: [
          if (kDebugMode && _simulatedFix != null)
            IconButton(
              tooltip: 'Hapus posisi simulasi',
              icon: const Icon(Icons.location_off_outlined),
              onPressed: () => setState(() => _simulatedFix = null),
            ),
        ],
      ),
      body: Column(
        children: [
          if (content.isDummy)
            Container(
              width: double.infinity,
              color: AppColors.sunlitAmber.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                kDebugMode
                    ? 'DATA DUMMY · tekan lama peta untuk simulasi posisi'
                    : 'DATA DUMMY — bukan koordinat survei',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: ExploreMap(
              userFix: _simulatedFix,
              selectedId: switch (selected) {
                Poi(:final id) || Facility(:final id) => id,
                _ => null,
              },
              onPoiTap: (p) => setState(() => _selected = p),
              onFacilityTap: (f) => setState(() => _selected = f),
              onMapTap: () => setState(() => _selected = null),
              onMapLongPress: _simulateAt,
            ),
          ),
          if (selected != null)
            _PreviewCard(
              target: selected,
              from: _simulatedFix?.position,
              onClose: () => setState(() => _selected = null),
            ),
        ],
      ),
    );
  }
}

/// UC-A01-1 marker preview: name, walking distance + ETA, Detail / Navigasi.
class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({
    required this.target,
    required this.from,
    required this.onClose,
  });

  final Object target; // Poi or Facility
  final GeoPoint? from;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentRepositoryProvider);
    final router = ref.watch(trailRouterProvider);
    final (name, subtitle, node) = switch (target) {
      Poi p => (p.name, _categoryLabel(p.category), p.graphNode),
      Facility f => (f.name, 'Fasilitas', f.graphNode),
      _ => throw ArgumentError.value(target, 'target'),
    };
    final origin = from ?? content.gate.position;
    final metres = router.walkingDistanceM(origin, node);
    final minutes = router.walkingTime(origin, node).inMinutes;
    final text = Theme.of(context).textTheme;

    return Material(
      color: AppColors.pureSurface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(name, style: text.titleMedium)),
                  IconButton(
                    tooltip: 'Tutup',
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
              Text(
                '$subtitle · ${metres.round()} m · ±$minutes mnt'
                '${from == null ? ' dari gerbang' : ''}',
                style: text.bodyMedium?.copyWith(color: AppColors.mossGray),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    // TODO(C, T06): open POI Detail. TODO(B, T19): start navigation.
                    Expanded(
                        child: OutlinedButton(
                            onPressed: null, child: Text('Detail'))),
                    SizedBox(width: 12),
                    Expanded(
                        child: FilledButton(
                            onPressed: null, child: Text('Navigasi'))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _categoryLabel(String c) => switch (c) {
        'sejarah' => 'Sejarah',
        'alam' => 'Alam',
        'rekreasi' => 'Rekreasi',
        _ => 'Informasi',
      };
}
