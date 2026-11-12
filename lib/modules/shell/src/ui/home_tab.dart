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
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
            height: 272,
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

/// Route pass shown before a session, styled as a trail ticket: a sun-tinted stub with
/// faint doodles, the route medallion, name and an honest finish-time check; a perforated
/// tear line with side notches; then the stats and the start button. Light and warm, so it
/// reads differently from the dark "Sedang menjelajah" card.
class _StartCard extends ConsumerWidget {
  const _StartCard();

  static const _stubHeight = 132.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final r = demo.route;
    final atGate = demo.walkingM(demo.place('P01')!) < 40;
    final finish = demo.now().add(Duration(minutes: r.durationMin));
    final fits =
        finish.isBefore(demo.closingTime.subtract(const Duration(minutes: 15)));
    final diffColor = switch (r.difficulty) {
      1 => JT.leaf,
      2 => JT.doodle,
      _ => JT.terracotta,
    };
    final stubColor = Color.lerp(JT.sun, JT.surface, 0.72)!;
    Widget notch(bool left) => Positioned(
          left: left ? -11 : null,
          right: left ? null : -11,
          top: _stubHeight - 11,
          child: Container(
            width: 22,
            height: 22,
            decoration:
                const BoxDecoration(color: JT.cream, shape: BoxShape.circle),
          ),
        );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: JT.surface,
            borderRadius: BorderRadius.circular(JT.rCard),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Backgrounds: sun-tinted stub over a white body.
              Positioned.fill(
                child: Column(
                  children: [
                    SizedBox(
                        height: _stubHeight,
                        width: double.infinity,
                        child: ColoredBox(color: stubColor)),
                    const Expanded(
                        child: SizedBox(
                            width: double.infinity,
                            child: ColoredBox(color: JT.surface))),
                  ],
                ),
              ),
              // One doodle layer across stub and body, fading out towards the left.
              Positioned.fill(
                child: IgnorePointer(
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [Colors.white, Colors.transparent],
                      stops: [0.0, 0.6],
                    ).createShader(rect),
                    child: const DoodlePattern(
                        color: JT.doodle,
                        seed: 13,
                        cell: 50,
                        iconSize: 24,
                        opacity: 0.28),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stub.
                  SizedBox(
                    height: _stubHeight,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Pill(
                                    label: atGate
                                        ? 'Anda di gerbang'
                                        : 'Rute pilihan Anda',
                                    dot: atGate,
                                    icon: atGate ? null : Icons.route_rounded,
                                    color: JT.forest,
                                    background: Colors.white,
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () => context.go('/setup'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: JT.forest,
                                      minimumSize: const Size(48, 40),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                    ),
                                    icon: const Icon(Icons.swap_horiz_rounded,
                                        size: 18),
                                    label: Text('Ganti',
                                        style: JTText.label
                                            .copyWith(color: JT.forest)),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('Rute ${r.name}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: JTText.h1),
                                  ),
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Pill(
                                      label: difficultyLabel(r.difficulty),
                                      icon: Icons.terrain_rounded,
                                      color: diffColor,
                                      background: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(
                                      fits
                                          ? Icons.check_circle_rounded
                                          : Icons.schedule_rounded,
                                      size: 16,
                                      color: fits
                                          ? JT.forestBright
                                          : JT.terracotta),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      fits
                                          ? 'Selesai ±${clockLabel(finish)}, sebelum tutup'
                                          : 'Tidak cukup waktu sebelum tutup ${clockLabel(demo.closingTime)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: JTText.bodySm.copyWith(
                                          color: fits
                                              ? JT.ink.withValues(alpha: 0.7)
                                              : JT.terracotta),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tear line.
                  const SizedBox(
                    height: 1,
                    width: double.infinity,
                    child: CustomPaint(painter: _TearLinePainter()),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            children: [
                              _Stat(
                                  icon: Icons.straighten_rounded,
                                  value: '${km(r.distanceM)} km',
                                  label: 'JARAK'),
                              const VerticalDivider(
                                  width: 1, thickness: 1, color: JT.line),
                              _Stat(
                                  icon: Icons.schedule_rounded,
                                  value: minutesLabel(
                                      Duration(minutes: r.durationMin)),
                                  label: 'DURASI'),
                              const VerticalDivider(
                                  width: 1, thickness: 1, color: JT.line),
                              _Stat(
                                  icon: Icons.place_rounded,
                                  value: '${demo.routePois.length}',
                                  label: 'TEMPAT'),
                            ],
                          ),
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
                  ),
                ],
              ),
            ],
          ),
        ),
        notch(true),
        notch(false),
      ],
    );
  }
}

class _TearLinePainter extends CustomPainter {
  const _TearLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = JT.line;
    for (var x = 18.0; x < size.width - 18; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), p);
    }
  }

  @override
  bool shouldRepaint(_TearLinePainter old) => false;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: JT.forestBright),
                    const SizedBox(width: 5),
                    Text(value, maxLines: 1, style: JTText.number(17)),
                  ],
                ),
              ),
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

/// Opening hours as the sun's path: a dashed arc from opening to closing time with the
/// sun at "now", the walked part of the day drawn solid (A03 context).
class _TimeLeft extends ConsumerWidget {
  const _TimeLeft();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final total = demo.closingTime.difference(demo.openingTime).inMinutes;
    final left = math.max(0, demo.timeToClose.inMinutes);
    final elapsed = total == 0 ? 1.0 : (1 - left / total).clamp(0.0, 1.0);
    final warn = left < 60;
    final accent = left == 0
        ? JT.muted
        : warn
            ? JT.terracotta
            : JT.doodle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        decoration: BoxDecoration(
          color: JT.surface,
          borderRadius: BorderRadius.circular(JT.rCard),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              height: 44,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: elapsed),
                duration: const Duration(milliseconds: 1100),
                curve: JTMotion.emphasized,
                builder: (context, v, _) => CustomPaint(
                    painter: _SunArcPainter(progress: v, color: accent)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      if (left == 0)
                        const TextSpan(text: 'Kawasan sudah tutup')
                      else ...[
                        const TextSpan(text: 'Sisa '),
                        TextSpan(
                          text: minutesLabel(Duration(minutes: left)),
                          style: JTText.number(16,
                              color: warn ? JT.terracotta : JT.ink),
                        ),
                        const TextSpan(text: ' sebelum tutup'),
                      ],
                    ]),
                    style: JTText.label
                        .copyWith(color: warn ? JT.terracotta : JT.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Buka ${clockLabel(demo.openingTime)} · Tutup ${clockLabel(demo.closingTime)}',
                    style: JTText.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SunArcPainter extends CustomPainter {
  _SunArcPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width / 2 - 6, size.height - 8);
    final c = Offset(size.width / 2, size.height - 3);
    final rect = Rect.fromCircle(center: c, radius: r);

    // Horizon.
    canvas.drawLine(
        Offset(0, c.dy),
        Offset(size.width, c.dy),
        Paint()
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..color = JT.line);

    // Dashed path of the whole day.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = JT.line;
    const dashes = 14;
    for (var i = 0; i < dashes; i++) {
      final a = math.pi + i * math.pi / dashes;
      canvas.drawArc(rect, a, math.pi / dashes * 0.55, false, track);
    }

    // Elapsed part, solid.
    canvas.drawArc(
        rect,
        math.pi,
        math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.55));

    // The sun, with short rays.
    final a = math.pi + math.pi * progress;
    final sun = c + Offset(math.cos(a), math.sin(a)) * r;
    final ray = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (var i = 0; i < 8; i++) {
      final ra = i * math.pi / 4;
      final d = Offset(math.cos(ra), math.sin(ra));
      canvas.drawLine(sun + d * 8.5, sun + d * 11, ray);
    }
    canvas.drawCircle(sun, 7, Paint()..color = JT.surface);
    canvas.drawCircle(sun, 5.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SunArcPainter old) =>
      old.progress != progress || old.color != color;
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

/// Door to search: a mint card with drifting doodles and Pako peeking in from the corner.
class _ExploreAll extends StatelessWidget {
  const _ExploreAll({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.98,
        semanticLabel: 'Cari tempat lain',
        child: Container(
          height: 108,
          decoration: BoxDecoration(
            color: JT.mint,
            borderRadius: BorderRadius.circular(JT.rCard),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DoodlePattern(
                    color: JT.mintDeep, seed: 9, cell: 52, iconSize: 24),
              ),
              const Positioned(
                left: 6,
                bottom: -22,
                child: Pako(pose: PakoPose.curious, size: 104, shadow: false),
              ),
              Positioned.fill(
                left: 118,
                right: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cari tempat lain', style: JTText.h3),
                          const SizedBox(height: 3),
                          Text('Gua, toilet, saung…',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: JTText.bodySm.copyWith(
                                  color: JT.ink.withValues(alpha: 0.65))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: JT.forest, shape: BoxShape.circle),
                      child: const Icon(Icons.search_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
