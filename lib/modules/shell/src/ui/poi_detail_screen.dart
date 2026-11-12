import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../demo/demo_controller.dart';
import '../demo/places.dart';
import 'overlays.dart';
import 'widgets.dart';

/// UI06 POI Detail: parallax photo gallery (Hero from the card you tapped), audio card,
/// safety callout, observations, quick facts, then "Selesai, lihat berikutnya" (F07).
class PoiDetailScreen extends ConsumerStatefulWidget {
  const PoiDetailScreen({super.key, required this.id, this.heroSuffix = ''});

  final String id;
  final String heroSuffix;

  @override
  ConsumerState<PoiDetailScreen> createState() => _PoiDetailScreenState();
}

class _PoiDetailScreenState extends ConsumerState<PoiDetailScreen> {
  final _scroll = ScrollController();
  final _gallery = PageController();
  double _offset = 0;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => setState(() => _offset = _scroll.offset));
    _gallery.addListener(() => setState(() => _page = _gallery.page ?? 0));
    // Opening the detail counts as engaging with the POI (D05).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final demo = ref.read(demoProvider);
      final p = demo.place(widget.id);
      if (p != null && demo.sessionActive) demo.markVisited(p);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _gallery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(demoProvider);
    final place = demo.place(widget.id);
    if (place == null || !place.isPoi) {
      return const Scaffold(
          body: Center(child: Text('Tempat tidak ditemukan')));
    }
    final poi = place.poi!;
    final pad = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final headerH = math.min(width * 1.05, 440.0);
    final images = place.images.isEmpty ? [null] : place.images;
    final visited = demo.visited.contains(place.id);
    final gateM =
        demo.router.walkingDistanceM(demo.content.gate.position, place.node);
    final collapsed = _offset > headerH - pad.top - 70;

    return Scaffold(
      backgroundColor: JT.cream,
      body: Stack(
        children: [
          // parallax header
          Positioned(
            top: -_offset.clamp(0, double.infinity) * 0.45,
            left: 0,
            right: 0,
            height: headerH + math.max(0, -_offset),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(34)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _gallery,
                    itemCount: images.length,
                    itemBuilder: (context, i) => i == 0
                        ? PlacePhoto(
                            place: place,
                            radius: 0,
                            heroSuffix: widget.heroSuffix)
                        : PlacePhoto(
                            place: place, radius: 0, hero: false, index: i),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.25, 0.7, 1],
                          colors: [
                            JT.ink.withValues(alpha: 0.45),
                            Colors.transparent,
                            Colors.transparent,
                            JT.ink.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 18,
                      left: 0,
                      right: 0,
                      child: Center(
                          child: PageDots(
                              count: images.length,
                              page: _page,
                              color: Colors.white)),
                    ),
                ],
              ),
            ),
          ),
          // content
          CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                  child: IgnorePointer(child: SizedBox(height: headerH - 8))),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(JT.gutter, 20, JT.gutter, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Entrance(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Pill(
                                label: place.groupLabel,
                                icon: place.icon,
                                color: place.tint),
                            if (visited)
                              const Pill(
                                  label: 'Dikunjungi',
                                  icon: Icons.check_rounded,
                                  color: JT.leaf),
                            if (poi.hasQr)
                              const Pill(
                                  label: 'Ada kode QR',
                                  icon: Icons.qr_code_rounded,
                                  color: JT.forest),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Entrance(
                        delay: const Duration(milliseconds: 60),
                        child: Text(place.name, style: JTText.hero),
                      ),
                      const SizedBox(height: 10),
                      Entrance(
                        delay: const Duration(milliseconds: 120),
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            _Meta(Icons.schedule_rounded,
                                '±${poi.visitMinutes} mnt di lokasi'),
                            _Meta(Icons.directions_walk_rounded,
                                '${distanceLabel(demo.walkingM(place))} dari Anda'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Entrance(
                        delay: const Duration(milliseconds: 180),
                        child: _AudioCard(place: place),
                      ),
                      if (poi.safetyNote != null) ...[
                        const SizedBox(height: 14),
                        Entrance(
                          delay: const Duration(milliseconds: 220),
                          child: _Safety(text: poi.safetyNote!),
                        ),
                      ],
                      const SizedBox(height: 26),
                      Text('Yang akan Anda temui', style: JTText.h2),
                      const SizedBox(height: 10),
                      Text(poi.displayText, style: JTText.body),
                      const SizedBox(height: 26),
                      Text('Sekilas', style: JTText.h2),
                      const SizedBox(height: 12),
                      _Facts(items: [
                        (Icons.category_rounded, 'Kategori', place.groupLabel),
                        (
                          Icons.timer_rounded,
                          'Lama kunjungan',
                          '±${poi.visitMinutes} menit'
                        ),
                        (
                          Icons.door_front_door_rounded,
                          'Dari gerbang',
                          place.isGate ? 'Titik awal' : distanceLabel(gateM)
                        ),
                        (
                          Icons.terrain_rounded,
                          'Jalur',
                          difficultyLabel(poi.difficulty)
                        ),
                      ]),
                      if (place.images.length > 1) ...[
                        const SizedBox(height: 26),
                        Text('Foto', style: JTText.h2),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 150,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: place.images.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, i) => Pressable(
                              onTap: () {
                                _gallery.animateToPage(i,
                                    duration: JTMotion.slow,
                                    curve: JTMotion.emphasized);
                                _scroll.animateTo(0,
                                    duration: JTMotion.lazy,
                                    curve: JTMotion.emphasized);
                              },
                              child: AspectRatio(
                                aspectRatio: 3 / 4,
                                child: PlacePhoto(
                                    place: place, hero: false, index: i),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (place.images.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Center(
                          child: Text('Foto: dokumentasi tim Jelajah Taman',
                              style: JTText.caption.copyWith(color: JT.faint)),
                        ),
                      ],
                      SizedBox(height: 120 + pad.bottom),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // top bar: back (+ name once the header has scrolled away)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: JTMotion.base,
              padding: EdgeInsets.fromLTRB(12, pad.top + 8, 12, 8),
              decoration: BoxDecoration(
                color: collapsed
                    ? JT.cream.withValues(alpha: 0.97)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Kembali',
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: collapsed ? 1 : 0,
                      duration: JTMotion.base,
                      child: Text(place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: JTText.h3),
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.map_rounded,
                    tooltip: 'Navigasi ke sini',
                    onTap: () {
                      if (demo.startNavigation(place)) {
                        context.push('/navigate');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          // sticky CTA
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  JT.gutter, 14, JT.gutter, 14 + pad.bottom),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [JT.cream.withValues(alpha: 0), JT.cream, JT.cream],
                  stops: const [0, 0.35, 1],
                ),
              ),
              child: PrimaryPill(
                label: 'Selesai, lihat berikutnya',
                trailingIcon: Icons.arrow_forward_rounded,
                onTap: () {
                  demo.markVisited(place);
                  showRecommendations(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: JT.forest),
          const SizedBox(width: 5),
          Text(text,
              style: JTText.bodySm.copyWith(fontWeight: FontWeight.w600)),
        ],
      );
}

class _AudioCard extends ConsumerWidget {
  const _AudioCard({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final mine = demo.nowPlaying?.id == place.id;
    final playing = mine && demo.audioPlaying;
    final len = demo.audioLength(place);
    final pos = mine ? demo.audioPos : 0.0;
    return JTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedSwitcher(
                duration: JTMotion.base,
                child: playing
                    ? const Pako(
                        key: ValueKey('p'),
                        pose: PakoPose.listen,
                        size: 52,
                        shadow: false)
                    : const IconBadge(
                        key: ValueKey('i'),
                        icon: Icons.headphones_rounded,
                        size: 44),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cerita tempat ini', style: JTText.title),
                    Text(
                        place.poi?.audio == null
                            ? 'Dibacakan suara otomatis'
                            : 'Narasi audio',
                        style: JTText.caption),
                  ],
                ),
              ),
              Pill(
                  label: durationClock(Duration(seconds: len.round())),
                  color: JT.forest),
            ],
          ),
          const SizedBox(height: 12),
          Waveform(
            progress: pos / len,
            playing: playing,
            seed: place.seed,
            onSeek: (f) {
              if (!mine) demo.playAudio(place);
              demo.seekAudio(f);
            },
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(durationClock(Duration(seconds: pos.round())),
                  style: JTText.number(13, color: JT.muted, w: 600)),
              const Spacer(),
              Text(durationClock(Duration(seconds: len.round())),
                  style: JTText.number(13, color: JT.muted, w: 600)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleIconButton(
                icon: Icons.replay_10_rounded,
                tooltip: 'Mundur 10 detik',
                background: JT.cream,
                onTap: mine ? () => demo.skipAudio(-10) : null,
              ),
              const SizedBox(width: 22),
              Pressable(
                onTap: () => demo.toggleAudio(place),
                scale: 0.9,
                semanticLabel: playing ? 'Jeda' : 'Putar',
                child: AnimatedContainer(
                  duration: JTMotion.base,
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: playing ? JT.sun : JT.forest,
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedSwitcher(
                    duration: JTMotion.base,
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      key: ValueKey(playing),
                      size: 38,
                      color: playing ? JT.ink : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 22),
              CircleIconButton(
                icon: Icons.forward_10_rounded,
                tooltip: 'Maju 10 detik',
                background: JT.cream,
                onTap: mine ? () => demo.skipAudio(10) : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SoftButton(
            label: 'Mode dengar · layar besar',
            icon: Icons.open_in_full_rounded,
            height: 46,
            onTap: () {
              if (!mine) demo.playAudio(place);
              context.push('/play/${place.id}');
            },
          ),
        ],
      ),
    );
  }
}

class _Safety extends StatelessWidget {
  const _Safety({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: JT.terracottaSoft,
          borderRadius: BorderRadius.circular(JT.rCard),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: JT.terracotta.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.flashlight_on_rounded,
                  color: JT.terracotta, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Perhatian keselamatan',
                      style: JTText.label
                          .copyWith(color: const Color(0xFFA63A22))),
                  const SizedBox(height: 3),
                  Text(text,
                      style: JTText.bodySm
                          .copyWith(color: const Color(0xFF6B2A1A))),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Facts extends StatelessWidget {
  const _Facts({required this.items});

  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (icon, label, value) in items)
                Container(
                  width: w,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: JT.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: JT.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 20, color: JT.forest),
                      const SizedBox(height: 8),
                      Text(label.toUpperCase(), style: JTText.overline),
                      const SizedBox(height: 3),
                      Text(value, style: JTText.title),
                    ],
                  ),
                ),
            ],
          );
        },
      );
}
