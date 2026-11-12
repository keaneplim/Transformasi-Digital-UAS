import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../domain/map_geometry.dart';
import '../map_providers.dart';

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

  void dispose() {
    _glide?.dispose();
    _glide = null;
    _map.dispose();
  }
}

/// The illustrated park map: procedural terrain (until offline tiles land, T05), footpaths
/// from the trail graph, bubbly place markers, the walking route and the visitor's dot.
class ParkMapView extends ConsumerStatefulWidget {
  const ParkMapView({
    super.key,
    required this.pins,
    required this.user,
    this.headingDeg = 0,
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
  });

  final List<MapPin> pins;
  final GeoPoint user;
  final double headingDeg;

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

  static const background = Color(0xFFEFF1DA);

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
  List<Polygon>? _terrain;
  List<Marker>? _trees;

  /// Facilities (toilet, musala, saung) only appear once zoomed in, so they never
  /// crowd the POI labels on the overview.
  static const _facilityZoom = 16.9;
  bool _closeUp = false;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _pulse.dispose();
    _draw.dispose();
    super.dispose();
  }

  // ---- procedural terrain: wobbly contour "hills" in geo coordinates ----------------------
  List<Polygon> _buildTerrain(GeoBounds zone) {
    final rnd = math.Random(42);
    final polys = <Polygon>[];
    final latSpan = zone.north - zone.south;
    final lngSpan = zone.east - zone.west;
    const mPerDegLat = 111320.0;
    final mPerDegLng = 111320.0 * math.cos(zone.center.lat * math.pi / 180);
    for (var h = 0; h < 7; h++) {
      final c = GeoPoint(zone.south + latSpan * (0.1 + 0.8 * rnd.nextDouble()),
          zone.west + lngSpan * (0.1 + 0.8 * rnd.nextDouble()));
      final base = 180 + rnd.nextDouble() * 260;
      final phase = rnd.nextDouble() * 6;
      for (var ring = 0; ring < 5; ring++) {
        final r = base * (1 - ring * 0.19);
        final pts = <LatLng>[];
        for (var i = 0; i < 48; i++) {
          final a = i / 48 * math.pi * 2;
          final wob = 1 +
              0.16 * math.sin(a * 3 + phase + ring * 0.4) +
              0.08 * math.sin(a * 5 + phase * 2);
          pts.add(LatLng(c.lat + r * wob * math.sin(a) / mPerDegLat,
              c.lng + r * wob * 1.25 * math.cos(a) / mPerDegLng));
        }
        polys.add(Polygon(
          points: pts,
          color: const Color(0xFF8DB26A).withValues(alpha: 0.10 + ring * 0.035),
          borderColor: const Color(0xFF7D9E5C).withValues(alpha: 0.28),
          borderStrokeWidth: 1,
        ));
      }
    }
    return polys;
  }

  List<Marker> _buildTrees(GeoBounds zone, List<GeoPoint> avoid) {
    final rnd = math.Random(9);
    final out = <Marker>[];
    var tries = 0;
    while (out.length < 70 && tries < 800) {
      tries++;
      final p = GeoPoint(
          zone.south + (zone.north - zone.south) * rnd.nextDouble(),
          zone.west + (zone.east - zone.west) * rnd.nextDouble());
      if (avoid.any((a) => haversineM(a, p) < 45)) continue;
      final s = 15.0 + rnd.nextDouble() * 9;
      out.add(Marker(
        point: _ll(p),
        width: s,
        height: s,
        child: IgnorePointer(
          child: DoodleIcon(Doodle.pine,
              size: s,
              color: const Color(0xFF6E9150).withValues(alpha: 0.55),
              stroke: 1.6),
        ),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scene = ref.watch(mapSceneProvider);
    final zone = scene.zone;
    final bounds = LatLngBounds(_ll(zone.southWest), _ll(zone.northEast));
    _terrain ??= _buildTerrain(zone);
    final trails = scene.trails;
    _trees ??= _buildTrees(zone, [
      for (final t in trails) ...t,
      for (final p in widget.pins) p.position,
    ]);

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
    final fitTo = trail.length > 1
        ? trail
        : widget.route.length > 1
            ? widget.route
            : [...widget.overview, widget.user];

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
        minZoom: 14.5,
        maxZoom: 19.5,
        backgroundColor: ParkMapView.background,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        onTap: (_, __) => widget.onMapTap?.call(),
        onPositionChanged: (camera, _) {
          final close = camera.zoom >= _facilityZoom;
          if (close == _closeUp) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && close != _closeUp) setState(() => _closeUp = close);
          });
        },
      ),
      children: [
        PolygonLayer(polygons: _terrain!, simplificationTolerance: 0),
        MarkerLayer(markers: _trees!),
        // footpaths: white casing + warm sand core
        PolylineLayer(polylines: [
          for (final t in trails)
            Polyline(
              points: [for (final p in t) _ll(p)],
              strokeWidth: 9,
              color: Colors.white.withValues(alpha: 0.9),
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ),
        ]),
        PolylineLayer(polylines: [
          for (final t in trails)
            Polyline(
              points: [for (final p in t) _ll(p)],
              strokeWidth: 3.2,
              color: const Color(0xFFCDB27C),
              pattern: StrokePattern.dashed(segments: const [7, 6]),
              strokeCap: StrokeCap.round,
            ),
        ]),
        // visitor's walked trail
        if (trail.length >= 2)
          PolylineLayer(polylines: [
            Polyline(
              points: [for (final p in trail) _ll(p)],
              strokeWidth: 5,
              color: JT.sun,
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
                  radius: r + 30,
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
        MarkerLayer(
          rotate: false,
          markers: [
            for (final (i, p) in places.indexed)
              Marker(
                point: _ll(p.position),
                width: 132,
                height: 96,
                alignment: Alignment.center,
                child: PlaceMarker(
                  key: ValueKey(p.id),
                  pin: p,
                  index: i,
                  selected:
                      p.id == widget.selectedId || p.id == widget.destinationId,
                  visited: p.visited,
                  showLabel: widget.showLabels &&
                      (p.id == widget.selectedId ||
                          p.id == widget.destinationId ||
                          p.id == widget.highlightId ||
                          (p.isPoi && !p.isGate)),
                  onTap: widget.onPlaceTap == null
                      ? null
                      : () => widget.onPlaceTap!(p.id),
                ),
              ),
            Marker(
              point: _ll(widget.user),
              width: 120,
              height: 120,
              child:
                  IgnorePointer(child: UserDot(headingDeg: widget.headingDeg)),
            ),
          ],
        ),
      ],
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
                _short(pin.name),
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

  static String _short(String n) => n
      .replaceAll('Ir. H. ', '')
      .replaceAll('Kawasan ', '')
      .replaceAll(' / Piknik', '')
      .replaceAll('Titik ', '');
}

/// The visitor: blue dot, white ring, soft pulse and a heading cone.
class UserDot extends StatelessWidget {
  const UserDot({super.key, required this.headingDeg});

  final double headingDeg;

  @override
  Widget build(BuildContext context) => PulseRings(
        color: JT.sky,
        size: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: headingDeg * math.pi / 180,
              child: CustomPaint(
                  size: const Size(64, 64), painter: _ConePainter()),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: JT.sky,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
            ),
          ],
        ),
      );
}

class _ConePainter extends CustomPainter {
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
          colors: [JT.sky.withValues(alpha: 0.45), JT.sky.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: 34)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
