import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/map/map.dart';

import '../state/guide_controller.dart';
import '../state/places.dart';

/// The park map fed with the guide state (places, visited, live or simulated position).
/// Rendering lives in the `map` module ([ParkMapView]); this only maps data across.
class ParkMap extends ConsumerWidget {
  const ParkMap({
    super.key,
    this.controller,
    this.selectedId,
    this.highlightId,
    this.destinationId,
    this.route = const [],
    this.walkedM = 0,
    this.onPlaceTap,
    this.onMapTap,
    this.showFacilities = true,
    this.showLabels = true,
    this.interactive = true,
    this.initialZoom = 16.4,
    this.initialCenter,
    this.fitPadding = const EdgeInsets.fromLTRB(40, 140, 40, 300),
    this.trailOverride,
    this.chromeInsets = const EdgeInsets.all(12),
    this.satellite = false,
    this.onSatelliteError,
    this.followUser = false,
    this.onUserGesture,
    this.showChrome,
  });

  /// Scale bar + attribution; defaults to [interactive].
  final bool? showChrome;

  final bool satellite;
  final VoidCallback? onSatelliteError;
  final bool followUser;
  final VoidCallback? onUserGesture;

  /// Space the screen's own overlays take (scale bar + attribution stay inside it).
  final EdgeInsets chromeInsets;

  final ParkMapController? controller;
  final String? selectedId;
  final String? highlightId;
  final String? destinationId;
  final List<GeoPoint> route;
  final double walkedM;
  final ValueChanged<Place>? onPlaceTap;
  final VoidCallback? onMapTap;
  final bool showFacilities;
  final bool showLabels;
  final bool interactive;
  final double initialZoom;
  final GeoPoint? initialCenter;
  final EdgeInsets fitPadding;

  /// Draw this line instead of the live visitor trail (session summary).
  final List<GeoPoint>? trailOverride;

  static const background = ParkMapView.background;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    return ParkMapView(
      pins: [
        for (final p in demo.places)
          MapPin(
            id: p.id,
            position: p.position,
            name: p.name,
            color: p.tint,
            icon: p.icon,
            isPoi: p.isPoi,
            isGate: p.isGate,
            visited: demo.visited.contains(p.id),
            radiusM: p.poi?.radiusM ?? 25,
          ),
      ],
      user: demo.position,
      headingDeg: demo.heading,
      accuracyM: demo.accuracyM,
      gpsWeak: demo.gpsWeak,
      showUser: demo.showUser,
      trail: trailOverride ?? demo.trail,
      overview: [for (final p in demo.routePois) p.position],
      controller: controller,
      selectedId: selectedId,
      highlightId: highlightId,
      destinationId: destinationId,
      route: route,
      walkedM: walkedM,
      onPlaceTap: onPlaceTap == null
          ? null
          : (id) {
              final p = demo.place(id);
              if (p != null) onPlaceTap!(p);
            },
      onMapTap: onMapTap,
      showFacilities: showFacilities,
      showLabels: showLabels,
      interactive: interactive,
      initialZoom: initialZoom,
      initialCenter: initialCenter,
      fitPadding: fitPadding,
      chromeInsets: chromeInsets,
      satellite: satellite,
      onSatelliteError: onSatelliteError,
      followUser: followUser,
      onUserGesture: onUserGesture,
      showChrome: showChrome,
    );
  }
}
