import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../application/basemap_loader.dart';
import '../application/map_scene.dart';
import '../domain/basemap.dart';
import '../map_providers.dart';
import 'map_style.dart';

LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lng);

/// Something drawn on the park map: a POI (tinted disc + label) or a facility (small disc).
class MapPin {
  const MapPin({
    required this.id,
    required this.position,
    required this.name,
    required this.color,
    required this.icon,
    this.isPoi = true,
    this.isGate = false,
    this.visited = false,
    this.radiusM = 25,
  });

  final String id;
  final GeoPoint position;
  final String name;
  final Color color;
  final IconData icon;
  final bool isPoi;
  final bool isGate;
  final bool visited;

  /// Geofence radius, drawn as the pulsing ring while approaching.
  final double radiusM;
}

/// Camera handle for [ParkMapView], so other modules never touch flutter_map directly (R5).
class ParkMapController {
  final MapController _map = MapController();
  AnimationController? _glide;

  double get zoom => _map.camera.zoom;
  GeoPoint get center =>
      GeoPoint(_map.camera.center.latitude, _map.camera.center.longitude);

  void move(GeoPoint target, double zoom) => _map.move(_ll(target), zoom);

  void fit(List<GeoPoint> points,
      {EdgeInsets padding = const EdgeInsets.all(40), double maxZoom = 18}) {
    if (points.length < 2) return;
    _map.fitCamera(CameraFit.coordinates(
      coordinates: [for (final p in points) _ll(p)],
      padding: padding,
      maxZoom: maxZoom,
    ));
  }

  /// Eased camera flight to [target].
  void glideTo(GeoPoint target,
      {required TickerProvider vsync,
      double? zoom,
      Duration duration = const Duration(milliseconds: 650)}) {
    final cam = _map.camera;
    final from = cam.center;
    final z0 = cam.zoom;
    final z1 = zoom ?? z0;
    _glide?.dispose();
    final c = AnimationController(vsync: vsync, duration: duration);
    _glide = c;
    final curve = CurvedAnimation(parent: c, curve: Curves.easeInOutCubic);
    curve.addListener(() {
      final v = curve.value;
      _map.move(
        LatLng(from.latitude + (target.lat - from.latitude) * v,
            from.longitude + (target.lng - from.longitude) * v),
        z0 + (z1 - z0) * v,
      );
    });
    c.forward();
  }

  void _stopGlide() {
    _glide?.stop();
  }

  void dispose() {
    _glide?.dispose();
    _glide = null;
    _map.dispose();
  }
}

/// The park map (A01): the bundled offline basemap (landcover, relief, contours, water, roads,
/// buildings) or online satellite imagery, the surveyed trail graph, place markers with label
/// collision, the walking route, geofence rings and the visitor's dot with accuracy and heading.
class ParkMapView extends ConsumerStatefulWidget {
  const ParkMapView({
    super.key,
    required this.pins,
    required this.user,
    this.headingDeg = 0,
    this.accuracyM,
    this.gpsWeak = false,
    this.showUser = true,
    this.trail = const [],
    this.overview = const [],
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
    this.satellite = false,
    this.onSatelliteError,
    this.followUser = false,
    this.onUserGesture,
    this.showChrome,
    this.chromeInsets = const EdgeInsets.fromLTRB(12, 12, 12, 12),
  });

  final List<MapPin> pins;
  final GeoPoint user;

  /// Compass/course heading; null hides the cone.
  final double? headingDeg;

  /// Horizontal accuracy of the latest fix (metres); null = no circle (demo mode).
  final double? accuracyM;

  /// Latest fix is weak (> 30 m) or old: grey dot, no cone (F01).
  final bool gpsWeak;

  /// False while there is no position at all (permission denied, no fix yet).
  final bool showUser;

  /// The visitor's walked line (sun yellow).
  final List<GeoPoint> trail;

  /// Points the first camera fit frames when there is no trail or route to fit.
  final List<GeoPoint> overview;
  final ParkMapController? controller;
  final String? selectedId;

  /// POI the visitor is approaching: pulsing geofence ring.
  final String? highlightId;
  final String? destinationId;
  final List<GeoPoint> route;
  final double walkedM;
  final ValueChanged<String>? onPlaceTap;
  final VoidCallback? onMapTap;
  final bool showFacilities;
  final bool showLabels;
  final bool interactive;
  final double initialZoom;
  final GeoPoint? initialCenter;
  final EdgeInsets fitPadding;

  /// Online satellite imagery instead of the vector landcover (needs internet).
  final bool satellite;

  /// Satellite tiles keep failing (offline): the screen should fall back to the vector map.
  final VoidCallback? onSatelliteError;

  /// Keep the camera on the visitor's dot.
  final bool followUser;

  /// The visitor panned or zoomed by hand (ends follow mode).
  final VoidCallback? onUserGesture;

  /// Scale bar, attribution and the off-screen position arrow. Defaults to [interactive].
  final bool? showChrome;

  /// Space the screen's own overlays take; the chrome stays inside it.
  final EdgeInsets chromeInsets;

  static const background = MapStyle.background;

  /// Esri World Imagery (online only; attribution shown on the map and in Tentang).
  static const satelliteUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  @override
  ConsumerState<ParkMapView> createState() => _ParkMapViewState();
}

class _ParkMapViewState extends ConsumerState<ParkMapView>
    with TickerProviderStateMixin {
  late final ParkMapController _controller =
      widget.controller ?? ParkMapController();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _draw = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  /// Smooth dot: glides from the previous fix to the new one instead of jumping every 3 s.
  late final AnimationController _dot =
      AnimationController(vsync: this, value: 1)..addListener(_onDotTick);
  late GeoPoint _dotFrom = widget.user;
  late GeoPoint _dotTo = widget.user;

  /// Time since the previous position (UI animation timing only, not domain time: R7).
  final Stopwatch _sinceMove = Stopwatch()..start();

  /// Facilities (toilet, musala, saung) only appear once zoomed in, so they never
  /// crowd the POI labels on the overview.
  static const _facilityZoom = 16.9;
  bool _closeUp = false;

  /// Integer zoom bucket (14–18): line widths and layer visibility only change per bucket, so
  /// the heavy basemap layers rebuild a handful of times instead of every frame.
  int _bucket = 16;
  final Map<String, List<Widget>> _layerCache = {};
  BasemapData? _cachedFor;

  int _satErrors = 0;
  bool _satReported = false;

  GeoPoint get _dotPosition {
    final t = Curves.easeOutCubic.transform(_dot.value);
    return GeoPoint(_dotFrom.lat + (_dotTo.lat - _dotFrom.lat) * t,
        _dotFrom.lng + (_dotTo.lng - _dotFrom.lng) * t);
  }

  @override
  void initState() {
    super.initState();
    _bucket = widget.initialZoom.floor().clamp(14, 18);
    if (widget.route.isNotEmpty) _draw.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (JTMotion.reduced(context)) {
      _pulse.stop();
      _draw.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(ParkMapView old) {
    super.didUpdateWidget(old);
    final changed = old.route.length != widget.route.length ||
        (widget.route.isNotEmpty &&
            old.route.isNotEmpty &&
            old.route.last != widget.route.last);
    if (changed && widget.route.isNotEmpty) _draw.forward(from: 0);
    if (old.user != widget.user) _moveDot(widget.user);
    if (widget.satellite && !old.satellite) {
      _satErrors = 0;
      _satReported = false;
    }
    if (widget.followUser && !old.followUser) {
      _controller.glideTo(_dotPosition,
          vsync: this, zoom: math.max(_controller.zoom, 17.2));
    }
  }

  void _moveDot(GeoPoint to) {
    final from = _dotPosition;
    final gap = _sinceMove.elapsed;
    _sinceMove.reset();
    if (JTMotion.reduced(context) || haversineM(from, to) > 250) {
      _dotFrom = to;
      _dotTo = to;
      _dot.value = 1;
      _onDotTick();
      return;
    }
    _dotFrom = from;
    _dotTo = to;
    // Glide over (roughly) the time between fixes: 3 s GPS → ~1 s glide; the fast demo walk
    // updates often, so its glide stays short and the dot never lags behind.
    _dot.duration = Duration(milliseconds: gap.inMilliseconds.clamp(120, 1000));
    _dot.forward(from: 0);
  }

  void _onDotTick() {
    if (widget.followUser && mounted) {
      _controller._map.move(_ll(_dotPosition), _controller.zoom);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _pulse.dispose();
    _draw.dispose();
    _dot.dispose();
    super.dispose();
  }

  void _onCamera(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _controller._stopGlide();
      widget.onUserGesture?.call();
    }
    final close = camera.zoom >= _facilityZoom;
    final bucket = camera.zoom.floor().clamp(14, 18);
    if (close == _closeUp && bucket == _bucket) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (close != _closeUp || bucket != _bucket) {
        setState(() {
          _closeUp = close;
          _bucket = bucket;
        });
      }
    });
  }

  void _onTileError(TileImage tile, Object error, StackTrace? stack) {
    if (!widget.satellite || _satReported) return;
    _satErrors++;
    if (_satErrors >= 3) {
      _satReported = true;
      widget.onSatelliteError?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scene = ref.watch(mapSceneProvider);
    final extent = scene.extent;
    final bounds = LatLngBounds(_ll(extent.southWest), _ll(extent.northEast));
    final basemap = scene.basemap;
    if (!identical(basemap, _cachedFor)) {
      _layerCache.clear();
      _cachedFor = basemap;
    }
    final chrome = widget.showChrome ?? widget.interactive;

    final places = widget.pins
        .where((p) =>
            p.isPoi ||
            p.id == widget.selectedId ||
            p.id == widget.destinationId ||
            (widget.showFacilities && _closeUp))
        .toList();
    MapPin? highlight;
    for (final p in widget.pins) {
      if (p.id == widget.highlightId) highlight = p;
    }

    final trail = widget.trail;
    final candidates = trail.length > 1
        ? trail
        : widget.route.length > 1
            ? widget.route
            : [...widget.overview, if (widget.showUser) widget.user];
    // a visitor far outside the park must not pull the first view off the map
    var fitTo = candidates.where(extent.contains).toList();
    if (fitTo.length < 2) fitTo = [scene.zone.southWest, scene.zone.northEast];

    final satellite = widget.satellite;
    final key = '$_bucket-$satellite';
    final base = _layerCache[key] ??= _baseLayers(scene, _bucket, satellite);

    return FlutterMap(
      mapController: _controller._map,
      options: MapOptions(
        initialCenter: _ll(widget.initialCenter ?? widget.user),
        initialZoom: widget.initialZoom,
        initialCameraFit: widget.initialCenter != null
            ? null
            : CameraFit.coordinates(
                coordinates: [for (final p in fitTo) _ll(p)],
                padding: widget.fitPadding,
                maxZoom: 17.6,
              ),
        cameraConstraint: CameraConstraint.containCenter(bounds: bounds),
        minZoom: 14,
        maxZoom: 19.5,
        backgroundColor:
            satellite ? const Color(0xFF2B3A2E) : MapStyle.background,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        onTap: (_, __) => widget.onMapTap?.call(),
        onPositionChanged: _onCamera,
      ),
      children: [
        if (satellite)
          TileLayer(
            urlTemplate: ParkMapView.satelliteUrl,
            userAgentPackageName: 'id.ac.itb.kel5.jelajah_taman',
            maxNativeZoom: 19,
            errorTileCallback: _onTileError,
          ),
        ...base,
        // visitor's walked trail
        if (trail.length >= 2)
          PolylineLayer(polylines: [
            Polyline(
              points: [for (final p in trail) _ll(p)],
              strokeWidth: 5,
              color: JT.sun,
              borderStrokeWidth: satellite ? 1.5 : 0,
              borderColor: Colors.black.withValues(alpha: 0.35),
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ),
          ]),
        if (widget.route.length >= 2)
          AnimatedBuilder(
            animation: _draw,
            builder: (context, _) => PolylineLayer(polylines: _routeLines()),
          ),
        if (highlight case final highlight?)
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final r = highlight.radiusM;
              final t = _pulse.value;
              return CircleLayer(circles: [
                CircleMarker(
                  point: _ll(highlight.position),
                  radius: r + scene.approachMarginM,
                  useRadiusInMeter: true,
                  color: highlight.color.withValues(alpha: 0.08),
                  borderColor: highlight.color.withValues(alpha: 0.35),
                  borderStrokeWidth: 1.5,
                ),
                CircleMarker(
                  point: _ll(highlight.position),
                  radius: r * (0.6 + 0.9 * t),
                  useRadiusInMeter: true,
                  color: highlight.color.withValues(alpha: 0.22 * (1 - t)),
                ),
                CircleMarker(
                  point: _ll(highlight.position),
                  radius: r,
                  useRadiusInMeter: true,
                  color: Colors.transparent,
                  borderColor: highlight.color,
                  borderStrokeWidth: 2,
                ),
              ]);
            },
          ),
        if (widget.showUser)
          AnimatedBuilder(
            animation: _dot,
            builder: (context, _) {
              final acc = widget.accuracyM;
              if (acc == null || acc < 4) return const SizedBox.shrink();
              final c = widget.gpsWeak ? MapStyle.gpsWeakDot : JT.sky;
              return CircleLayer(circles: [
                CircleMarker(
                  point: _ll(_dotPosition),
                  radius: acc,
                  useRadiusInMeter: true,
                  color: c.withValues(alpha: widget.gpsWeak ? 0.14 : 0.12),
                  borderColor: c.withValues(alpha: 0.4),
                  borderStrokeWidth: 1,
                ),
              ]);
            },
          ),
        _PinLayer(
          places: places,
          selectedId: widget.selectedId,
          destinationId: widget.destinationId,
          highlightId: widget.highlightId,
          showLabels: widget.showLabels,
          onPlaceTap: widget.onPlaceTap,
        ),
        if (widget.showUser)
          AnimatedBuilder(
            animation: _dot,
            builder: (context, _) => MarkerLayer(markers: [
              Marker(
                point: _ll(_dotPosition),
                width: 120,
                height: 120,
                child: IgnorePointer(
                  child: UserDot(
                    headingDeg: widget.headingDeg ?? 0,
                    showHeading: widget.headingDeg != null && !widget.gpsWeak,
                    weak: widget.gpsWeak,
                  ),
                ),
              ),
            ]),
          ),
        if (chrome) ...[
          if (widget.showUser)
            AnimatedBuilder(
              animation: _dot,
              builder: (context, _) => _OffscreenUser(
                user: _dotPosition,
                insets: widget.chromeInsets,
                onTap: () {
                  if (extent.contains(_dotPosition)) {
                    _controller.glideTo(_dotPosition, vsync: this, zoom: 17.2);
                  }
                },
              ),
            ),
          _MapChrome(insets: widget.chromeInsets, satellite: satellite),
        ],
      ],
    );
  }

  // ---- basemap ------------------------------------------------------------------------------

  List<Widget> _baseLayers(MapScene scene, int z, bool satellite) {
    final bm = scene.basemap;
    final prep = bm == null ? null : _Prepared.of(bm);
    final zf = z.toDouble();
    double w(double base, {double min = 0.6}) =>
        MapStyle.scaled(base, zf, min: min);
    final trails = [for (final t in scene.trails) t.map(_ll).toList()];

    final out = <Widget>[];
    if (prep != null && !satellite) {
      out
        ..add(PolygonLayer(polygons: prep.landcover))
        ..add(PolygonLayer(polygons: [
          for (final r in prep.boundary)
            Polygon(points: r, color: MapStyle.parkTint),
        ]));
      if (prep.hillshade case final h?) {
        out.add(OverlayImageLayer(overlayImages: [
          OverlayImage(
              bounds: h,
              imageProvider: AssetImage(prep.hillshadeAsset!),
              opacity: 0.45),
        ]));
      }
      out
        ..add(PolygonLayer(polygons: prep.water))
        ..add(PolylineLayer(polylines: [
          for (final c in prep.contours)
            if (c.index || z >= 15)
              Polyline(
                points: c.points,
                strokeWidth: c.index ? w(1.1, min: 0.7) : w(0.6, min: 0.4),
                color:
                    MapStyle.contour.withValues(alpha: c.index ? 0.34 : 0.18),
              ),
        ]))
        ..add(PolylineLayer(polylines: [
          for (final l in prep.waterways)
            if (l.kind != 'stream' || z >= 15)
              Polyline(
                points: l.points,
                strokeWidth: w(
                    switch (l.kind) {
                      'river' => 3.2,
                      'canal' => 1.8,
                      _ => 1.4
                    },
                    min: 0.8),
                color: MapStyle.waterEdge,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
        ]))
        ..add(PolylineLayer(polylines: [
          for (final r in prep.boundary) ...[
            Polyline(
                points: r,
                strokeWidth: w(9, min: 5),
                color: MapStyle.parkEdge.withValues(alpha: 0.10)),
            Polyline(
              points: r,
              strokeWidth: w(1.6, min: 1.2),
              color: MapStyle.parkEdge.withValues(alpha: 0.75),
              pattern: StrokePattern.dashed(segments: const [9, 5]),
            ),
          ],
        ]));
      final roads = [
        for (final r in prep.roads)
          if (_roadVisible(r.kind, z)) r
      ];
      out
        ..add(PolylineLayer(polylines: [
          for (final r in roads)
            Polyline(
              points: r.points,
              strokeWidth: w(_roadWidth(r.kind)) + 2,
              color: MapStyle.roadCasing,
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ),
        ]))
        ..add(PolylineLayer(polylines: [
          for (final r in roads)
            Polyline(
              points: r.points,
              strokeWidth: w(_roadWidth(r.kind)),
              color: r.kind == 'secondary' || r.kind == 'tertiary'
                  ? MapStyle.majorRoadFill
                  : MapStyle.roadFill,
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ),
        ]));
      if (z >= 16) out.add(PolygonLayer(polygons: prep.buildings));
      if (z >= 15) {
        out.add(PolylineLayer(polylines: [
          for (final p in prep.paths)
            Polyline(
              points: p.points,
              strokeWidth: w(p.kind == 'steps' ? 2.4 : 1.4, min: 1),
              color: MapStyle.footpath.withValues(alpha: 0.75),
              pattern: p.kind == 'steps'
                  ? StrokePattern.dashed(segments: const [1.5, 2.5])
                  : StrokePattern.dashed(segments: const [4, 3]),
            ),
        ]));
      }
    } else if (prep != null && satellite) {
      out.add(PolylineLayer(polylines: [
        for (final r in prep.boundary)
          Polyline(
            points: r,
            strokeWidth: 1.8,
            color: Colors.white.withValues(alpha: 0.85),
            pattern: StrokePattern.dashed(segments: const [9, 5]),
          ),
      ]));
    }

    // surveyed trail graph: casing + warm sand core (the walkable network the router uses)
    out
      ..add(PolylineLayer(polylines: [
        for (final t in trails)
          Polyline(
            points: t,
            strokeWidth: w(8, min: 4.5),
            color: satellite
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.92),
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),
      ]))
      ..add(PolylineLayer(polylines: [
        for (final t in trails)
          Polyline(
            points: t,
            strokeWidth: w(3, min: 2),
            color: satellite ? const Color(0xFFFFE3A8) : MapStyle.trailCore,
            pattern: StrokePattern.dashed(segments: const [7, 5]),
            strokeCap: StrokeCap.round,
          ),
      ]));

    if (prep != null) {
      final labels = <Marker>[
        if (z >= 15)
          for (final l in prep.waterLabels)
            // a POI already names this lake: its marker label is enough
            if (!scene.pois.any((p) => p.name.contains(l.text)))
              _labelMarker(l, satellite,
                  size: 11, italic: true, color: MapStyle.waterText),
        if (z >= 16)
          for (final l in prep.waterwayLabels)
            _labelMarker(l, satellite,
                size: 10, italic: true, color: MapStyle.waterText),
        if (z >= 16 && !satellite)
          for (final l in prep.contourLabels)
            _labelMarker(l, satellite,
                size: 9, color: MapStyle.contour.withValues(alpha: 0.9)),
      ];
      if (labels.isNotEmpty) {
        out.add(MarkerLayer(markers: labels, rotate: false));
      }
    }
    return out;
  }

  static bool _roadVisible(String kind, int z) => switch (kind) {
        'secondary' || 'tertiary' => true,
        'unclassified' || 'residential' => z >= 15,
        _ => z >= 16, // living_street, service, track
      };

  static double _roadWidth(String kind) => switch (kind) {
        'secondary' => 7,
        'tertiary' => 6,
        'unclassified' => 4.6,
        'residential' => 4.2,
        'living_street' => 3.6,
        'track' => 2.4,
        _ => 3, // service
      };

  Marker _labelMarker(_LineLabel l, bool satellite,
      {required double size, bool italic = false, required Color color}) {
    final width = l.text.length * size * 0.62 + 16;
    return Marker(
      point: l.point,
      width: width,
      height: size * 2.4,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: l.angle,
          child: Center(
            child: _HaloText(
              l.text,
              size: size,
              italic: italic,
              color: satellite ? Colors.white : color,
              halo: satellite
                  ? Colors.black.withValues(alpha: 0.6)
                  : MapStyle.background.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }

  List<Polyline> _routeLines() {
    final pts = widget.route;
    // split at walkedM: walked part faded, remaining part bold forest; drawn in progressively.
    var acc = 0.0;
    final done = <LatLng>[_ll(pts.first)];
    final todo = <LatLng>[];
    var split = false;
    for (var i = 1; i < pts.length; i++) {
      final seg = haversineM(pts[i - 1], pts[i]);
      if (!split && acc + seg >= widget.walkedM) {
        final f = seg == 0 ? 0.0 : (widget.walkedM - acc) / seg;
        final mid = GeoPoint(pts[i - 1].lat + (pts[i].lat - pts[i - 1].lat) * f,
            pts[i - 1].lng + (pts[i].lng - pts[i - 1].lng) * f);
        done.add(_ll(mid));
        todo
          ..add(_ll(mid))
          ..add(_ll(pts[i]));
        split = true;
      } else if (split) {
        todo.add(_ll(pts[i]));
      } else {
        done.add(_ll(pts[i]));
      }
      acc += seg;
    }
    // draw-on: reveal a fraction of the remaining line
    final t = Curves.easeInOutCubic.transform(_draw.value);
    final shown = todo.isEmpty
        ? <LatLng>[]
        : todo.sublist(
            0, math.max(2, (todo.length * t).ceil()).clamp(0, todo.length));
    return [
      if (done.length >= 2)
        Polyline(
            points: done,
            strokeWidth: 6,
            color: JT.forest.withValues(alpha: 0.28),
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round),
      if (shown.length >= 2) ...[
        Polyline(
            points: shown,
            strokeWidth: 11,
            color: Colors.white,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round),
        Polyline(
            points: shown,
            strokeWidth: 6.5,
            color: JT.forest,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round),
      ],
    ];
  }
}

// ---- prepared basemap geometry (computed once per BasemapData) -----------------------------

class _Line {
  const _Line(this.kind, this.points, {this.index = false});
  final String kind;
  final List<LatLng> points;
  final bool index;
}

class _LineLabel {
  const _LineLabel(this.text, this.point, this.angle);
  final String text;
  final LatLng point;
  final double angle;
}

class _Prepared {
  _Prepared(BasemapData b)
      : landcover = [
          for (final a in b.landcover)
            Polygon(
              points: a.ring.map(_ll).toList(),
              holePointsList: a.holes.isEmpty
                  ? null
                  : [for (final h in a.holes) h.map(_ll).toList()],
              color: MapStyle.landcover(a.kind),
            ),
        ],
        water = [
          for (final a in b.water)
            Polygon(
              points: a.ring.map(_ll).toList(),
              holePointsList: a.holes.isEmpty
                  ? null
                  : [for (final h in a.holes) h.map(_ll).toList()],
              color: MapStyle.water,
              borderColor: MapStyle.waterEdge,
              borderStrokeWidth: 1,
            ),
        ],
        buildings = [
          for (final a in b.buildings)
            Polygon(
              points: a.ring.map(_ll).toList(),
              color: MapStyle.building,
              borderColor: MapStyle.buildingEdge,
              borderStrokeWidth: 0.6,
            ),
        ],
        boundary = [for (final r in b.boundary) r.map(_ll).toList()],
        waterways = [
          for (final l in b.waterways) _Line(l.kind, l.points.map(_ll).toList())
        ],
        roads = [
          for (final l in b.roads) _Line(l.kind, l.points.map(_ll).toList())
        ],
        paths = [
          for (final l in b.paths) _Line(l.kind, l.points.map(_ll).toList())
        ],
        contours = [
          for (final c in b.contours)
            _Line('contour', c.points.map(_ll).toList(),
                index: b.isIndexContour(c))
        ],
        waterLabels = [
          for (final l in b.labels)
            if (l.kind == 'water') _LineLabel(l.text, _ll(l.position), 0)
        ],
        waterwayLabels = _waterwayLabels(b),
        contourLabels = _contourLabels(b),
        hillshade = b.hillshadeBounds == null
            ? null
            : LatLngBounds(_ll(b.hillshadeBounds!.southWest),
                _ll(b.hillshadeBounds!.northEast)),
        hillshadeAsset = b.hillshadeFile == null
            ? null
            : '${basemapAsset.substring(0, basemapAsset.lastIndexOf('/'))}/${b.hillshadeFile}';

  static final _cache = Expando<_Prepared>();
  static _Prepared of(BasemapData b) => _cache[b] ??= _Prepared(b);

  final List<Polygon> landcover;
  final List<Polygon> water;
  final List<Polygon> buildings;
  final List<List<LatLng>> boundary;
  final List<_Line> waterways;
  final List<_Line> roads;
  final List<_Line> paths;
  final List<_Line> contours;
  final List<_LineLabel> waterLabels;
  final List<_LineLabel> waterwayLabels;
  final List<_LineLabel> contourLabels;
  final LatLngBounds? hillshade;
  final String? hillshadeAsset;

  /// One label per named river/canal stretch longer than 250 m, at its middle, rotated along
  /// it; repeats of the same name closer than 450 m are dropped.
  static List<_LineLabel> _waterwayLabels(BasemapData b) {
    final out = <_LineLabel>[];
    final placed = <String, List<GeoPoint>>{};
    final named = [
      for (final l in b.waterways)
        if (l.name != null && l.name!.isNotEmpty) l
    ]..sort((a, b) => _length(b.points).compareTo(_length(a.points)));
    for (final l in named) {
      if (_length(l.points) < 250) continue;
      final (p, a) = _midpoint(l.points);
      final seen = placed.putIfAbsent(l.name!, () => []);
      if (seen.any((s) => haversineM(s, p) < 450)) continue;
      seen.add(p);
      out.add(_LineLabel(l.name!, _ll(p), a));
    }
    return out;
  }

  /// Elevation labels on index contours (every 50 m), one per contour longer than 400 m.
  static List<_LineLabel> _contourLabels(BasemapData b) {
    final out = <_LineLabel>[];
    for (final c in b.contours) {
      if (!b.isIndexContour(c) || _length(c.points) < 400) continue;
      final (p, a) = _midpoint(c.points);
      out.add(_LineLabel('${c.elevationM!.round()}', _ll(p), a));
      if (out.length >= 60) break;
    }
    return out;
  }

  static double _length(List<GeoPoint> pts) {
    var s = 0.0;
    for (var i = 1; i < pts.length; i++) {
      s += haversineM(pts[i - 1], pts[i]);
    }
    return s;
  }

  /// The point halfway along [pts] and the screen angle of the line there (kept upright).
  static (GeoPoint, double) _midpoint(List<GeoPoint> pts) {
    final half = _length(pts) / 2;
    var acc = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final seg = haversineM(pts[i - 1], pts[i]);
      if (acc + seg >= half) {
        final f = seg == 0 ? 0.0 : (half - acc) / seg;
        final p = GeoPoint(pts[i - 1].lat + (pts[i].lat - pts[i - 1].lat) * f,
            pts[i - 1].lng + (pts[i].lng - pts[i - 1].lng) * f);
        final a = pts[math.max(0, i - 3)];
        final b = pts[math.min(pts.length - 1, i + 2)];
        return (p, _screenAngle(a, b));
      }
      acc += seg;
    }
    return (pts.first, 0);
  }

  static double _screenAngle(GeoPoint a, GeoPoint b) {
    final dx = (b.lng - a.lng) * math.cos(a.lat * math.pi / 180);
    final dy = -(b.lat - a.lat);
    var ang = math.atan2(dy, dx);
    if (ang > math.pi / 2) {
      ang -= math.pi;
    } else if (ang < -math.pi / 2) {
      ang += math.pi;
    }
    return ang;
  }
}

/// Text with a soft outline so it stays legible over relief, roads or imagery.
class _HaloText extends StatelessWidget {
  const _HaloText(this.text,
      {required this.size,
      required this.color,
      required this.halo,
      this.italic = false});

  final String text;
  final double size;
  final Color color;
  final Color halo;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    TextStyle style({Color? c, Paint? fg}) => TextStyle(
          fontFamily: JTText.caption.fontFamily,
          fontSize: size,
          fontWeight: FontWeight.w600,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          letterSpacing: 0.3,
          color: c,
          foreground: fg,
          height: 1,
        );
    return Stack(
      children: [
        Text(text,
            maxLines: 1,
            softWrap: false,
            style: style(
                fg: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..strokeJoin = StrokeJoin.round
                  ..color = halo)),
        Text(text, maxLines: 1, softWrap: false, style: style(c: color)),
      ],
    );
  }
}

// ---- markers with label collision ---------------------------------------------------------

/// Place markers. Labels are placed greedily in screen space by priority (selected >
/// destination > approaching > POIs in route order) and skipped where they would cover another
/// label or marker (#21). The selected marker is drawn last, on top.
class _PinLayer extends StatelessWidget {
  const _PinLayer({
    required this.places,
    required this.selectedId,
    required this.destinationId,
    required this.highlightId,
    required this.showLabels,
    required this.onPlaceTap,
  });

  final List<MapPin> places;
  final String? selectedId;
  final String? destinationId;
  final String? highlightId;
  final bool showLabels;
  final ValueChanged<String>? onPlaceTap;

  int _rank(MapPin p) {
    if (p.id == selectedId) return 0;
    if (p.id == destinationId) return 1;
    if (p.id == highlightId) return 2;
    if (p.isPoi && !p.isGate) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final cam = MapCamera.of(context);
    final n = places.length;
    final offsets = [
      for (final p in places) cam.latLngToScreenOffset(_ll(p.position))
    ];
    // the disc sits ~11 px above the anchor (marker box is centred on the point)
    final discs = [
      for (var i = 0; i < n; i++)
        Rect.fromCenter(
            center: offsets[i].translate(0, -11),
            width: places[i].isPoi ? 40 : 30,
            height: places[i].isPoi ? 40 : 30),
    ];
    final order = List.generate(n, (i) => i)
      ..sort((a, b) => _rank(places[a]).compareTo(_rank(places[b])));
    final labelOn = List.filled(n, false);
    final taken = <Rect>[];
    for (final i in order) {
      final p = places[i];
      final rank = _rank(p);
      if (!showLabels || rank > 3) continue;
      final w =
          math.min(124.0, PlaceMarker.shortName(p.name).length * 6.4 + 18);
      final r = Rect.fromLTWH(offsets[i].dx - w / 2, offsets[i].dy + 16, w, 21)
          .inflate(2);
      final hit = taken.any(r.overlaps) ||
          [
            for (var j = 0; j < n; j++)
              if (j != i && _rank(places[j]) <= rank) discs[j]
          ].any(r.overlaps);
      if (rank <= 1 || !hit) {
        labelOn[i] = true;
        taken.add(r);
      }
    }
    // paint order: lowest priority first so the selected marker ends on top
    final paint = List.generate(n, (i) => i)
      ..sort((a, b) => _rank(places[b]).compareTo(_rank(places[a])));
    return MarkerLayer(
      rotate: false,
      markers: [
        for (final i in paint)
          Marker(
            key: ValueKey('pin-${places[i].id}'),
            point: _ll(places[i].position),
            width: 132,
            height: 96,
            alignment: Alignment.center,
            child: PlaceMarker(
              key: ValueKey(places[i].id),
              pin: places[i],
              index: i,
              selected:
                  places[i].id == selectedId || places[i].id == destinationId,
              visited: places[i].visited,
              showLabel: labelOn[i],
              onTap:
                  onPlaceTap == null ? null : () => onPlaceTap!(places[i].id),
            ),
          ),
      ],
    );
  }
}

// ---- screen chrome -----------------------------------------------------------------------

/// Arrow at the screen edge pointing at the visitor when the dot is out of view.
class _OffscreenUser extends StatelessWidget {
  const _OffscreenUser(
      {required this.user, required this.insets, required this.onTap});

  final GeoPoint user;
  final EdgeInsets insets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cam = MapCamera.of(context);
    final size = cam.nonRotatedSize;
    final o = cam.latLngToScreenOffset(_ll(user));
    final view = (Offset.zero & size).deflate(8);
    if (view.contains(o)) return const SizedBox.shrink();
    final box = Rect.fromLTRB(insets.left + 26, insets.top + 26,
        size.width - insets.right - 26, size.height - insets.bottom - 26);
    if (box.width <= 0 || box.height <= 0) return const SizedBox.shrink();
    final c = box.center;
    final d = o - c;
    // intersect the ray centre → user with the inset box
    final sx = d.dx == 0 ? double.infinity : (box.width / 2) / d.dx.abs();
    final sy = d.dy == 0 ? double.infinity : (box.height / 2) / d.dy.abs();
    final pos = c + d * math.min(sx, sy);
    final centre = cam.center;
    final dist = haversineM(GeoPoint(centre.latitude, centre.longitude), user);
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            left: pos.dx - 26,
            top: pos.dy - 26,
            width: 52,
            height: 52,
            child: Pressable(
              onTap: onTap,
              semanticLabel: 'Posisi Anda ${_km(dist)}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Transform.rotate(
                      angle: math.atan2(d.dy, d.dx) + math.pi / 2,
                      child: const Icon(Icons.navigation_rounded,
                          size: 18, color: JT.sky),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: JT.ink.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(_km(dist),
                        style: JTText.caption.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _km(double m) => m < 1000
      ? '${(m / 10).round() * 10} m'
      : '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Scale bar + attribution (OpenStreetMap ODbL; Esri imagery on satellite).
class _MapChrome extends StatelessWidget {
  const _MapChrome({required this.insets, required this.satellite});

  final EdgeInsets insets;
  final bool satellite;

  @override
  Widget build(BuildContext context) {
    final fg = satellite ? Colors.white : JT.ink;
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            left: insets.left,
            bottom: insets.bottom,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                decoration: BoxDecoration(
                  color: (satellite ? Colors.black : Colors.white)
                      .withValues(alpha: satellite ? 0.45 : 0.78),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Scalebar(
                      alignment: Alignment.topLeft,
                      padding: EdgeInsets.zero,
                      length: ScalebarLength.s,
                      lineColor: fg,
                      strokeWidth: 1.5,
                      lineHeight: 4,
                      textStyle: JTText.caption.copyWith(
                          color: fg, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      satellite
                          ? 'Citra © Esri · © OpenStreetMap'
                          : '© OpenStreetMap',
                      style: JTText.caption.copyWith(
                          color: fg.withValues(alpha: 0.8), fontSize: 8.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bubbly marker: POIs are tinted discs, facilities small white discs. Pops in with a stagger.
class PlaceMarker extends StatelessWidget {
  const PlaceMarker({
    super.key,
    required this.pin,
    required this.index,
    required this.selected,
    required this.visited,
    required this.showLabel,
    this.onTap,
  });

  final MapPin pin;
  final int index;
  final bool selected;
  final bool visited;
  final bool showLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final poi = pin.isPoi;
    final size = poi ? 44.0 : 34.0;
    final disc = AnimatedScale(
      scale: selected ? 1.22 : 1,
      duration: JTMotion.slow,
      curve: JTMotion.pop,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: JTMotion.base,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: poi ? pin.color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? JT.sun : (poi ? Colors.white : pin.color),
                  width: selected ? 4 : (poi ? 3 : 2)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(pin.icon,
                size: poi ? 22 : 18, color: poi ? Colors.white : pin.color),
          ),
          if (visited)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: JT.leaf,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check_rounded,
                    size: 11, color: Colors.white),
              ),
            ),
        ],
      ),
    );
    return Entrance(
      delay: JTMotion.stagger * index,
      offset: const Offset(0, 10),
      scaleFrom: 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pressable(
            onTap: onTap,
            scale: 0.88,
            semanticLabel: pin.name,
            child: Padding(padding: const EdgeInsets.all(4), child: disc),
          ),
          AnimatedOpacity(
            opacity: showLabel ? 1 : 0,
            duration: JTMotion.base,
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? JT.ink : Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                shortName(pin.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: JTText.caption.copyWith(
                    color: selected ? Colors.white : JT.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String shortName(String n) => n
      .replaceAll('Ir. H. ', '')
      .replaceAll('Kawasan ', '')
      .replaceAll(' / Piknik', '')
      .replaceAll('Titik ', '');
}

/// The visitor: blue dot, white ring, soft pulse and a heading cone. Grey and still when the
/// GPS is weak (F01).
class UserDot extends StatelessWidget {
  const UserDot(
      {super.key,
      required this.headingDeg,
      this.showHeading = true,
      this.weak = false});

  final double headingDeg;
  final bool showHeading;
  final bool weak;

  @override
  Widget build(BuildContext context) {
    final c = weak ? MapStyle.gpsWeakDot : JT.sky;
    final dot = Stack(
      alignment: Alignment.center,
      children: [
        if (showHeading)
          Transform.rotate(
            angle: headingDeg * math.pi / 180,
            child:
                CustomPaint(size: const Size(64, 64), painter: _ConePainter(c)),
          ),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)
            ],
          ),
        ),
      ],
    );
    return weak
        ? SizedBox(width: 120, height: 120, child: Center(child: dot))
        : PulseRings(color: c, size: 120, child: dot);
  }
}

class _ConePainter extends CustomPainter {
  const _ConePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx - 15, c.dy - 30)
      ..quadraticBezierTo(c.dx, c.dy - 36, c.dx + 15, c.dy - 30)
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: 34)),
    );
  }

  @override
  bool shouldRepaint(covariant _ConePainter old) => old.color != color;
}
