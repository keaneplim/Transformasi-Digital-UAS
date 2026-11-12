import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../demo/demo_controller.dart';
import '../demo/places.dart';
import 'main_shell.dart';
import 'widgets.dart';

/// UI12 QR fallback (A02). Dark viewfinder with breathing corners and a scan line.
/// In the preview the camera is mocked: pick a code below to "scan" it.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();
  bool _torch = false;
  String? _found;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _scan(Place p) async {
    setState(() => _found = p.id);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    final demo = ref.read(demoProvider);
    if (!demo.sessionActive) demo.startSession();
    demo.teleportTo(p);
    context.pop();
    demo.triggerNow(p, viaQr: true);
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(demoProvider);
    final qrPlaces = [
      for (final p in demo.pois)
        if (p.poi?.qrCode != null) p,
    ];
    final size = MediaQuery.sizeOf(context);
    final box = math.min(size.width - 80, 290.0);
    return Scaffold(
      backgroundColor: JT.dusk,
      body: Stack(
        children: [
          // Fake camera feed: blurred forest tones that drift slowly.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) =>
                  CustomPaint(painter: _FeedPainter(_c.value)),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _MaskPainter(box: box, radius: 34)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Tutup',
                        background: Colors.white.withValues(alpha: 0.12),
                        foreground: Colors.white,
                        onTap: () => context.pop(),
                      ),
                      const Spacer(),
                      CircleIconButton(
                        icon: _torch
                            ? Icons.flashlight_on_rounded
                            : Icons.flashlight_off_rounded,
                        tooltip: _torch ? 'Matikan senter' : 'Nyalakan senter',
                        background: _torch
                            ? JT.sun
                            : Colors.white.withValues(alpha: 0.12),
                        foreground: _torch ? JT.ink : Colors.white,
                        onTap: () => setState(() => _torch = !_torch),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      HighlightHeadline(
                        before: 'Pindai ',
                        highlight: 'kode QR',
                        textAlign: TextAlign.center,
                        color: JT.sun,
                        style: JTText.display.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cari papan kecil bergambar QR di dekat mulut gua.',
                        textAlign: TextAlign.center,
                        style: JTText.body.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox.square(
                  dimension: box,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => CustomPaint(
                      painter: _FinderPainter(
                        t: _c.value,
                        found: _found != null,
                        reduced: JTMotion.reduced(context),
                      ),
                      child: Center(
                        child: AnimatedScale(
                          scale: _found != null ? 1 : 0,
                          duration: JTMotion.slow,
                          curve: JTMotion.pop,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: const BoxDecoration(
                                color: JT.sun, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded,
                                size: 44, color: JT.ink),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const _WeakSignal(),
                const SizedBox(height: 14),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(26),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KODE DI TAMAN',
                          style:
                              JTText.overline.copyWith(color: Colors.white60)),
                      const SizedBox(height: 10),
                      for (final p in qrPlaces) ...[
                        _CodeRow(
                            place: p,
                            busy: _found == p.id,
                            onTap: () => _scan(p)),
                        if (p != qrPlaces.last) const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    ref.read(tabProvider.notifier).state = 2;
                    context.pop();
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  icon: const Icon(Icons.list_rounded, size: 20),
                  label: Text('Pilih tempat dari daftar',
                      style: JTText.label.copyWith(color: Colors.white70)),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow(
      {required this.place, required this.busy, required this.onTap});

  final Place place;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: 'Pindai kode ${place.name}',
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: busy ? JT.sun : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              SizedBox.square(
                  dimension: 44,
                  child: PlacePhoto(place: place, radius: 12, hero: false)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(place.name,
                    style: JTText.title
                        .copyWith(color: busy ? JT.ink : Colors.white)),
              ),
              Icon(Icons.qr_code_2_rounded, color: busy ? JT.ink : JT.sun),
              const SizedBox(width: 8),
            ],
          ),
        ),
      );
}

class _WeakSignal extends StatelessWidget {
  const _WeakSignal();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: JT.sun.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_disabled_rounded,
                color: JT.sun, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Di dalam gua sinyal lokasi melemah. Kode QR membuka ceritanya langsung.',
                style: JTText.bodySm.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      );
}

class _FeedPainter extends CustomPainter {
  _FeedPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF173A2A));
    final blobs = [
      (const Color(0xFF2F6B45), 0.2, 0.3, 0.55),
      (const Color(0xFF4F7A3C), 0.8, 0.25, 0.45),
      (const Color(0xFF1D4A35), 0.5, 0.75, 0.6),
      (const Color(0xFF6E8A4A), 0.15, 0.85, 0.35),
    ];
    for (var i = 0; i < blobs.length; i++) {
      final (c, x, y, r) = blobs[i];
      final a = t * 2 * math.pi + i * 1.7;
      final center = Offset(
        size.width * (x + 0.04 * math.sin(a)),
        size.height * (y + 0.03 * math.cos(a)),
      );
      final rad = size.width * r;
      canvas.drawCircle(
        center,
        rad,
        Paint()
          ..shader = RadialGradient(
                  colors: [c.withValues(alpha: 0.9), c.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: rad)),
      );
    }
  }

  @override
  bool shouldRepaint(_FeedPainter old) => old.t != t;
}

/// Darkens everything except the viewfinder square (positioned at the screen centre).
class _MaskPainter extends CustomPainter {
  _MaskPainter({required this.box, required this.radius});

  final double box;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // The finder sits roughly in the middle of the free space; a soft vignette is enough.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 0.75,
          colors: [Colors.transparent, JT.dusk.withValues(alpha: 0.75)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_MaskPainter old) => false;
}

class _FinderPainter extends CustomPainter {
  _FinderPainter({required this.t, required this.found, required this.reduced});

  final double t;
  final bool found;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    final breathe = reduced ? 0.0 : math.sin(t * 2 * math.pi) * 4;
    final r = Rect.fromLTWH(0, 0, size.width, size.height).deflate(6 - breathe);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(30));
    canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: 0.06));

    final color = found ? JT.sun : Colors.white;
    final corner = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    const len = 46.0;
    const rad = 30.0;
    for (final (dx, dy) in [(0, 0), (1, 0), (0, 1), (1, 1)]) {
      final x = dx == 0 ? r.left : r.right;
      final y = dy == 0 ? r.top : r.bottom;
      final sx = dx == 0 ? 1.0 : -1.0;
      final sy = dy == 0 ? 1.0 : -1.0;
      final path = Path()
        ..moveTo(x, y + sy * len)
        ..lineTo(x, y + sy * rad)
        ..arcToPoint(Offset(x + sx * rad, y),
            radius: const Radius.circular(rad), clockwise: (sx * sy) > 0)
        ..lineTo(x + sx * len, y);
      canvas.drawPath(path, corner);
    }

    if (!found) {
      final p = reduced ? 0.5 : (math.sin(t * 2 * math.pi) + 1) / 2;
      final y = r.top + 20 + (r.height - 40) * p;
      final line = Rect.fromLTWH(r.left + 22, y - 1.5, r.width - 44, 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(line, const Radius.circular(2)),
        Paint()..color = JT.sun,
      );
      canvas.drawRect(
        Rect.fromLTWH(r.left + 22, y - 36, r.width - 44, 36),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              JT.sun.withValues(alpha: 0),
              JT.sun.withValues(alpha: 0.18)
            ],
          ).createShader(Rect.fromLTWH(0, y - 36, 1, 36)),
      );
    }
  }

  @override
  bool shouldRepaint(_FinderPainter old) => old.t != t || old.found != found;
}
