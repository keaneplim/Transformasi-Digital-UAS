import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'doodles.dart';
import 'motion.dart';

/// A real photo (asset) or, until the survey photo exists, an illustrated scene in the
/// same frame: layered hills in the category tint with a big doodle. Same size either way,
/// so swapping in the photo later doesn't change the layout.
class SceneImage extends StatelessWidget {
  const SceneImage({
    super.key,
    required this.asset,
    required this.tint,
    required this.doodle,
    this.seed = 1,
    this.radius = 0,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final String? asset;
  final Color tint;
  final Doodle doodle;
  final int seed;
  final double radius;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final child = asset != null
        ? Image.asset(
            'assets/images/$asset',
            fit: fit,
            alignment: alignment,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
              opacity: sync || frame != null ? 1 : 0,
              duration: JTMotion.slow,
              child: child,
            ),
            errorBuilder: (context, error, stack) =>
                _Illustration(tint: tint, doodle: doodle, seed: seed),
          )
        : _Illustration(tint: tint, doodle: doodle, seed: seed);
    return radius == 0
        ? child
        : ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration(
      {required this.tint, required this.doodle, required this.seed});

  final Color tint;
  final Doodle doodle;
  final int seed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final s = math.min(c.maxWidth, c.maxHeight);
          final badge = (s * 0.34).clamp(22.0, 92.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _ScenePainter(tint, seed)),
              // The place's emblem as a white stamp, like a trail marker.
              Align(
                alignment: const Alignment(0, -0.12),
                child: Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: badge * 0.07,
                        strokeAlign: BorderSide.strokeAlignOutside),
                  ),
                  alignment: Alignment.center,
                  child: DoodleIcon(doodle,
                      size: badge * 0.58,
                      color: Color.lerp(tint, JT.ink, 0.25)!,
                      stroke: 1.8),
                ),
              ),
            ],
          );
        },
      );
}

/// Duotone landscape in the place's tint: soft sky, sun with halo, a cloud, three hill
/// layers with a row of pines on the middle one.
class _ScenePainter extends CustomPainter {
  _ScenePainter(this.tint, this.seed);

  final Color tint;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = Offset.zero & size;
    final rnd = math.Random(seed);
    final sky = Color.lerp(tint, JT.cream, 0.72)!;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(sky, Colors.white, 0.45)!, sky],
        ).createShader(r),
    );

    // Sun with a soft halo.
    final sun = Offset(w * (0.18 + rnd.nextDouble() * 0.64), h * 0.22);
    final sr = size.shortestSide * 0.1;
    canvas.drawCircle(
        sun, sr * 1.9, Paint()..color = JT.sunSoft.withValues(alpha: 0.45));
    canvas.drawCircle(sun, sr, Paint()..color = JT.sun);

    // A small cloud on the other side of the sky.
    final cx = sun.dx > w / 2 ? w * 0.24 : w * 0.72;
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.75);
    final cs = size.shortestSide * 0.045;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, h * 0.3), width: cs * 7, height: cs * 2.2),
            Radius.circular(cs * 1.1)),
        cloud);
    canvas.drawCircle(
        Offset(cx - cs * 0.8, h * 0.3 - cs * 1.1), cs * 1.4, cloud);
    canvas.drawCircle(Offset(cx + cs * 1.2, h * 0.3 - cs * 0.7), cs, cloud);

    // Hills, back to front.
    for (var layer = 0; layer < 3; layer++) {
      final base = h * (0.6 + layer * 0.13);
      final color = Color.lerp(Color.lerp(tint, JT.cream, 0.45 - layer * 0.2)!,
          JT.ink, layer * 0.1)!;
      final phase = rnd.nextDouble() * math.pi * 2;
      final amp = h * (0.05 + rnd.nextDouble() * 0.04);
      double y(double x) =>
          base + amp * math.sin(x / w * math.pi * (1.3 + layer * 0.8) + phase);
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 4) {
        p.lineTo(x, y(x));
      }
      p
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(p, Paint()..color = color);

      // Pines on the middle hill.
      if (layer == 1) {
        final pine = Paint()..color = Color.lerp(color, JT.ink, 0.18)!;
        final n = 3 + rnd.nextInt(3);
        for (var i = 0; i < n; i++) {
          final x = w * (0.08 + rnd.nextDouble() * 0.84);
          final ph = h * (0.07 + rnd.nextDouble() * 0.05);
          final pw = ph * 0.55;
          final top = y(x) - ph;
          canvas.drawPath(
            Path()
              ..moveTo(x, top)
              ..lineTo(x - pw / 2, y(x) + 1)
              ..lineTo(x + pw / 2, y(x) + 1)
              ..close(),
            pine,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.tint != tint || old.seed != seed;
}

/// Audio waveform scrubber: bars breathe while playing, played part in sun yellow.
class Waveform extends StatefulWidget {
  const Waveform({
    super.key,
    required this.progress,
    required this.playing,
    this.seed = 3,
    this.bars = 42,
    this.height = 56,
    this.played = JT.sun,
    this.rest = JT.forest,
    this.onSeek,
  });

  final double progress;
  final bool playing;
  final int seed;
  final int bars;
  final double height;
  final Color played;
  final Color rest;
  final ValueChanged<double>? onSeek;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2));
  late final List<double> _levels = () {
    final r = math.Random(widget.seed);
    return List.generate(widget.bars, (i) {
      final env = math.sin(i / widget.bars * math.pi) * 0.5 + 0.5;
      return (0.25 + r.nextDouble() * 0.75) * env;
    });
  }();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Waveform old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.playing && !JTMotion.reduced(context)) {
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

  void _seek(Offset local, double width) =>
      widget.onSeek?.call((local.dx / width).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => GestureDetector(
          onTapDown: (d) => _seek(d.localPosition, c.maxWidth),
          onHorizontalDragUpdate: (d) => _seek(d.localPosition, c.maxWidth),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _WavePainter(
                  levels: _levels,
                  progress: widget.progress,
                  t: _c.value,
                  playing: widget.playing,
                  played: widget.played,
                  rest: widget.rest,
                ),
              ),
            ),
          ),
        ),
      );
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.levels,
    required this.progress,
    required this.t,
    required this.playing,
    required this.played,
    required this.rest,
  });

  final List<double> levels;
  final double progress;
  final double t;
  final bool playing;
  final Color played;
  final Color rest;

  @override
  void paint(Canvas canvas, Size size) {
    final n = levels.length;
    final gap = size.width / n;
    final w = math.max(2.0, gap * 0.56);
    for (var i = 0; i < n; i++) {
      final frac = i / n;
      final wobble =
          playing ? 0.82 + 0.18 * math.sin(t * math.pi * 2 * 2 + i * 0.7) : 1.0;
      final h = math.max(4.0, levels[i] * size.height * wobble);
      final x = i * gap + gap / 2;
      final isPlayed = frac <= progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(x, size.height / 2), width: w, height: h),
          Radius.circular(w / 2),
        ),
        Paint()..color = isPlayed ? played : rest.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.progress != progress || old.t != t || old.playing != playing;
}

/// Elevation profile sparkline that draws itself in.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color = JT.forest,
    this.height = 40,
    this.fill = true,
  });

  final List<double> values;
  final Color color;
  final double height;
  final bool fill;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: JTMotion.of(context, const Duration(milliseconds: 900)),
        curve: JTMotion.emphasized,
        builder: (context, t, _) => SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _SparkPainter(values, color, t, fill)),
        ),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color, this.t, this.fill);

  final List<double> values;
  final Color color;
  final double t;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final span = math.max(1.0, hi - lo);
    Offset pt(int i) => Offset(
          i / (values.length - 1) * size.width,
          size.height - 4 - (values[i] - lo) / span * (size.height - 8),
        );
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final a = pt(i - 1), b = pt(i);
      final mx = (a.dx + b.dx) / 2;
      line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));
    if (fill) {
      final area = Path.from(line)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t || old.color != color;
}

/// Falling leaves + sparkles for celebrations (arrival, session end). Plays once.
class LeafConfetti extends StatefulWidget {
  const LeafConfetti({super.key, this.count = 26});

  final int count;

  @override
  State<LeafConfetti> createState() => _LeafConfettiState();
}

class _LeafConfettiState extends State<LeafConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!JTMotion.reduced(context) && !_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_c.value, widget.count),
          ),
        ),
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.count);

  final double t;
  final int count;

  static const _colors = [
    JT.leaf,
    JT.sun,
    JT.forestBright,
    JT.terracotta,
    JT.alam
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final rnd = math.Random(11);
    for (var i = 0; i < count; i++) {
      final x0 = rnd.nextDouble() * size.width;
      final delay = rnd.nextDouble() * 0.35;
      final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p == 0) continue;
      final fall = Curves.easeIn.transform(p);
      final y = -30 + fall * (size.height * (0.6 + rnd.nextDouble() * 0.5));
      final x = x0 + math.sin(p * math.pi * 3 + i) * 26;
      final alpha = (1 - p).clamp(0.0, 1.0);
      final color = _colors[i % _colors.length].withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p * math.pi * 4 * (rnd.nextBool() ? 1 : -1));
      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, 3.5, Paint()..color = color);
      } else {
        final s = 6 + rnd.nextDouble() * 6;
        final leaf = Path()
          ..moveTo(-s, 0)
          ..quadraticBezierTo(0, -s * 0.8, s, 0)
          ..quadraticBezierTo(0, s * 0.8, -s, 0)
          ..close();
        canvas.drawPath(leaf, Paint()..color = color);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// A pulsing halo (approaching POI, live location, recording).
class PulseRings extends StatefulWidget {
  const PulseRings({
    super.key,
    required this.color,
    this.size = 120,
    this.child,
    this.rings = 2,
  });

  final Color color;
  final double size;
  final Widget? child;
  final int rings;

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!JTMotion.reduced(context)) {
      if (!_c.isAnimating) _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                size: Size.square(widget.size),
                painter: _PulsePainter(_c.value, widget.color, widget.rings),
              ),
            ),
            if (widget.child != null) widget.child!,
          ],
        ),
      );
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t, this.color, this.rings);

  final double t;
  final Color color;
  final int rings;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < rings; i++) {
      final p = (t + i / rings) % 1;
      canvas.drawCircle(
        c,
        size.shortestSide / 2 * (0.35 + 0.65 * p),
        Paint()..color = color.withValues(alpha: 0.28 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}
