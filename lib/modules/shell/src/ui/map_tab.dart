import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:jelajah_taman/modules/map/map.dart';

import '../demo/demo_controller.dart';
import '../demo/places.dart';
import 'main_shell.dart';
import 'park_map.dart';
import 'widgets.dart';

/// UI03 Explore map. Tap any marker → preview → Navigasi / Detail / "Saya di sini".
/// No GPS needed: the visitor's dot is simulated (see DemoController).
class MapTab extends ConsumerStatefulWidget {
  const MapTab({super.key});

  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> with TickerProviderStateMixin {
  final ParkMapController mapController = ParkMapController();
  String? _selected;
  bool _facilities = true;

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  void _select(Place p) {
    setState(() => _selected = p.id);
    // keep the marker above the preview card
    mapController.glideTo(GeoPoint(p.position.lat - 0.0011, p.position.lng),
        vsync: this, zoom: 17.2);
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(demoProvider);
    ref.listen(mapFocusProvider, (_, id) {
      if (id == null) return;
      final p = demo.place(id);
      if (p != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _select(p));
      }
      ref.read(mapFocusProvider.notifier).state = null;
    });
    final selected = _selected == null ? null : demo.place(_selected!);
    final pad = MediaQuery.paddingOf(context);
    final bottomNav = 96 + pad.bottom;

    return Stack(
      children: [
        Positioned.fill(
          child: ParkMap(
            controller: mapController,
            selectedId: _selected,
            highlightId: demo.approaching?.place.id,
            showFacilities: _facilities,
            onPlaceTap: _select,
            onMapTap: () => setState(() => _selected = null),
          ),
        ),
        // soft fade under the top controls so they stay readable over the map
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: pad.top + 120,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    JT.cream.withValues(alpha: 0.9),
                    JT.cream.withValues(alpha: 0)
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: pad.top + 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchBar(onTap: () => ref.read(tabProvider.notifier).state = 2),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  Pill(
                    label: 'Rute ${demo.route.name}',
                    icon: Icons.route_rounded,
                    color: JT.forest,
                    background: Colors.white,
                  ),
                  if (demo.sessionActive)
                    Pill(
                      label: '${demo.visited.length} dikunjungi',
                      icon: Icons.check_circle_rounded,
                      color: JT.leaf,
                      background: Colors.white,
                    ),
                ],
              ),
            ],
          ),
        ),
        // right-side controls
        AnimatedPositioned(
          duration: JTMotion.slow,
          curve: JTMotion.emphasized,
          right: 16,
          bottom: bottomNav + (selected != null ? 250 : 200),
          child: Column(
            children: [
              CircleIconButton(
                icon:
                    _facilities ? Icons.layers_rounded : Icons.layers_outlined,
                tooltip: _facilities
                    ? 'Sembunyikan fasilitas'
                    : 'Tampilkan fasilitas',
                onTap: () => setState(() => _facilities = !_facilities),
              ),
              const SizedBox(height: 10),
              CircleIconButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Posisi saya',
                foreground: JT.sky,
                onTap: () => mapController.glideTo(demo.position,
                    vsync: this, zoom: 17.4),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomNav,
          child: AnimatedSwitcher(
            duration: JTMotion.slow,
            switchInCurve: JTMotion.emphasized,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
                    .animate(a),
                child: child,
              ),
            ),
            child: selected != null
                ? _Preview(
                    key: ValueKey(selected.id),
                    place: selected,
                    onClose: () => setState(() => _selected = null),
                  )
                : _NearbyStrip(key: const ValueKey('nearby'), onTap: _select),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.98,
        semanticLabel: 'Cari tempat atau fasilitas',
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: JT.surface,
            borderRadius: BorderRadius.circular(27),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: JT.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Cari tempat atau fasilitas',
                    style: JTText.body.copyWith(color: JT.muted)),
              ),
            ],
          ),
        ),
      );
}

/// Peek content when nothing is selected: session stats + the nearest places.
class _NearbyStrip extends ConsumerWidget {
  const _NearbyStrip({super.key, required this.onTap});

  final ValueChanged<Place> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final near =
        demo.nearest(poisOnly: true).where((p) => !p.isGate).take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (demo.sessionActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              decoration: BoxDecoration(
                color: JT.surface,
                borderRadius: BorderRadius.circular(JT.rCard),
              ),
              child: const StatStrip(),
            ),
          ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: near.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final p = near[i];
              return Entrance(
                delay: JTMotion.stagger * i,
                offset: const Offset(24, 0),
                child: Pressable(
                  onTap: () => onTap(p),
                  scale: 0.96,
                  semanticLabel: p.name,
                  child: Container(
                    width: 238,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: JT.surface,
                      borderRadius: BorderRadius.circular(JT.rCard),
                    ),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 74,
                          child: PlacePhoto(
                              place: p, radius: 15, heroSuffix: '-near'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  i == 0
                                      ? 'TERDEKAT'
                                      : p.groupLabel.toUpperCase(),
                                  style: JTText.overline.copyWith(
                                      color:
                                          i == 0 ? JT.forestBright : JT.muted)),
                              const SizedBox(height: 3),
                              Text(p.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: JTText.label),
                              const SizedBox(height: 3),
                              Text(
                                '${distanceLabel(demo.walkingM(p))} · ${minutesLabel(demo.walkingTime(p))}',
                                style: JTText.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Marker preview: photo, name, distance; Navigasi (primary), Detail, "Saya di sini".
class _Preview extends ConsumerWidget {
  const _Preview({super.key, required this.place, required this.onClose});

  final Place place;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final visited = demo.visited.contains(place.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: JT.surface,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: PlacePhoto(
                      place: place, radius: 18, heroSuffix: '-preview'),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 8),
                      Text(place.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: JTText.h3),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.directions_walk_rounded,
                              size: 16, color: JT.forest),
                          const SizedBox(width: 4),
                          Text(distanceLabel(demo.walkingM(place)),
                              style: JTText.number(15)),
                          Text(
                              '  ·  ${minutesLabel(demo.walkingTime(place))} jalan kaki',
                              style: JTText.caption),
                        ],
                      ),
                    ],
                  ),
                ),
                CircleIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Tutup',
                  size: 40,
                  iconSize: 20,
                  background: JT.cream,
                  onTap: onClose,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PrimaryPill(
                    label: 'Navigasi',
                    icon: Icons.navigation_rounded,
                    height: 52,
                    onTap: () {
                      if (demo.startNavigation(place)) {
                        context.push('/navigate');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (place.isPoi)
                  Expanded(
                    flex: 2,
                    child: SoftButton(
                      label: 'Detail',
                      height: 52,
                      onTap: () =>
                          context.push('/poi/${place.id}?hero=-preview'),
                    ),
                  ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Saya di sini',
                  child: SoftButton(
                    label: '',
                    icon: Icons.person_pin_circle_rounded,
                    height: 52,
                    expand: false,
                    color: JT.cream,
                    onTap: () {
                      onClose();
                      if (place.isPoi &&
                          !place.isGate &&
                          !demo.visited.contains(place.id)) {
                        demo.triggerNow(place);
                      } else {
                        demo.teleportTo(place);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
