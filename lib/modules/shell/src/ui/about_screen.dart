import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../state/credits.dart';
import '../state/guide_controller.dart';

/// Tentang & atribusi: what the app is, and who made the map data, imagery and photos.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pad = MediaQuery.paddingOf(context);
    final demo = ref.watch(guideProvider);
    final credits = ref.watch(imageCreditsProvider).valueOrNull ?? const {};
    final names = {
      for (final p in demo.places)
        for (final img in p.images) img: p.name,
    };
    final photos = credits.values
        .where((c) => names.containsKey(c.file))
        .toList()
      ..sort((a, b) => a.file.compareTo(b.file));

    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(title.toUpperCase(), style: JTText.overline),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: JT.surface,
                    borderRadius: BorderRadius.circular(JT.rCard)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children),
              ),
            ],
          ),
        );
    Widget item(String title, String body) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: JTText.title),
              const SizedBox(height: 2),
              Text(body, style: JTText.caption),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: JT.cream,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            JT.gutter, pad.top + 8, JT.gutter, 28 + pad.bottom),
        children: [
          Row(children: [
            CircleIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Kembali',
                onTap: () => context.pop()),
          ]),
          const SizedBox(height: 14),
          Text('Tentang & atribusi', style: JTText.display),
          const SizedBox(height: 8),
          Text(
            'Jelajah Taman memandu kunjungan di Tahura Ir. H. Djuanda, zona Dago Pakar. '
            'Dibuat oleh Kelompok 5, mata kuliah Transformasi Digital, STI ITB 2026.',
            style: JTText.body.copyWith(color: JT.muted),
          ),
          const SizedBox(height: 22),
          section('Peta', [
            item('Data peta © OpenStreetMap contributors',
                'Jalan, jalur, sungai, bangunan, tutupan lahan, dan batas Tahura. Lisensi ODbL (openstreetmap.org/copyright).'),
            item('Relief dan garis kontur',
                'Diolah dari data elevasi Google Elevation API.'),
            item('Citra satelit © Esri',
                'Sumber: Esri, Maxar, Earthstar Geographics, dan komunitas pengguna GIS. Hanya saat lapisan Satelit dipilih dan ada internet.'),
          ]),
          section('Foto tempat', [
            if (photos.isEmpty)
              item('Dokumentasi tim Jelajah Taman',
                  'Survei lapangan 7 November 2026.'),
            for (final c in photos)
              item(
                names[c.file]!,
                [
                  c.isCommons
                      ? '${c.author} · ${c.license} · Wikimedia Commons'
                      : c.author,
                  if (c.edit.isNotEmpty && c.edit != 'Tanpa edit') c.edit,
                ].join('\n'),
              ),
          ]),
          section('Narasi', [
            item('Suara narasi',
                'Dibuat dengan teks-ke-suara Gemini dari naskah tim.'),
          ]),
        ],
      ),
    );
  }
}
