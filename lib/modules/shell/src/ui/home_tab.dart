import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../demo/demo_controller.dart';
import '../demo/places.dart';
import 'main_shell.dart';
import 'widgets.dart';

/// UI02 Home: greeting on the sun band, the session card, highlights on the chosen route,
/// nearest facilities (toilet, musala, saung).
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final top = MediaQuery.paddingOf(context).top;
    final highlights = demo.routePois;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SunHeader(
            height: 318 + top,
            seed: 11,
            child: Padding(
              padding: EdgeInsets.fromLTRB(JT.gutter, top + 10, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.forest_rounded, size: 20, color: JT.ink),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Tahura Djuanda · Dago Pakar',
                            style: JTText.label),
                      ),
                      CircleIconButton(
                        icon: Icons.tune_rounded,
                        tooltip: 'Pengaturan',
                        onTap: () => context.push('/settings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Entrance(
                          child: HighlightHeadline(
                            before: '${greeting(demo.now())},\nsiap ',
                            highlight: 'menjelajah?',
                            style: JTText.display,
                            color: JT.forest,
                          ),
                        ),
                      ),
                      const Entrance(
                        delay: Duration(milliseconds: 180),
                        scaleFrom: 0.6,
                        child: Pako(pose: PakoPose.wave, size: 112),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Pill(
                        label: demo.isOpen
                            ? 'Buka · tutup ${clockLabel(demo.closingTime)}'
                            : 'Tutup · buka ${clockLabel(demo.openingTime)}',
                        dot: true,
                        color: demo.isOpen ? JT.forest : JT.terracotta,
                        background: Colors.white.withValues(alpha: 0.9),
                      ),
                      Pill(
                        label: 'Peta siap tanpa sinyal',
                        icon: Icons.cloud_done_rounded,
                        color: JT.forest,
                        background: Colors.white.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(JT.gutter, 0, JT.gutter, 0),
          sliver: SliverToBoxAdapter(
            child: Entrance(
              delay: const Duration(milliseconds: 120),
              child: demo.sessionActive
                  ? const _ActiveSession()
                  : const _StartCard(),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
        const SliverToBoxAdapter(child: _TimeLeft()),
        const SliverToBoxAdapter(child: SizedBox(height: 26)),
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Di rute ${demo.route.name}',
            action: 'Lihat peta',
            onAction: () => ref.read(tabProvider.notifier).state = 1,
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 268,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
              itemCount: highlights.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) => Entrance(
                delay: JTMotion.stagger * (i + 3),
                offset: const Offset(30, 0),
                child: PlaceCard(
                  place: highlights[i],
                  heroSuffix: '-home',
                  onTap: () =>
                      context.push('/poi/${highlights[i].id}?hero=-home'),
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 26)),
        const SliverToBoxAdapter(
            child: SectionHeader(title: 'Fasilitas terdekat')),
        const SliverToBoxAdapter(child: _Facilities()),
        const SliverToBoxAdapter(child: SizedBox(height: 26)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
            child: _ExploreAll(
                onTap: () => ref.read(tabProvider.notifier).state = 2),
          ),
        ),
        SliverToBoxAdapter(
            child:
                SizedBox(height: 120 + MediaQuery.paddingOf(context).bottom)),
      ],
    );
  }
}

class _StartCard extends ConsumerWidget {
  const _StartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final r = demo.route;
    final atGate = demo.walkingM(demo.place('P01')!) < 40;
    return JTCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                  icon: atGate
                      ? Icons.door_front_door_rounded
                      : Icons.route_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        atGate
                            ? 'Anda di Gerbang Dago Pakar'
                            : 'Rute pilihan Anda',
                        style: JTText.caption),
                    const SizedBox(height: 2),
                    Text('Rute ${r.name}', style: JTText.h2),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.go('/setup'),
                style: TextButton.styleFrom(
                    foregroundColor: JT.forest,
                    minimumSize: const Size(48, 44)),
                child: Text('Ganti',
                    style: JTText.label.copyWith(color: JT.forest)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(value: '${km(r.distanceM)} km', label: 'JARAK'),
              _Stat(
                  value: minutesLabel(Duration(minutes: r.durationMin)),
                  label: 'DURASI'),
              _Stat(value: '${demo.routePois.length}', label: 'TEMPAT'),
              _Stat(value: difficultyLabel(r.difficulty), label: 'TINGKAT'),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryPill(
            label: 'Mulai Jelajah',
            icon: Icons.explore_rounded,
            onTap: () {
              demo.startSession();
              ref.read(tabProvider.notifier).state = 1;
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, maxLines: 1, style: JTText.number(17))),
              const SizedBox(height: 4),
              Text(label, style: JTText.overline),
            ],
          ),
        ),
      );
}

class _ActiveSession extends ConsumerWidget {
  const _ActiveSession();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        decoration: BoxDecoration(
          color: JT.forest,
          borderRadius: BorderRadius.circular(JT.rCard),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(
              child:
                  DoodlePattern(color: JT.forestBright, seed: 4, opacity: 0.5),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const PulseRings(
                        color: JT.sun,
                        size: 22,
                        child: CircleAvatar(radius: 4, backgroundColor: JT.sun),
                      ),
                      const SizedBox(width: 6),
                      Text('Sedang menjelajah',
                          style: JTText.label.copyWith(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const StatStrip(dark: true),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SoftButton(
                          label: 'Buka peta',
                          icon: Icons.map_rounded,
                          color: JT.sun,
                          onTap: () => ref.read(tabProvider.notifier).state = 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SoftButton(
                          label: 'Akhiri',
                          icon: Icons.flag_rounded,
                          color: Colors.white.withValues(alpha: 0.14),
                          foreground: Colors.white,
                          onTap: () => context.push('/summary'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Time left before closing as a draining bar (A03 context).
class _TimeLeft extends ConsumerWidget {
  const _TimeLeft();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final total = demo.closingTime.difference(demo.openingTime).inMinutes;
    final left = math.max(0, demo.timeToClose.inMinutes);
    final frac = total == 0 ? 0.0 : (left / total).clamp(0.0, 1.0);
    final warn = left < 60;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
      child: Row(
        children: [
          Icon(Icons.wb_twilight_rounded,
              size: 22, color: warn ? JT.terracotta : JT.doodle),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  left == 0
                      ? 'Kawasan sudah tutup'
                      : 'Sisa ${minutesLabel(Duration(minutes: left))} sebelum tutup',
                  style: JTText.label
                      .copyWith(color: warn ? JT.terracotta : JT.ink),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: frac),
                    duration: JTMotion.lazy,
                    curve: JTMotion.emphasized,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      color: warn ? JT.terracotta : JT.sun,
                      backgroundColor: JT.line,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Facilities extends ConsumerWidget {
  const _Facilities();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    Place? nearestOf(String type) {
      final list = demo.facilities.where((f) => f.kind == type).toList()
        ..sort((a, b) => demo.walkingM(a).compareTo(demo.walkingM(b)));
      return list.isEmpty ? null : list.first;
    }

    final items = [
      for (final t in ['toilet', 'musala', 'istirahat'])
        if (nearestOf(t) case final f?) f,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
      child: Column(
        children: [
          for (final (i, f) in items.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Entrance(
                delay: JTMotion.stagger * (i + 4),
                child: PlaceTile(
                  place: f,
                  heroSuffix: '-fac',
                  onTap: () => openOnMap(ref, f.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExploreAll extends StatelessWidget {
  const _ExploreAll({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => JTCard(
        onTap: onTap,
        color: JT.mint,
        child: Row(
          children: [
            const Pako(pose: PakoPose.curious, size: 64, shadow: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cari tempat lain', style: JTText.h3),
                  const SizedBox(height: 2),
                  Text('Gua, toilet, musala, saung…',
                      style: JTText.bodySm.copyWith(color: JT.muted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: JT.forest),
          ],
        ),
      );
}
