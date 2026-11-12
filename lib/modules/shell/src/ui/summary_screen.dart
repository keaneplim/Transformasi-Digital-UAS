import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../demo/demo_controller.dart';
import '../demo/places.dart';
import 'park_map.dart';
import 'widgets.dart';

/// UI14 Session summary: counters roll up, the walked line draws on a mini map,
/// visited vs. not yet visited. Ending keeps nothing on a server (NG05).
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final pad = MediaQuery.paddingOf(context);
    final pois = demo.routePois;
    final visitedPois =
        demo.pois.where((p) => demo.visited.contains(p.id)).toList();
    final missed = pois.where((p) => !demo.visited.contains(p.id)).toList();
    final minutes = demo.sessionDuration.inMinutes;

    void finish() {
      demo.endSession();
      context.go('/home');
    }

    return Scaffold(
      backgroundColor: JT.cream,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SunHeader(
              height: 300 + pad.top,
              seed: 21,
              child: Padding(
                padding: EdgeInsets.fromLTRB(JT.gutter, pad.top + 8, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Kembali',
                          onTap: () => context.pop(),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('RINGKASAN JELAJAH', style: JTText.overline),
                              const SizedBox(height: 8),
                              HighlightHeadline(
                                before: 'Jelajah yang ',
                                highlight: 'seru!',
                                style: JTText.hero,
                                color: JT.forest,
                              ),
                            ],
                          ),
                        ),
                        const Pako(pose: PakoPose.cheer, size: 112),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
            sliver: SliverList.list(
              children: [
                Entrance(
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.45,
                    padding: EdgeInsets.zero,
                    children: [
                      _Stat(
                        icon: Icons.directions_walk_rounded,
                        color: JT.forest,
                        value: demo.steps.toDouble(),
                        format: (v) => thousands(v.round()),
                        label: 'langkah',
                      ),
                      _Stat(
                        icon: Icons.route_rounded,
                        color: JT.sky,
                        value: demo.walkedM,
                        format: (v) => '${km(v)} km',
                        label: 'jarak tempuh',
                      ),
                      _Stat(
                        icon: Icons.timer_rounded,
                        color: JT.category('sejarah'),
                        value: minutes.toDouble(),
                        format: (v) =>
                            minutesLabel(Duration(minutes: v.round())),
                        label: 'durasi',
                      ),
                      _Stat(
                        icon: Icons.local_fire_department_rounded,
                        color: JT.terracotta,
                        value: demo.kcal,
                        format: (v) => '${v.round()} kkal',
                        label: demo.weightKg == null
                            ? 'perkiraan energi'
                            : 'energi',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Entrance(
                  delay: JTMotion.stagger * 2,
                  child: JTCard(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(JT.rCard),
                      child: SizedBox(
                        height: 220,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ParkMap(
                                  interactive: false,
                                  showFacilities: false,
                                  showLabels: false,
                                  trailOverride: demo.trail,
                                  initialZoom: 15.6,
                                  fitPadding: const EdgeInsets.all(28),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              top: 12,
                              child: Pill(
                                icon: Icons.gesture_rounded,
                                label: 'Jalur yang Anda lalui',
                                background: JT.surface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text('Sudah dikunjungi · ${visitedPois.length}',
                    style: JTText.h2),
                const SizedBox(height: 10),
                if (visitedPois.isEmpty)
                  Text('Belum ada tempat yang dikunjungi.',
                      style: JTText.body.copyWith(color: JT.muted))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in visitedPois)
                        Pill(
                          icon: Icons.check_circle_rounded,
                          label: p.name,
                          color: p.tint,
                          background: p.tintSoft,
                        ),
                    ],
                  ),
                if (missed.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text('Untuk kunjungan berikutnya', style: JTText.h2),
                  const SizedBox(height: 10),
                  for (final p in missed) ...[
                    PlaceTile(
                      place: p,
                      heroSuffix: '-summary',
                      onTap: () => context.push('/poi/${p.id}?hero=-summary'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 18),
                JTCard(
                  color: JT.mint,
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: JT.forest),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ringkasan ini hanya tersimpan di ponsel Anda.',
                          style: JTText.bodySm.copyWith(color: JT.forest),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryPill(
                  label: demo.sessionActive
                      ? 'Akhiri jelajah'
                      : 'Kembali ke beranda',
                  icon: demo.sessionActive
                      ? Icons.flag_rounded
                      : Icons.home_rounded,
                  onTap: finish,
                ),
                SizedBox(height: 20 + pad.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.format,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final double value;
  final String Function(double) format;
  final String label;

  @override
  Widget build(BuildContext context) => JTCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, color: color, size: 36),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedCount(
                  value: value, format: format, style: JTText.number(24)),
            ),
            Text(label, style: JTText.caption),
          ],
        ),
      );
}
