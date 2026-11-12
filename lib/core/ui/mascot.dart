import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'motion.dart';

/// Pako: a pinecone from the Dago Pakar pine forest, with a leaf sprout.
/// Drawn as vectors so every part (eyes, mouth, arms, sprout) can move independently.
enum PakoPose {
  idle,
  wave,
  cheer,
  listen,
  navigate,
  curious,
  sleepy,
  thinking,
  drink,
}

class Pako extends StatefulWidget {
  const Pako({
    super.key,
    this.pose = PakoPose.idle,
    this.size = 160,
    this.look = Offset.zero,
    this.animate = true,
    this.shadow = true,
  });

  final PakoPose pose;
  final double size;

  /// Where the eyes look, each axis −1…1.
  final Offset look;
  final bool animate;
  final bool shadow;

  @override
  State<Pako> createState() => _PakoState();
}

class _PakoState extends State<Pako> with TickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _blink = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 150));
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));
  Timer? _blinkTimer;
  final _rnd = math.Random();
  PakoPose? _previous;

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Pako old) {
    super.didUpdateWidget(old);
    if (old.pose != widget.pose) {
      _previous = old.pose;
      _enter.forward(from: 0); // squash-pop into the new pose
    }
    _sync();
  }

  void _sync() {
    final run = widget.animate && !JTMotion.reduced(context);
    if (run && !_loop.isAnimating) _loop.repeat();
    if (!run) {
      _loop.stop();
      _enter.value = 1;
    }
  }

  void _scheduleBlink() {
    _blinkTimer =
        Timer(Duration(milliseconds: 1800 + _rnd.nextInt(3200)), () async {
      if (!mounted) return;
      if (widget.pose != PakoPose.sleepy && widget.animate) {
        await _blink.forward(from: 0);
        if (!mounted) return;
        await _blink.reverse();
        if (!mounted) return;
        if (_rnd.nextDouble() < 0.25) {
          await _blink.forward(from: 0);
          if (mounted) await _blink.reverse();
        }
      }
      if (mounted) _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _loop.dispose();
    _blink.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'Pako, pemandu jelajah',
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: widget.size,
            child: AnimatedBuilder(
              animation: Listenable.merge([_loop, _blink, _enter]),
              builder: (context, _) => CustomPaint(
                painter: _PakoPainter(
                  pose: widget.pose,
                  t: _loop.value,
                  blink: _blink.value,
                  enter: _enter.isAnimating || _previous != null
                      ? _enter.value
                      : 1,
                  look: widget.look,
                  shadow: widget.shadow,
                ),
              ),
            ),
          ),
        ),
      );
}

class _PakoPainter extends CustomPainter {
  _PakoPainter({
    required this.pose,
    required this.t,
    required this.blink,
    required this.enter,
    required this.look,
    required this.shadow,
  });

  final PakoPose pose;
  final double t; // 0..1 loop
  final double blink; // 0 open … 1 closed
  final double enter; // 0..1 pose change pop
  final Offset look;
  final bool shadow;

  static const bodyLight = Color(0xFFD48C52);
  static const bodyDark = Color(0xFF94512A);
  static const scale = Color(0xFF6B3519);
  static const face = Color(0xFFF6CF9C);
  static const foot = Color(0xFF7A4322);
  static const leafA = Color(0xFF5DB26C);
  static const leafB = Color(0xFF2F7A50);
  static const cheek = Color(0xFFF08A7A);
  static const eyeInk = Color(0xFF2A1A10);

  double get _w => t * math.pi * 2;

  Path _body() => Path()
    ..moveTo(100, 44)
    ..cubicTo(131, 44, 153, 80, 157, 118)
    ..cubicTo(161, 153, 137, 178, 100, 178)
    ..cubicTo(63, 178, 39, 153, 43, 118)
    ..cubicTo(47, 80, 69, 44, 100, 44)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200);

    // --- per-pose motion ---------------------------------------------------
    var hop = 0.0; // px up
    var squash = 1.0; // y scale
    var tilt = 0.0; // radians
    var breath = 1 + 0.018 * math.sin(_w);
    switch (pose) {
      case PakoPose.cheer:
        final h = math.max(0.0, math.sin(_w * 2));
        hop = 16 * h;
        squash = 1 + 0.07 * h - 0.06 * (1 - h) * (h < 0.15 ? 1 : 0);
      case PakoPose.listen:
        tilt = 0.09 * math.sin(_w * 2);
        hop = 2 * math.max(0.0, math.sin(_w * 4));
      case PakoPose.wave:
        tilt = 0.04 * math.sin(_w);
        hop = 3 * math.max(0.0, math.sin(_w));
      case PakoPose.sleepy:
        breath = 1 + 0.035 * math.sin(_w * 0.5);
        tilt = 0.06;
      case PakoPose.curious:
        tilt = -0.12 + 0.03 * math.sin(_w);
      case PakoPose.thinking:
        tilt = 0.07;
      case PakoPose.idle:
      case PakoPose.navigate:
      case PakoPose.drink:
        hop = 2.5 * (0.5 + 0.5 * math.sin(_w));
    }
    // pop on pose change: squash then overshoot
    final e = Curves.elasticOut.transform(enter.clamp(0, 1));
    final popY = 0.88 + 0.12 * e;
    final popX = 1.08 - 0.08 * e;

    // --- ground shadow -----------------------------------------------------
    if (shadow) {
      final k = 1 - hop / 40;
      canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(100, 190), width: 96 * k, height: 12 * k),
        Paint()
          ..color = const Color(0xFF5A3A12).withValues(alpha: 0.16 * k)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    canvas.save();
    canvas.translate(100, 184 - hop);
    canvas.rotate(tilt);
    canvas.scale(popX / math.sqrt(squash), popY * squash * breath);
    canvas.translate(-100, -184);

    _feet(canvas);
    _arms(canvas, back: true);
    _sprout(canvas);
    _bodyPaint(canvas);
    _faceArea(canvas);
    _eyes(canvas);
    _cheeks(canvas);
    _mouth(canvas);
    _props(canvas);
    _arms(canvas, back: false);

    canvas.restore();
    _floaters(canvas);
  }

  void _bodyPaint(Canvas canvas) {
    final body = _body();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [bodyLight, bodyDark],
        ).createShader(const Rect.fromLTWH(43, 44, 114, 134)),
    );
    // scales
    canvas.save();
    canvas.clipPath(body);
    final scalePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = scale.withValues(alpha: 0.33);
    var row = 0;
    for (var y = 56.0; y < 182; y += 13) {
      final off = row.isOdd ? 9.0 : 0.0;
      for (var x = 30.0 + off; x < 172; x += 18) {
        final p = Path()
          ..moveTo(x - 7, y)
          ..quadraticBezierTo(x, y + 8, x + 7, y);
        canvas.drawPath(p, scalePaint);
      }
      row++;
    }
    // rim light
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.35), Colors.transparent],
          stops: const [0, 0.45],
        ).createShader(const Rect.fromLTWH(43, 44, 114, 134)),
    );
    canvas.restore();
  }

  void _faceArea(Canvas canvas) {
    final r =
        Rect.fromCenter(center: const Offset(100, 128), width: 86, height: 66);
    canvas.drawOval(
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.3),
          colors: [Color(0xFFFFE2B8), face],
        ).createShader(r),
    );
  }

  void _eyes(Canvas canvas) {
    final closed = pose == PakoPose.sleepy ? 1.0 : blink;
    final happy = pose == PakoPose.cheer;
    for (final cx in [84.0, 116.0]) {
      const cy = 120.0;
      if (happy || closed > 0.85) {
        // ^ ^ happy arcs, or u u when closed
        final p = Path();
        if (happy) {
          p
            ..moveTo(cx - 7, cy + 3)
            ..quadraticBezierTo(cx, cy - 7, cx + 7, cy + 3);
        } else {
          p
            ..moveTo(cx - 7, cy)
            ..quadraticBezierTo(cx, cy + 6, cx + 7, cy);
        }
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.6
            ..strokeCap = StrokeCap.round
            ..color = eyeInk,
        );
        continue;
      }
      final open = 1 - closed;
      final white = Rect.fromCenter(
          center: Offset(cx, cy), width: 17, height: 20 * open + 1.5);
      canvas.drawOval(white, Paint()..color = Colors.white);
      var lx = look.dx;
      var ly = look.dy;
      if (pose == PakoPose.curious) lx += 0.5 * math.sin(_w);
      if (pose == PakoPose.thinking) {
        lx = 0.6;
        ly = -0.7;
      }
      final pupil = Offset(cx + lx * 3.2, cy + ly * 3.6 * open);
      canvas.save();
      canvas.clipPath(Path()..addOval(white));
      canvas.drawOval(Rect.fromCenter(center: pupil, width: 10, height: 11.5),
          Paint()..color = eyeInk);
      canvas.drawCircle(
          pupil + const Offset(-2.2, -2.6), 2.4, Paint()..color = Colors.white);
      canvas.restore();
    }
  }

  void _cheeks(Canvas canvas) {
    final p = Paint()
      ..color = cheek.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(70, 136), width: 14, height: 8),
        p);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(130, 136), width: 14, height: 8),
        p);
  }

  void _mouth(Canvas canvas) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = eyeInk;
    switch (pose) {
      case PakoPose.cheer:
      case PakoPose.wave:
        final m = Path()
          ..moveTo(90, 137)
          ..quadraticBezierTo(100, 152, 110, 137)
          ..close();
        canvas.drawPath(m, Paint()..color = const Color(0xFF6B2416));
        canvas.save();
        canvas.clipPath(m);
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(100, 148), width: 12, height: 8),
            Paint()..color = const Color(0xFFF07B6B));
        canvas.restore();
      case PakoPose.curious:
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(100, 141), width: 7, height: 8),
            Paint()..color = eyeInk);
      case PakoPose.sleepy:
        canvas.drawPath(
            Path()
              ..moveTo(95, 141)
              ..quadraticBezierTo(100, 144, 105, 141),
            ink);
      case PakoPose.thinking:
        canvas.drawPath(
            Path()
              ..moveTo(93, 142)
              ..quadraticBezierTo(101, 139, 108, 143),
            ink);
      case PakoPose.drink:
        canvas.drawCircle(const Offset(100, 141), 3, Paint()..color = eyeInk);
      case PakoPose.idle:
      case PakoPose.listen:
      case PakoPose.navigate:
        canvas.drawPath(
            Path()
              ..moveTo(92, 138)
              ..quadraticBezierTo(100, 146, 108, 138),
            ink);
    }
  }

  void _feet(Canvas canvas) {
    final p = Paint()..color = foot;
    final step = pose == PakoPose.navigate ? 3 * math.sin(_w * 2) : 0.0;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(82, 179 - step), width: 26, height: 13),
        p);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(118, 179 + step), width: 26, height: 13),
        p);
  }

  /// Arms are small rounded stubs rotating around the shoulder.
  void _arms(Canvas canvas, {required bool back}) {
    double left = 0.35, right = -0.35; // radians, 0 = hanging down
    switch (pose) {
      case PakoPose.wave:
        right = -2.3 + 0.45 * math.sin(_w * 3);
      case PakoPose.cheer:
        left = 2.5 + 0.2 * math.sin(_w * 2);
        right = -2.5 - 0.2 * math.sin(_w * 2);
      case PakoPose.navigate:
      case PakoPose.drink:
        left = 1.2;
        right = -1.2;
      case PakoPose.thinking:
        right = -2.0;
      case PakoPose.listen:
        left = 1.9;
        right = -1.9;
      case PakoPose.idle:
      case PakoPose.curious:
      case PakoPose.sleepy:
        left = 0.3 + 0.05 * math.sin(_w);
        right = -0.3 - 0.05 * math.sin(_w);
    }
    final front = pose == PakoPose.navigate ||
        pose == PakoPose.drink ||
        pose == PakoPose.thinking;
    if (back == front) return;
    final paint = Paint()
      ..shader = const LinearGradient(colors: [bodyLight, bodyDark])
          .createShader(const Rect.fromLTWH(30, 110, 140, 50));
    void arm(Offset shoulder, double angle) {
      canvas.save();
      canvas.translate(shoulder.dx, shoulder.dy);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-8, -2, 16, 30), const Radius.circular(8)),
        paint,
      );
      canvas.restore();
    }

    arm(const Offset(50, 124), left);
    arm(const Offset(150, 124), right);
  }

  void _sprout(Canvas canvas) {
    final sway = 0.16 * math.sin(_w + 0.6);
    canvas.save();
    canvas.translate(100, 47);
    canvas.rotate(sway);
    final stem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = leafB;
    canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-2, -10, 2, -20),
        stem);
    void leaf(double angle, double len, Color c) {
      canvas.save();
      canvas.translate(2, -18);
      canvas.rotate(angle);
      final p = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * 0.5, -len * 0.42, len, 0)
        ..quadraticBezierTo(len * 0.5, len * 0.42, 0, 0)
        ..close();
      canvas.drawPath(p, Paint()..color = c);
      canvas.drawLine(
          Offset.zero,
          Offset(len * 0.8, 0),
          Paint()
            ..color = leafB.withValues(alpha: 0.5)
            ..strokeWidth = 1.4);
      canvas.restore();
    }

    leaf(-2.6 - 0.1 * math.sin(_w), 24, leafA);
    leaf(-0.55 + 0.12 * math.sin(_w + 1), 28, leafA);
    canvas.restore();
  }

  void _props(Canvas canvas) {
    switch (pose) {
      case PakoPose.listen:
        final band = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = JT.forest;
        canvas.drawArc(const Rect.fromLTWH(46, 62, 108, 108), math.pi * 1.06,
            math.pi * 0.88, false, band);
        final cup = Paint()..color = JT.forest;
        final pad = Paint()..color = JT.sun;
        for (final x in [44.0, 156.0]) {
          final r = RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, 116), width: 20, height: 32),
              const Radius.circular(10));
          canvas.drawRRect(r, cup);
          canvas.drawRRect(r.deflate(5), pad);
        }
      case PakoPose.navigate:
        final r = Rect.fromCenter(
            center: const Offset(100, 166), width: 64, height: 40);
        canvas.save();
        canvas.translate(100, 166);
        canvas.rotate(-0.06);
        canvas.translate(-100, -166);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(5)),
            Paint()..color = const Color(0xFFFFF3D6));
        final fold = Paint()
          ..color = const Color(0xFFE7D3A6)
          ..strokeWidth = 1.5;
        canvas.drawLine(
            Offset(r.left + 21, r.top), Offset(r.left + 21, r.bottom), fold);
        canvas.drawLine(
            Offset(r.left + 43, r.top), Offset(r.left + 43, r.bottom), fold);
        final route = Path()
          ..moveTo(r.left + 8, r.bottom - 8)
          ..cubicTo(r.left + 20, r.top + 8, r.left + 40, r.bottom - 6,
              r.right - 10, r.top + 10);
        canvas.drawPath(
            route,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..strokeCap = StrokeCap.round
              ..color = JT.forest);
        canvas.drawCircle(Offset(r.right - 10, r.top + 10), 3.6,
            Paint()..color = JT.terracotta);
        canvas.restore();
      case PakoPose.drink:
        final bottle = RRect.fromRectAndRadius(
            const Rect.fromLTWH(86, 146, 28, 40), const Radius.circular(9));
        canvas.drawRRect(bottle, Paint()..color = const Color(0xFF9FD3EE));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(86, 162, 28, 24), const Radius.circular(9)),
            Paint()..color = JT.sky);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(92, 140, 16, 9), const Radius.circular(3)),
            Paint()..color = JT.forest);
        canvas.drawLine(
            const Offset(93, 152),
            const Offset(93, 170),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.7)
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round);
      case PakoPose.idle:
      case PakoPose.wave:
      case PakoPose.cheer:
      case PakoPose.curious:
      case PakoPose.sleepy:
      case PakoPose.thinking:
        break;
    }
  }

  /// Things floating outside the body: Zs, sparkles, thought dots, music notes.
  void _floaters(Canvas canvas) {
    switch (pose) {
      case PakoPose.sleepy:
        for (var i = 0; i < 3; i++) {
          final p = (t + i / 3) % 1;
          final o = (math.sin(p * math.pi)).clamp(0.0, 1.0);
          final tp = TextPainter(
            text: TextSpan(
              text: 'z',
              style: TextStyle(
                fontFamily: 'Bricolage',
                fontWeight: FontWeight.w800,
                fontSize: 14 + 8 * p,
                color: JT.forest.withValues(alpha: o),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(150 + 14 * p, 70 - 50 * p));
        }
      case PakoPose.cheer:
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2 + 0.5;
          final pulse = 0.6 + 0.4 * math.sin(_w * 2 + i);
          final c = Offset(100 + 82 * math.cos(a), 100 + 70 * math.sin(a) - 10);
          _sparkle(canvas, c, 7 * pulse, i.isEven ? JT.sun : JT.leaf);
        }
      case PakoPose.thinking:
        for (var i = 0; i < 3; i++) {
          final pulse = 0.5 + 0.5 * math.sin(_w * 2 - i * 0.9);
          canvas.drawCircle(
              Offset(146 + i * 13.0, 58 - i * 12.0),
              3.5 + i * 1.5,
              Paint()..color = JT.forest.withValues(alpha: 0.35 + 0.5 * pulse));
        }
      case PakoPose.listen:
        for (var i = 0; i < 2; i++) {
          final p = (t * 1.2 + i / 2) % 1;
          final x = i == 0 ? 26.0 - 10 * p : 172.0 + 10 * p;
          _note(canvas, Offset(x, 96 - 56 * p), math.sin(p * math.pi));
        }
      case PakoPose.idle:
      case PakoPose.wave:
      case PakoPose.navigate:
      case PakoPose.curious:
      case PakoPose.drink:
        break;
    }
  }

  void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.15, c.dy - r * 0.15, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.15, c.dy + r * 0.15, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.15, c.dy + r * 0.15, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.15, c.dy - r * 0.15, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  void _note(Canvas canvas, Offset c, double alpha) {
    final paint = Paint()
      ..color = JT.forest.withValues(alpha: alpha.clamp(0, 1));
    canvas.drawOval(Rect.fromCenter(center: c, width: 9, height: 7), paint);
    canvas.drawRect(Rect.fromLTWH(c.dx + 3, c.dy - 16, 2.4, 16), paint);
    canvas.drawRect(Rect.fromLTWH(c.dx + 3, c.dy - 16, 8, 3), paint);
  }

  @override
  bool shouldRepaint(_PakoPainter old) =>
      old.t != t ||
      old.blink != blink ||
      old.enter != enter ||
      old.pose != pose ||
      old.look != look;
}
