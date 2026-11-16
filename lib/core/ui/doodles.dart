import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'motion.dart';

/// Hand-drawn forest doodles, authored on a 24×24 grid as stroke paths.
/// Used as a drifting pattern on the sun band (Sliq-style) and as small spot icons.
enum Doodle {
  pine,
  cave,
  deer,
  leaf,
  compass,
  headphones,
  footprints,
  sun,
  mountain,
  butterfly,
  bench,
  drop,
  map,
  sparkle,
  mushroom,
  binoculars,
}

Path doodlePath(Doodle d) {
  final p = Path();
  switch (d) {
    case Doodle.pine:
      p
        ..moveTo(12, 2.5)
        ..lineTo(7, 9)
        ..lineTo(9.5, 9)
        ..lineTo(5.5, 14.5)
        ..lineTo(8.5, 14.5)
        ..lineTo(4.5, 19.5)
        ..lineTo(19.5, 19.5)
        ..lineTo(15.5, 14.5)
        ..lineTo(18.5, 14.5)
        ..lineTo(14.5, 9)
        ..lineTo(17, 9)
        ..close()
        ..moveTo(12, 19.5)
        ..lineTo(12, 22.5);
    case Doodle.cave:
      p
        ..moveTo(2, 21)
        ..lineTo(22, 21)
        ..moveTo(4, 21)
        ..cubicTo(4, 9, 8, 4, 12, 4)
        ..cubicTo(16, 4, 20, 9, 20, 21)
        ..moveTo(8.5, 21)
        ..cubicTo(8.5, 15, 10, 12, 12, 12)
        ..cubicTo(14, 12, 15.5, 15, 15.5, 21)
        ..moveTo(6.5, 8.5)
        ..lineTo(8, 9.5)
        ..moveTo(17.5, 8.5)
        ..lineTo(16, 9.5);
    case Doodle.deer:
      p
        ..addOval(Rect.fromCenter(
            center: const Offset(12, 15), width: 7, height: 8.5))
        ..moveTo(10, 11.5)
        ..lineTo(8, 7)
        ..lineTo(5, 5)
        ..moveTo(8, 7)
        ..lineTo(9, 3.5)
        ..moveTo(14, 11.5)
        ..lineTo(16, 7)
        ..lineTo(19, 5)
        ..moveTo(16, 7)
        ..lineTo(15, 3.5)
        ..moveTo(8.6, 12.5)
        ..lineTo(5.5, 11)
        ..moveTo(15.4, 12.5)
        ..lineTo(18.5, 11)
        ..addOval(Rect.fromCenter(
            center: const Offset(12, 18.4), width: 1.6, height: 1.2));
    case Doodle.leaf:
      p
        ..moveTo(4, 20)
        ..cubicTo(4, 10, 10, 4, 20, 4)
        ..cubicTo(20, 14, 14, 20, 4, 20)
        ..close()
        ..moveTo(4, 20)
        ..lineTo(14, 10)
        ..moveTo(9, 15)
        ..lineTo(9, 11)
        ..moveTo(12, 12)
        ..lineTo(15.5, 12.5);
    case Doodle.compass:
      p
        ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 9))
        ..moveTo(15.5, 8.5)
        ..lineTo(13.2, 13.2)
        ..lineTo(8.5, 15.5)
        ..lineTo(10.8, 10.8)
        ..close()
        ..moveTo(12, 1.5)
        ..lineTo(12, 3);
    case Doodle.headphones:
      p
        ..moveTo(4, 15)
        ..lineTo(4, 12)
        ..cubicTo(4, 7, 7.5, 4, 12, 4)
        ..cubicTo(16.5, 4, 20, 7, 20, 12)
        ..lineTo(20, 15)
        ..addRRect(RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 13, 4.5, 7), const Radius.circular(2)))
        ..addRRect(RRect.fromRectAndRadius(
            const Rect.fromLTWH(16.5, 13, 4.5, 7), const Radius.circular(2)));
    case Doodle.footprints:
      p
        ..addOval(
            Rect.fromCenter(center: const Offset(8, 15), width: 4.5, height: 7))
        ..addOval(Rect.fromCircle(center: const Offset(8, 9.6), radius: 1.1))
        ..addOval(Rect.fromCenter(
            center: const Offset(16, 8.5), width: 4.5, height: 7))
        ..addOval(Rect.fromCircle(center: const Offset(16, 3.2), radius: 1.1));
    case Doodle.sun:
      p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 4.5));
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        p
          ..moveTo(12 + 7 * math.cos(a), 12 + 7 * math.sin(a))
          ..lineTo(12 + 10 * math.cos(a), 12 + 10 * math.sin(a));
      }
    case Doodle.mountain:
      p
        ..moveTo(2, 20)
        ..lineTo(9, 8)
        ..lineTo(13, 14)
        ..lineTo(16, 10)
        ..lineTo(22, 20)
        ..close()
        ..moveTo(7.2, 11)
        ..lineTo(9, 12.5)
        ..lineTo(10.8, 11)
        ..moveTo(5, 17)
        ..cubicTo(9, 15.5, 14, 18.5, 19, 16.5);
    case Doodle.butterfly:
      p
        ..moveTo(12, 7)
        ..lineTo(12, 18)
        ..moveTo(12, 10)
        ..cubicTo(8, 2, 2, 5, 4, 10)
        ..cubicTo(5, 12.5, 9, 12, 12, 11.5)
        ..moveTo(12, 10)
        ..cubicTo(16, 2, 22, 5, 20, 10)
        ..cubicTo(19, 12.5, 15, 12, 12, 11.5)
        ..moveTo(12, 12.5)
        ..cubicTo(9, 13, 5.5, 15, 7.5, 18)
        ..cubicTo(9, 19.5, 11, 16, 12, 13.5)
        ..moveTo(12, 12.5)
        ..cubicTo(15, 13, 18.5, 15, 16.5, 18)
        ..cubicTo(15, 19.5, 13, 16, 12, 13.5)
        ..moveTo(12, 7)
        ..lineTo(10.5, 4.5)
        ..moveTo(12, 7)
        ..lineTo(13.5, 4.5);
    case Doodle.bench:
      p
        ..moveTo(3, 12)
        ..lineTo(21, 12)
        ..moveTo(3, 8)
        ..lineTo(21, 8)
        ..moveTo(5, 12)
        ..lineTo(5, 19)
        ..moveTo(19, 12)
        ..lineTo(19, 19)
        ..moveTo(6, 8)
        ..lineTo(6, 5)
        ..moveTo(18, 8)
        ..lineTo(18, 5)
        ..moveTo(3, 15.5)
        ..lineTo(21, 15.5);
    case Doodle.drop:
      p
        ..moveTo(12, 2.5)
        ..cubicTo(12, 2.5, 5, 10.5, 5, 14.5)
        ..cubicTo(5, 18.5, 8.2, 21.5, 12, 21.5)
        ..cubicTo(15.8, 21.5, 19, 18.5, 19, 14.5)
        ..cubicTo(19, 10.5, 12, 2.5, 12, 2.5)
        ..close()
        ..moveTo(8.8, 14.5)
        ..cubicTo(8.8, 16.6, 10, 18, 11.5, 18.3);
    case Doodle.map:
      p
        ..moveTo(3, 6)
        ..lineTo(9, 3.5)
        ..lineTo(15, 6)
        ..lineTo(21, 3.5)
        ..lineTo(21, 18)
        ..lineTo(15, 20.5)
        ..lineTo(9, 18)
        ..lineTo(3, 20.5)
        ..close()
        ..moveTo(9, 3.5)
        ..lineTo(9, 18)
        ..moveTo(15, 6)
        ..lineTo(15, 20.5);
    case Doodle.sparkle:
      p
        ..moveTo(12, 2)
        ..quadraticBezierTo(13, 11, 22, 12)
        ..quadraticBezierTo(13, 13, 12, 22)
        ..quadraticBezierTo(11, 13, 2, 12)
        ..quadraticBezierTo(11, 11, 12, 2)
        ..close();
    case Doodle.mushroom:
      p
        ..moveTo(3, 12)
        ..cubicTo(3, 6, 7, 3, 12, 3)
        ..cubicTo(17, 3, 21, 6, 21, 12)
        ..close()
        ..moveTo(9, 12)
        ..lineTo(8.5, 20)
        ..quadraticBezierTo(12, 21.5, 15.5, 20)
        ..lineTo(15, 12)
        ..addOval(Rect.fromCircle(center: const Offset(9, 7.5), radius: 1.3))
        ..addOval(Rect.fromCircle(center: const Offset(15, 8), radius: 1.1));
    case Doodle.binoculars:
      p
        ..addOval(Rect.fromCircle(center: const Offset(7, 15.5), radius: 4.5))
        ..addOval(Rect.fromCircle(center: const Offset(17, 15.5), radius: 4.5))
        ..moveTo(4, 12)
        ..lineTo(6, 5)
        ..lineTo(9, 5)
        ..lineTo(10.5, 12)
        ..moveTo(20, 12)
        ..lineTo(18, 5)
        ..lineTo(15, 5)
        ..lineTo(13.5, 12)
        ..moveTo(10.5, 13)
        ..lineTo(13.5, 13);
  }
  return p;
}

/// One doodle as an icon.
class DoodleIcon extends StatelessWidget {
  const DoodleIcon(this.doodle,
      {super.key, this.size = 24, this.color = JT.ink, this.stroke = 1.7});

  final Doodle doodle;
  final double size;
  final Color color;
  final double stroke;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _DoodlePainter(doodle, color, stroke)),
      );
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter(this.doodle, this.color, this.stroke);

  final Doodle doodle;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 24;
    canvas.scale(s);
    canvas.drawPath(
      doodlePath(doodle),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_DoodlePainter old) =>
      old.doodle != doodle || old.color != color || old.stroke != stroke;
}

/// A tiled pattern of doodles drifting left to right forever (seeded, so it never jumps
/// between rebuilds). Doodles are chosen by their world column, and one loop moves exactly
/// one 8-column period, so the end of a loop looks identical to its start: no reset.
class DoodlePattern extends StatefulWidget {
  const DoodlePattern({
    super.key,
    this.color = JT.doodle,
    this.cell = 62,
    this.iconSize = 30,
    this.seed = 7,
    this.drift = true,
    this.opacity = 1,
  });

  final Color color;
  final double cell;
  final double iconSize;
  final int seed;
  final bool drift;
  final double opacity;

  @override
  State<DoodlePattern> createState() => _DoodlePatternState();
}

class _DoodlePatternState extends State<DoodlePattern>
    with SingleTickerProviderStateMixin {
  /// Drift speed in logical pixels per second.
  static const _speed = 7.0;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(
        milliseconds:
            (_PatternPainter.period * widget.cell / _speed * 1000).round()),
  );

  /// The shared clock, when there is one above: patterns with the same seed then drift
  /// in step.
  AmbientClock? _clock;

  double get _loopSeconds => _PatternPainter.period * widget.cell / _speed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clock = AmbientScope.maybeOf(context);
    if (_clock == null && widget.drift && !JTMotion.reduced(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _clock ?? _c,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _PatternPainter(
              t: _clock != null && widget.drift
                  ? (_clock!.seconds / _loopSeconds) % 1
                  : _c.value,
              color: widget.color.withValues(alpha: widget.opacity),
              cell: widget.cell,
              iconSize: widget.iconSize,
              seed: widget.seed,
            ),
          ),
        ),
      );
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.t,
    required this.color,
    required this.cell,
    required this.iconSize,
    required this.seed,
  });

  final double t;
  final Color color;
  final double cell;
  final double iconSize;
  final int seed;

  /// Columns/rows after which the doodle layout repeats.
  static const period = 8;

  static final _paths = {for (final d in Doodle.values) d: doodlePath(d)};

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    // Horizontal drift by exactly one pattern period per loop (seamless wrap).
    final shift = t * period * cell;
    final cols = (size.width / cell).ceil() + 3;
    final rows = (size.height / cell).ceil() + 2;
    final first = (-shift / cell).floor() - 2;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var r = -1; r < rows; r++) {
      for (var c = first; c < first + cols; c++) {
        final gr = ((r % period) + period) % period;
        final gc = ((c % period) + period) % period;
        final rnd = math.Random(seed * 1000 + gr * 31 + gc);
        final d = Doodle.values[rnd.nextInt(Doodle.values.length)];
        final jitter =
            Offset(rnd.nextDouble() * 14 - 7, rnd.nextDouble() * 14 - 7);
        final offsetRow = (r.isOdd ? cell / 2 : 0);
        final pos = Offset(c * cell + offsetRow + shift, r * cell) + jitter;
        final scale = iconSize / 24 * (0.85 + rnd.nextDouble() * 0.35);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate((rnd.nextDouble() - 0.5) * 0.9);
        canvas.scale(scale);
        canvas.translate(-12, -12);
        canvas.drawPath(_paths[d]!, paint..strokeWidth = 1.9 / scale);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.t != t || old.color != color;
}

/// The puffy canopy edge between the sun band and the cream body: a white rim of
/// scallops (Sliq's cloud) whose bumps breathe gently.
class CanopyEdge extends StatefulWidget {
  const CanopyEdge({
    super.key,
    this.height = 64,
    this.body = JT.cream,
    this.rim = Colors.white,
    this.seed = 3,
    this.animate = true,
  });

  final double height;
  final Color body;
  final Color rim;
  final int seed;
  final bool animate;

  @override
  State<CanopyEdge> createState() => _CanopyEdgeState();
}

class _CanopyEdgeState extends State<CanopyEdge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));

  /// The shared clock, when there is one above (see [DoodlePattern]).
  AmbientClock? _clock;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clock = AmbientScope.maybeOf(context);
    if (_clock == null && widget.animate && !JTMotion.reduced(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _clock ?? _c,
          builder: (context, _) => CustomPaint(
            painter: _CanopyPainter(
              t: _clock != null && widget.animate
                  ? (_clock!.seconds / 6) % 1
                  : _c.value,
              body: widget.body,
              rim: widget.rim,
              seed: widget.seed,
            ),
          ),
        ),
      );
}

class _CanopyPainter extends CustomPainter {
  _CanopyPainter(
      {required this.t,
      required this.body,
      required this.rim,
      required this.seed});

  final double t;
  final Color body;
  final Color rim;
  final int seed;

  Path _scallops(Size size, double baseY, double amp, int salt) {
    final rnd = math.Random(seed + salt);
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, baseY);
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final w = 46 + rnd.nextDouble() * 54;
      final phase = rnd.nextDouble() * math.pi * 2;
      final h = amp *
          (0.55 + rnd.nextDouble() * 0.6) *
          (1 + 0.08 * math.sin(t * math.pi * 2 + phase));
      path.cubicTo(
          x + w * 0.05, baseY - h, x + w * 0.95, baseY - h, x + w, baseY);
      x += w;
      i++;
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    assert(i > 0);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rimPath = _scallops(size, size.height * 0.62, size.height * 0.55, 1);
    final bodyPath = _scallops(size, size.height * 0.82, size.height * 0.42, 2);
    canvas.drawShadow(rimPath, const Color(0xFF8A6A1E), 3, false);
    canvas.drawPath(rimPath, Paint()..color = rim);
    canvas.drawPath(bodyPath, Paint()..color = body);
  }

  @override
  bool shouldRepaint(_CanopyPainter old) => old.t != t || old.body != body;
}

/// The sun band itself: yellow, drifting doodles and the puffy canopy edge along the
/// bottom, clipped to its box. Home, Search and the tab transition all draw this one
/// widget, so with the same [seed] and [edgeHeight] they look exactly alike.
class SunBand extends StatelessWidget {
  const SunBand({
    super.key,
    this.color = JT.sun,
    this.doodleColor = JT.doodle,
    this.body = JT.cream,
    this.edge = true,
    this.edgeHeight = 64,
    this.seed = 7,
    this.behindEdge,
  });

  final Color color;
  final Color doodleColor;
  final Color body;
  final bool edge;
  final double edgeHeight;
  final int seed;

  /// Drawn over the doodles but behind the canopy (a mascot peeking over it).
  final Widget? behindEdge;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: color),
            DoodlePattern(color: doodleColor, seed: seed),
            if (behindEdge != null) behindEdge!,
            if (edge)
              Positioned(
                left: 0,
                right: 0,
                bottom: -1,
                child: CanopyEdge(height: edgeHeight, body: body, seed: seed),
              ),
          ],
        ),
      );
}

/// The Sliq-style sun band with content on it: [child] sits on top of the band (Skip chip,
/// mascot, title). With [backdrop] off only the content is drawn (something else is
/// drawing the band, e.g. a transition).
class SunHeader extends StatelessWidget {
  const SunHeader({
    super.key,
    required this.height,
    this.child,
    this.color = JT.sun,
    this.doodleColor = JT.doodle,
    this.body = JT.cream,
    this.edge = true,
    this.seed = 7,
    this.backdrop = true,
  });

  final double height;
  final Widget? child;
  final Color color;
  final Color doodleColor;
  final Color body;
  final bool edge;
  final int seed;
  final bool backdrop;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (backdrop)
              SunBand(
                color: color,
                doodleColor: doodleColor,
                body: body,
                edge: edge,
                seed: seed,
              ),
            if (child != null) child!,
          ],
        ),
      );
}
