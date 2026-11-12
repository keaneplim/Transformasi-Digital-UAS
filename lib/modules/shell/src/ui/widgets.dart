import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../demo/demo_controller.dart';
import '../demo/places.dart';

/// Photo (or illustrated stand-in) for a place, Hero-tagged so it flies into POI Detail.
class PlacePhoto extends StatelessWidget {
  const PlacePhoto({
    super.key,
    required this.place,
    this.radius = 18,
    this.hero = true,
    this.heroSuffix = '',
    this.index = 0,
  });

  final Place place;
  final double radius;
  final bool hero;
  final String heroSuffix;
  final int index;

  @override
  Widget build(BuildContext context) {
    final img = SceneImage(
      asset: place.images.length > index ? place.images[index] : null,
      tint: place.tint,
      doodle: place.doodle,
      seed: place.seed,
      radius: radius,
    );
    if (!hero) return img;
    return Hero(
      tag: 'photo-${place.id}$heroSuffix',
      flightShuttleBuilder: (context, anim, dir, from, to) => ClipRRect(
        borderRadius: BorderRadius.circular(radius * (1 - anim.value)),
        child: SceneImage(
          asset: place.cover,
          tint: place.tint,
          doodle: place.doodle,
          seed: place.seed,
        ),
      ),
      child: img,
    );
  }
}

/// List row: thumbnail, name, group pill, walking distance + ETA.
class PlaceTile extends ConsumerWidget {
  const PlaceTile({
    super.key,
    required this.place,
    required this.onTap,
    this.trailing,
    this.heroSuffix = '-tile',
  });

  final Place place;
  final VoidCallback onTap;
  final Widget? trailing;
  final String heroSuffix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final visited = demo.visited.contains(place.id);
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: place.name,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: JT.surface,
          borderRadius: BorderRadius.circular(JT.rCard),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 64,
              child:
                  PlacePhoto(place: place, radius: 16, heroSuffix: heroSuffix),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: JTText.title),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Pill(
                          label: place.groupLabel,
                          icon: place.icon,
                          color: place.tint),
                      if (visited) ...[
                        const SizedBox(width: 6),
                        const Pill(
                            label: 'Dikunjungi',
                            icon: Icons.check_rounded,
                            color: JT.leaf),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(distanceLabel(demo.walkingM(place)),
                        style: JTText.number(15)),
                    const SizedBox(height: 4),
                    Text(minutesLabel(demo.walkingTime(place)),
                        style: JTText.caption),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

/// Big photo card for carousels (Home highlights, nearby on the map).
class PlaceCard extends ConsumerWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.onTap,
    this.width = 220,
    this.height = 260,
    this.heroSuffix = '-card',
  });

  final Place place;
  final VoidCallback onTap;
  final double width;
  final double height;
  final String heroSuffix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final visited = demo.visited.contains(place.id);
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      semanticLabel: place.name,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PlacePhoto(place: place, radius: 26, heroSuffix: heroSuffix),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.4, 1],
                  colors: [Colors.transparent, JT.ink.withValues(alpha: 0.78)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Pill(
                label: place.groupLabel,
                icon: place.icon,
                color: place.tint,
                background: Colors.white.withValues(alpha: 0.92),
              ),
            ),
            if (visited)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                      color: JT.leaf, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: JTText.h3.copyWith(color: Colors.white)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.directions_walk_rounded,
                          size: 15, color: JT.sunSoft),
                      const SizedBox(width: 4),
                      Text(
                        '${distanceLabel(demo.walkingM(place))} · ${minutesLabel(demo.walkingTime(place))}',
                        style: JTText.caption.copyWith(color: Colors.white),
                      ),
                    ],
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

/// Session stats: steps · distance · duration · visited. Values count up.
class StatStrip extends ConsumerWidget {
  const StatStrip({super.key, this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final fg = dark ? Colors.white : JT.ink;
    final sub = dark ? Colors.white70 : JT.muted;
    final total = demo.routePois.length;
    final visited =
        demo.routePois.where((p) => demo.visited.contains(p.id)).length;
    Widget cell(Widget value, String label) => Expanded(
          child: Column(
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: value),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    maxLines: 1, style: JTText.overline.copyWith(color: sub)),
              ),
            ],
          ),
        );
    Widget div() =>
        Container(width: 1, height: 30, color: dark ? Colors.white24 : JT.line);
    return Row(
      children: [
        cell(
            AnimatedCount(
                value: demo.steps.toDouble(),
                format: thousands,
                style: JTText.number(20, color: fg)),
            'LANGKAH'),
        div(),
        cell(
            AnimatedCount(
                value: demo.walkedM,
                format: (v) => '${km(v)} km',
                style: JTText.number(20, color: fg)),
            'JARAK'),
        div(),
        cell(
            Text(durationClock(demo.sessionDuration).substring(0, 5),
                style: JTText.number(20, color: fg)),
            'DURASI'),
        div(),
        cell(
            Text('$visited/$total',
                style:
                    JTText.number(20, color: dark ? JT.sun : JT.forestBright)),
            'TEMPAT'),
      ],
    );
  }
}

/// Small circular badge with an icon, used for list leading and info rows.
class IconBadge extends StatelessWidget {
  const IconBadge(
      {super.key, required this.icon, this.color = JT.forest, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color.lerp(color, JT.cream, 0.82),
          borderRadius: BorderRadius.circular(size * 0.36),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}
