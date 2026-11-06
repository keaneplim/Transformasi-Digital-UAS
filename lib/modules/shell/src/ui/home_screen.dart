import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/theme/app_theme.dart';
import 'package:jelajah_taman/modules/content/content.dart';

/// Skeleton Home: proves the content pipeline works end to end.
/// TODO(C): replace with UI02 (interests, route chooser, Mulai Jelajah) per DESIGN.md.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentRepositoryProvider);
    final park = content.park;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Jelajah Taman')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          if (content.isDummy) const _DummyBanner(),
          Text(
            'Jam operasional ${park.openLabel}–${park.closeLabel}'
            '${park.hoursVerified ? '' : ' (belum diverifikasi)'}',
            style: text.bodyLarge,
          ),
          const SizedBox(height: 24),
          Text('Objek (${content.pois.length})', style: text.titleMedium),
          for (final poi in content.pois)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(poi.name),
              subtitle: Text(
                '${poi.id} · ${poi.category} · radius ${poi.radiusM.round()} m'
                '${poi.hasQr ? ' · QR' : ''}',
              ),
            ),
          const SizedBox(height: 16),
          Text('Fasilitas (${content.facilities.length})',
              style: text.titleMedium),
          for (final facility in content.facilities)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(facility.name),
              subtitle: Text('${facility.id} · ${facility.type}'),
            ),
          const SizedBox(height: 16),
          Text('Rute (${content.routes.length})', style: text.titleMedium),
          for (final route in content.routes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(route.name),
              subtitle: Text(
                '${(route.distanceM / 1000).toStringAsFixed(1).replaceAll('.', ',')} km · '
                '±${route.durationMin} mnt · ${route.poiSequence.length} titik',
              ),
            ),
        ],
      ),
    );
  }
}

class _DummyBanner extends StatelessWidget {
  const _DummyBanner();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.sunlitAmber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'DATA DUMMY — koordinat, jarak, dan durasi belum dari survei. '
          'Jangan dipakai untuk uji lapangan.',
          style: TextStyle(color: AppColors.pineInk),
        ),
      );
}
