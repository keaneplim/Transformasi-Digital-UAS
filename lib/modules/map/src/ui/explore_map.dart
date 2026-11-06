import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/theme/app_theme.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/location/location.dart';

import '../application/map_scene.dart';
import '../domain/map_geometry.dart';
import '../map_providers.dart';
import 'map_style.dart';

/// UI03 Explore map (A01): trails, POI + facility markers, geofence rings, active route, user dot.
///
/// Stateless about the session on purpose: the Explore screen (shell, T21) passes in the fix,
/// visited/triggered POIs and the active route. This widget never reads GPS itself.
class ExploreMap extends ConsumerStatefulWidget {
  const ExploreMap({
    super.key,
    this.userFix,
    this.activeRoute = const [],
    this.visitedPoiIds = const {},
    this.triggeredPoiId,
    this.selectedId,
    this.showGeofences = true,
    this.onPoiTap,
    this.onFacilityTap,
    this.onMapTap,
    this.onMapLongPress,
  });

  /// Latest fix (weak fixes too: they're drawn grey). Null = no position yet.
  final LocationFix? userFix;

  /// Navigation route polyline (F06). Empty = none.
  final List<GeoPoint> activeRoute;
  final Set<String> visitedPoiIds;

  /// POI currently in the Triggered state: drawn with an amber halo.
  final String? triggeredPoiId;

  /// POI or facility id whose preview card is open: drawn larger.
  final String? selectedId;
  final bool showGeofences;
  final ValueChanged<Poi>? onPoiTap;
  final ValueChanged<Facility>? onFacilityTap;
  final VoidCallback? onMapTap;
  final ValueChanged<GeoPoint>? onMapLongPress;

  /// Accuracy above this is drawn as a grey "GPS lemah" dot (F01, park.json `gps_weak_accuracy_m`).
  static const weakAccuracyM = 30.0;

  static const minZoom = 14.0;
  static const maxZoom = 19.0;
  static const _recenterZoom = 17.0;
  static const _fitPadding = EdgeInsets.all(32);

  @override
  ConsumerState<ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends ConsumerState<ExploreMap> {
  final _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LatLngBounds _bounds(GeoBounds b) =>
      LatLngBounds(b.southWest.toLatLng(), b.northEast.toLatLng());

  void _recenter(MapScene scene) {
    final fix = widget.userFix;
    if (fix != null && scene.isInsideZone(fix.position)) {
      _controller.move(
        fix.position.toLatLng(),
        math.max(_controller.camera.zoom, ExploreMap._recenterZoom),
      );
    } else {
      _controller.fitCamera(
        CameraFit.bounds(
            bounds: _bounds(scene.zone), padding: ExploreMap._fitPadding),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scene = ref.watch(mapSceneProvider);
    final fix = widget.userFix;
    final outsideZone = fix != null && !scene.isInsideZone(fix.position);
    final zoneBounds = _bounds(scene.zone);

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            // flutter_map's default initialCenter is outside our constraint and trips an assert.
            initialCenter: scene.zone.center.toLatLng(),
            initialZoom: ExploreMap._recenterZoom,
            initialCameraFit: CameraFit.bounds(
                bounds: zoneBounds, padding: ExploreMap._fitPadding),
            cameraConstraint:
                CameraConstraint.containCenter(bounds: zoneBounds),
            minZoom: ExploreMap.minZoom,
            maxZoom: ExploreMap.maxZoom,
            backgroundColor: MapStyle.background,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, __) => widget.onMapTap?.call(),
            onLongPress: (_, p) =>
                widget.onMapLongPress?.call(GeoPoint(p.latitude, p.longitude)),
          ),
          children: [
            // TODO(B, T05): MBTiles tile layer here + attribution "© OpenStreetMap contributors".
            PolylineLayer(
              polylines: [
                for (final t in scene.trails)
                  Polyline(
                    points: [for (final p in t) p.toLatLng()],
                    strokeWidth: 3,
                    color: MapStyle.trail,
                  ),
              ],
            ),
            if (widget.activeRoute.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [for (final p in widget.activeRoute) p.toLatLng()],
                    strokeWidth: 6,
                    color: MapStyle.activeRoute,
                  ),
                ],
              ),
            if (widget.showGeofences) ..._geofenceLayers(scene),
            if (fix != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: fix.position.toLatLng(),
                    radius: fix.accuracyM,
                    useRadiusInMeter: true,
                    color: AppColors.positionBlue.withValues(alpha: 0.12),
                    borderColor: AppColors.positionBlue.withValues(alpha: 0.3),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final f in scene.facilities) _facilityMarker(f),
                for (final p in scene.pois) _poiMarker(p),
                if (fix != null)
                  Marker(
                    point: fix.position.toLatLng(),
                    width: 24,
                    height: 24,
                    child: _UserDot(
                        weak: fix.accuracyM > ExploreMap.weakAccuracyM),
                  ),
              ],
            ),
          ],
        ),
        if (outsideZone)
          const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 12),
              child: Chip(
                avatar: Icon(Icons.wrong_location_outlined, size: 18),
                label: Text('Anda di luar zona Dago Pakar'),
              ),
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: null,
            tooltip: 'Pusatkan peta',
            onPressed: () => _recenter(scene),
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  /// Approaching ring (r + margin, faint fill) and trigger ring (r, dashed), GPS-triggered POIs only.
  List<Widget> _geofenceLayers(MapScene scene) {
    final gpsPois = scene.pois.where((p) => p.triggers.contains('gps'));
    return [
      CircleLayer(
        circles: [
          for (final p in gpsPois)
            CircleMarker(
              point: p.position.toLatLng(),
              radius: p.radiusM + scene.approachMarginM,
              useRadiusInMeter: true,
              color: MapStyle.category(p.category).withValues(alpha: 0.07),
              borderColor:
                  MapStyle.category(p.category).withValues(alpha: 0.25),
              borderStrokeWidth: 1,
            ),
        ],
      ),
      PolylineLayer(
        polylines: [
          for (final p in gpsPois)
            Polyline(
              points: [
                for (final q in circlePoints(p.position, p.radiusM))
                  q.toLatLng(),
              ],
              strokeWidth: 2,
              color: MapStyle.category(p.category).withValues(alpha: 0.8),
              pattern: StrokePattern.dashed(segments: [8, 6]),
            ),
        ],
      ),
    ];
  }

  Marker _poiMarker(Poi poi) {
    final selected = poi.id == widget.selectedId;
    final size = selected ? 56.0 : 48.0; // ≥48 dp touch target (A07)
    return Marker(
      point: poi.position.toLatLng(),
      width: size,
      height: size,
      child: _PoiPin(
        key: ValueKey('poi-${poi.id}'),
        poi: poi,
        visited: widget.visitedPoiIds.contains(poi.id),
        triggered: poi.id == widget.triggeredPoiId,
        selected: selected,
        onTap: () => widget.onPoiTap?.call(poi),
      ),
    );
  }

  Marker _facilityMarker(Facility f) => Marker(
        point: f.position.toLatLng(),
        width: 48,
        height: 48,
        child: _FacilityPin(
          key: ValueKey('facility-${f.id}'),
          facility: f,
          selected: f.id == widget.selectedId,
          onTap: () => widget.onFacilityTap?.call(f),
        ),
      );
}

class _PoiPin extends StatelessWidget {
  const _PoiPin({
    super.key,
    required this.poi,
    required this.visited,
    required this.triggered,
    required this.selected,
    required this.onTap,
  });

  final Poi poi;
  final bool visited;
  final bool triggered;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = MapStyle.category(poi.category);
    final d = selected ? 44.0 : 36.0;
    return Semantics(
      button: true,
      label: '${poi.name}${visited ? ', sudah dikunjungi' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.pureSurface, width: 2),
                  boxShadow: [
                    if (triggered)
                      BoxShadow(
                        color: AppColors.sunlitAmber.withValues(alpha: 0.7),
                        blurRadius: 12,
                        spreadRadius: 6,
                      )
                    else
                      BoxShadow(
                        color: AppColors.pineInk.withValues(alpha: 0.25),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: Icon(MapStyle.categoryIcon(poi.category),
                    color: AppColors.pureSurface, size: d * 0.55),
              ),
              if (visited)
                const Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: AppColors.pureSurface,
                    child: Icon(Icons.check_circle,
                        size: 18, color: AppColors.trailGreen),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacilityPin extends StatelessWidget {
  const _FacilityPin({
    super.key,
    required this.facility,
    required this.selected,
    required this.onTap,
  });

  final Facility facility;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = selected ? 36.0 : 28.0;
    return Semantics(
      button: true,
      label: facility.name,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              color: AppColors.slatePost,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.pureSurface, width: 2),
            ),
            child: Icon(MapStyle.facilityIcon(facility.type),
                color: AppColors.pureSurface, size: d * 0.6),
          ),
        ),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot({required this.weak});

  final bool weak;

  @override
  Widget build(BuildContext context) => Semantics(
        label: weak ? 'Posisi Anda, GPS lemah' : 'Posisi Anda',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: weak ? MapStyle.gpsWeakDot : AppColors.positionBlue,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.pureSurface, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.pineInk.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      );
}
