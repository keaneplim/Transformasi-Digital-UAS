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

/// List row: thumbnail (with a visited tick), category label in its colour, the name (the
/// search match highlighted) and walking distance/time. [trailing] replaces the default
/// arrow (e.g. a navigate button in search).
class PlaceTile extends ConsumerWidget {
  const PlaceTile({
    super.key,
    required this.place,
    required this.onTap,
    this.trailing,
    this.heroSuffix = '-tile',
    this.highlight = '',
    this.eyebrow,
  });

  final Place place;
  final VoidCallback onTap;
  final Widget? trailing;
  final String heroSuffix;

  /// Part of the name to mark (the search query).
  final String highlight;

  /// Replaces the category label (e.g. "Terdekat").
  final String? eyebrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final visited = demo.visited.contains(place.id);
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: place.name,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: JT.surface,
          borderRadius: BorderRadius.circular(JT.rCard),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 66,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: PlacePhoto(
                        place: place, radius: 16, heroSuffix: heroSuffix),
                  ),
                  if (visited)
                    const Positioned(right: -4, top: -4, child: VisitedTick()),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CategoryLabel(place: place, text: eyebrow),
                  const SizedBox(height: 3),
                  MatchText(
                    place.name,
                    highlight: highlight,
                    maxLines: 2,
                    style: JTText.title,
                  ),
                  const SizedBox(height: 4),
                  WalkMeta(place: place),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                      color: JT.cream, shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_right_rounded,
                      size: 22, color: JT.forest),
                ),
          ],
        ),
      ),
    );
  }
}

/// Small coloured eyebrow: category icon + label (or [text]) in the category tint.
class CategoryLabel extends StatelessWidget {
  const CategoryLabel(
      {super.key, required this.place, this.text, this.onDark = false});

  final Place place;
  final String? text;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final special = text != null;
    final color =
        onDark ? Colors.white : (special ? JT.forestBright : place.tint);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(special ? Icons.near_me_rounded : place.icon,
            size: 13, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            (text ?? place.groupLabel).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: JTText.overline.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// "🚶 280 m · 8 mnt" with the distance as a tabular number.
class WalkMeta extends ConsumerWidget {
  const WalkMeta({super.key, required this.place, this.color});

  final Place place;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final fg = color ?? JT.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.directions_walk_rounded,
            size: 15, color: color ?? JT.forestBright),
        const SizedBox(width: 3),
        Text(distanceLabel(demo.walkingM(place)),
            style: JTText.number(13.5, color: fg)),
        Text(' · ${minutesLabel(demo.walkingTime(place))}',
            style: JTText.caption
                .copyWith(color: color?.withValues(alpha: 0.85) ?? JT.muted)),
      ],
    );
  }
}

/// Text with the first case-insensitive occurrence of [highlight] marked in sun yellow.
class MatchText extends StatelessWidget {
  const MatchText(this.text,
      {super.key, this.highlight = '', this.style, this.maxLines});

  final String text;
  final String highlight;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final q = highlight.trim().toLowerCase();
    final i = q.isEmpty ? -1 : text.toLowerCase().indexOf(q);
    if (i < 0) {
      return Text(text,
          maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style);
    }
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text.substring(0, i)),
        TextSpan(
          text: text.substring(i, i + q.length),
          style: TextStyle(
              backgroundColor: JT.sunSoft, fontWeight: FontWeight.w800),
        ),
        TextSpan(text: text.substring(i + q.length)),
      ]),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// Green tick with a white rim, pinned to a thumbnail corner.
class VisitedTick extends StatelessWidget {
  const VisitedTick({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: JT.leaf,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child:
            Icon(Icons.check_rounded, color: Colors.white, size: size * 0.62),
      );
}

/// Carousel card, polaroid style: inset photo with the category pill, then a white footer
/// with the name, walking distance and a round arrow.
class PlaceCard extends ConsumerWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.onTap,
    this.width = 220,
    this.height = 268,
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
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: JT.surface,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlacePhoto(place: place, radius: 19, heroSuffix: heroSuffix),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Pill(
                      label: place.groupLabel,
                      icon: place.icon,
                      color: place.tint,
                      background: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  if (visited)
                    const Positioned(
                        right: 10, top: 10, child: VisitedTick(size: 28)),
                ],
              ),
            ),
            SizedBox(
              height: 84,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 2, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(place.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: JTText.h3),
                          const Spacer(),
                          WalkMeta(place: place),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                          color: JT.mint, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward_rounded,
                          size: 19, color: JT.forest),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Session stats: steps · distance · duration · visited, each with a small icon.
/// Values count up.
class StatStrip extends ConsumerWidget {
  const StatStrip({super.key, this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final fg = dark ? Colors.white : JT.ink;
    final sub = dark ? Colors.white70 : JT.muted;
    final ico = dark ? JT.sun : JT.forestBright;
    final total = demo.routePois.length;
    final visited =
        demo.routePois.where((p) => demo.visited.contains(p.id)).length;
    Widget cell(IconData icon, Widget value, String label) => Expanded(
          child: Column(
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: value),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: ico),
                    const SizedBox(width: 4),
                    Text(label,
                        maxLines: 1,
                        style: JTText.overline.copyWith(color: sub)),
                  ],
                ),
              ),
            ],
          ),
        );
    Widget div() =>
        Container(width: 1, height: 30, color: dark ? Colors.white24 : JT.line);
    return Row(
      children: [
        cell(
            Icons.directions_walk_rounded,
            AnimatedCount(
                value: demo.steps.toDouble(),
                format: thousands,
                style: JTText.number(20, color: fg)),
            'LANGKAH'),
        div(),
        cell(
            Icons.straighten_rounded,
            AnimatedCount(
                value: demo.walkedM,
                format: (v) => '${km(v)} km',
                style: JTText.number(20, color: fg)),
            'JARAK'),
        div(),
        cell(
            Icons.timer_outlined,
            Text(durationClock(demo.sessionDuration).substring(0, 5),
                style: JTText.number(20, color: fg)),
            'DURASI'),
        div(),
        cell(
            Icons.place_rounded,
            Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '$visited',
                    style: JTText.number(20,
                        color: dark ? JT.sun : JT.forestBright)),
                TextSpan(text: '/$total', style: JTText.number(15, color: sub)),
              ]),
            ),
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
