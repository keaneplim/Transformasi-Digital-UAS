import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:jelajah_taman/modules/location/location.dart';
import 'package:jelajah_taman/modules/map/map.dart';

import '../state/guide_controller.dart';
import '../state/places.dart';
import 'main_shell.dart';
import 'park_map.dart';
import 'tab_stage.dart';
import 'widgets.dart';

/// UI03 Explore map. Tap any marker → preview → Navigasi / Detail / "Saya di sini".
/// The dot is the live GPS position (real mode) or the simulated one (demo mode).
///
/// On a tab change the controls clear out before the canopy comes down over the map, and
/// drop back in once it has lifted (see [TabStage]): the bar from the top, the buttons from
/// the side, the strip from below, while the map itself settles from a slight zoom.
class MapTab extends ConsumerStatefulWidget {
  const MapTab({super.key});

  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> with TickerProviderStateMixin {
  final ParkMapController mapController = ParkMapController();
  String? _selected;
  bool _facilities = true;
  bool _satellite = false;

  /// Locate button: first tap centres on the visitor, a second tap follows them; panning by
  /// hand stops both.
  bool _centered = false;
  bool _follow = false;

  void _locate(GuideController demo) {
    if (demo.noPosition) {
      _askLocation(demo);
      return;
    }
    if (demo.outsideZone) {
      _toast('Anda di luar kawasan Tahura. Peta menampilkan area taman.');
      mapController.glideTo(demo.content.gate.position,
          vsync: this, zoom: 16.4);
      return;
    }
    if (_centered && !_follow) {
      setState(() => _follow = true);
      return;
    }
    mapController.glideTo(demo.position, vsync: this, zoom: 17.4);
    setState(() => _centered = true);
  }

  Future<void> _askLocation(GuideController demo) async {
    if (!demo.locationSupported) {
      _toast(
          'Lokasi tidak tersedia di perangkat ini. Aktifkan Mode demo di Pengaturan.');
      return;
    }
    if (demo.access == LocationAccess.deniedForever) {
      await demo.openLocationSettings();
      return;
    }
    final a = await demo.requestLocation();
    if (!mounted) return;
    if (a == LocationAccess.serviceOff) {
      _toast('Nyalakan lokasi (GPS) di perangkat Anda.');
    } else if (a != LocationAccess.granted) {
      _toast('Izin lokasi dibutuhkan agar pemandu tahu posisi Anda.');
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text, style: JTText.body.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: JT.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.fromLTRB(
            16, 0, 16, 120 + MediaQuery.paddingOf(context).bottom),
      ));
  }

  void _openLayers() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LayersSheet(
        satellite: _satellite,
        facilities: _facilities,
        onSatellite: (v) => setState(() => _satellite = v),
        onFacilities: (v) => setState(() => _facilities = v),
      ),
    );
  }

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
    final demo = ref.watch(guideProvider);
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
    final stage = TabStageScope.maybeOf(context);

    final map = ParkMap(
      controller: mapController,
      selectedId: _selected,
      highlightId: demo.approaching?.place.id,
      showFacilities: _facilities,
      satellite: _satellite,
      followUser: _follow,
      // the preview card covers the lower map; the chip returns when it closes
      showChrome: selected == null,
      onUserGesture: () {
        if (_centered || _follow) {
          setState(() {
            _centered = false;
            _follow = false;
          });
        }
      },
      onSatelliteError: () {
        setState(() => _satellite = false);
        _toast('Peta satelit butuh internet. Kembali ke peta biasa.');
      },
      chromeInsets: EdgeInsets.fromLTRB(
          16, pad.top + 120, 16, bottomNav + (selected != null ? 250 : 200)),
      onPlaceTap: _select,
      onMapTap: () => setState(() => _selected = null),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: stage == null
              ? map
              // the map eases back a touch as the page body covers it, and settles as
              // the body clears
              : ListenableBuilder(
                  listenable: stage,
                  child: map,
                  builder: (context, map) => Transform.scale(
                      scale: 1 + 0.04 * stage.cover, child: map),
                ),
        ),
        // soft fade under the top controls so they stay readable over the map
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: pad.top + 120,
          child: IgnorePointer(
            child: Staged(
              from: Offset.zero,
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
        ),
        Positioned(
          left: 16,
          right: 16,
          top: pad.top + 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Staged(
                at: 0.1,
                from: const Offset(0, -20),
                // the bar leads into the search field: the page opens ready to type
                child: _SearchBar(onTap: () => openSearch(ref, typing: true)),
              ),
              const SizedBox(height: 10),
              Staged(
                at: 0.2,
                from: const Offset(0, -14),
                child: Wrap(
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
                    if (demo.isDemo)
                      const Pill(
                        label: 'Mode demo',
                        icon: Icons.science_rounded,
                        color: JT.doodle,
                        background: Colors.white,
                      ),
                  ],
                ),
              ),
              Staged(
                at: 0.26,
                from: const Offset(0, -14),
                child: _StatusChip(
                    demo: demo, onAskLocation: () => _askLocation(demo)),
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
          child: Staged(
            at: 0.3,
            from: const Offset(24, 0),
            child: Column(
              children: [
                CircleIconButton(
                  icon: _satellite
                      ? Icons.satellite_alt_rounded
                      : Icons.layers_rounded,
                  tooltip: 'Lapisan peta',
                  onTap: _openLayers,
                ),
                const SizedBox(height: 10),
                CircleIconButton(
                  icon: _follow
                      ? Icons.navigation_rounded
                      : demo.noPosition
                          ? Icons.location_disabled_rounded
                          : _centered
                              ? Icons.my_location_rounded
                              : Icons.location_searching_rounded,
                  tooltip: _follow
                      ? 'Mengikuti posisi Anda'
                      : demo.noPosition
                          ? 'Aktifkan lokasi'
                          : 'Posisi saya',
                  foreground: demo.noPosition ? JT.muted : JT.sky,
                  background: _follow ? const Color(0xFFE3F0FA) : JT.surface,
                  onTap: () => _locate(demo),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomNav,
          child: Staged(
            at: 0.36,
            from: const Offset(0, 30),
            child: AnimatedSwitcher(
              duration: JTMotion.slow,
              switchInCurve: JTMotion.emphasized,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position:
                      Tween(begin: const Offset(0, 0.25), end: Offset.zero)
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
    final demo = ref.watch(guideProvider);
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
          height: 98,
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
                    width: 248,
                    padding: const EdgeInsets.fromLTRB(9, 9, 12, 9),
                    decoration: BoxDecoration(
                      color: JT.surface,
                      borderRadius: BorderRadius.circular(JT.rCard),
                    ),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 76,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: PlacePhoto(
                                    place: p, radius: 16, heroSuffix: '-near'),
                              ),
                              if (demo.visited.contains(p.id))
                                const Positioned(
                                    right: -4, top: -4, child: VisitedTick()),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CategoryLabel(
                                  place: p, text: i == 0 ? 'Terdekat' : null),
                              const SizedBox(height: 3),
                              Text(p.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: JTText.label.copyWith(fontSize: 15)),
                              const SizedBox(height: 4),
                              WalkMeta(place: p),
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
    final demo = ref.watch(guideProvider);
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
                  height: 98,
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
                          Flexible(
                            child: Text(
                                '  ·  ${minutesLabel(demo.walkingTime(place))} '
                                '${demo.outsideZone || demo.noPosition ? 'dari gerbang' : 'jalan kaki'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: JTText.caption),
                          ),
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

/// One line under the route pill about the position itself: location off, outside the park,
/// or weak GPS. Hidden when all is well (and always in demo mode).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.demo, required this.onAskLocation});

  final GuideController demo;
  final VoidCallback onAskLocation;

  @override
  Widget build(BuildContext context) {
    final (String, IconData, Color, VoidCallback?)? s = demo.isDemo
        ? null
        : demo.noPosition
            ? (
                demo.locationSupported
                    ? 'Aktifkan lokasi untuk memandu Anda'
                    : 'Lokasi tidak tersedia',
                Icons.location_off_rounded,
                JT.doodle,
                demo.locationSupported ? onAskLocation : null,
              )
            : demo.outsideZone
                ? (
                    'Anda di luar kawasan · ${distanceLabel(demo.distanceToGateM)} ke gerbang',
                    Icons.wrong_location_rounded,
                    JT.forest,
                    null,
                  )
                : demo.gpsWeakBanner
                    ? (
                        'GPS lemah, posisi kurang akurat',
                        Icons.gps_not_fixed_rounded,
                        JT.muted,
                        null
                      )
                    : null;
    return AnimatedSwitcher(
      duration: JTMotion.base,
      child: s == null
          ? const SizedBox.shrink()
          : Padding(
              key: ValueKey(s.$1),
              padding: const EdgeInsets.only(top: 8),
              child: Pressable(
                onTap: s.$4,
                scale: 0.97,
                semanticLabel: s.$1,
                child: Pill(
                    label: s.$1,
                    icon: s.$2,
                    color: s.$3,
                    background: Colors.white),
              ),
            ),
    );
  }
}

/// Layers: map style (Peta / Satelit), facilities, and a small legend.
class _LayersSheet extends StatefulWidget {
  const _LayersSheet({
    required this.satellite,
    required this.facilities,
    required this.onSatellite,
    required this.onFacilities,
  });

  final bool satellite;
  final bool facilities;
  final ValueChanged<bool> onSatellite;
  final ValueChanged<bool> onFacilities;

  @override
  State<_LayersSheet> createState() => _LayersSheetState();
}

class _LayersSheetState extends State<_LayersSheet> {
  late bool _sat = widget.satellite;
  late bool _fac = widget.facilities;

  @override
  Widget build(BuildContext context) {
    Widget style(String label, String sub, bool sat, IconData icon) {
      final on = _sat == sat;
      return Expanded(
        child: Pressable(
          onTap: () {
            setState(() => _sat = sat);
            widget.onSatellite(sat);
          },
          scale: 0.97,
          semanticLabel: label,
          child: AnimatedContainer(
            duration: JTMotion.base,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: on ? const Color(0xFFE6F1E8) : JT.cream,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: on ? JT.forest : Colors.transparent, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: on ? JT.forest : JT.muted),
                const SizedBox(height: 8),
                Text(label, style: JTText.label),
                const SizedBox(height: 2),
                Text(sub, style: JTText.caption),
              ],
            ),
          ),
        ),
      );
    }

    Widget legend(Widget swatch, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 34, child: Center(child: swatch)),
            const SizedBox(width: 10),
            Text(text, style: JTText.caption.copyWith(color: JT.ink)),
          ]),
        );
    Widget line(Color c, {double h = 4, bool dashed = false}) => dashed
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Container(
                  width: 7,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  color: c),
          ])
        : Container(
            width: 28,
            height: h,
            decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(h)));

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        decoration: BoxDecoration(
            color: JT.surface, borderRadius: BorderRadius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: JT.line, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            Text('Lapisan peta', style: JTText.h3),
            const SizedBox(height: 12),
            Row(children: [
              style(
                  'Peta', 'Tersedia tanpa internet', false, Icons.map_rounded),
              const SizedBox(width: 10),
              style('Satelit', 'Butuh internet', true,
                  Icons.satellite_alt_rounded),
            ]),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _fac,
              activeTrackColor: JT.forest,
              title: Text('Tampilkan fasilitas', style: JTText.label),
              subtitle: Text('Toilet, musala, warung, tempat istirahat',
                  style: JTText.caption),
              onChanged: (v) {
                setState(() => _fac = v);
                widget.onFacilities(v);
              },
            ),
            const Divider(height: 18),
            legend(line(JT.forest, h: 5), 'Rute aktif'),
            legend(line(const Color(0xFFC79A55), dashed: true),
                'Jalur setapak di taman'),
            legend(line(const Color(0xFF2F7A50), h: 2, dashed: true),
                'Batas Tahura'),
            legend(line(const Color(0x668E7A52), h: 1.5),
                'Garis kontur (tiap 10 m)'),
          ],
        ),
      ),
    );
  }
}
