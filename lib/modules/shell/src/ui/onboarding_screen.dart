import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../state/guide_controller.dart';

/// UI01 Onboarding.
///
/// Opens on a full-screen welcome that waits for the visitor: the sun band fills the
/// screen, Pako pops up large, doodles burst out and float,
/// a speech bubble types itself and the greeting rises in. Pako's eyes follow the finger,
/// the doodles parallax with it, and tapping Pako makes him react. "Ayo, mulai" (or a tap
/// anywhere else) folds the band up into the onboarding header while Pako hops and glides
/// into it, and only then do the pages rise in below.
/// Pages: two experience pages, then permissions (the band shrinks to make room).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

double _seg(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0);

/// What Pako says, one line per poke.
const _lines = [
  'Halo, saya Pako!',
  'Hihi, geli!',
  'Saya dari Hutan Pinus.',
  'Yuk, jalan-jalan!',
];

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pages = PageController();

  /// Welcome entrance (Pako, burst, bubble, greeting, button).
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));

  /// Band folds into the header; runs only after the visitor taps.
  late final AnimationController _fold = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1700));

  /// Endless ambient time for Pako's float and the floating doodles while waiting.
  late final AnimationController _ambient =
      AnimationController(vsync: this, duration: const Duration(seconds: 40));

  /// Pako's hop when poked or when the fold starts.
  late final AnimationController _hop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 560));

  double _page = 0;
  bool _started = false;
  int _line = 0;
  bool _cheer = false;

  /// Finger/pointer position relative to Pako, each axis −1…1 (eyes + parallax).
  Offset _look = const Offset(0.12, -0.3);
  final Map<String, bool> _perms = {
    'lokasi': true,
    'notifikasi': true,
    'aktivitas': true,
    'kamera': false,
  };

  @override
  void initState() {
    super.initState();
    _pages.addListener(() => setState(() => _page = _pages.page ?? 0));
    _fold.addStatusListener((s) {
      if (s == AnimationStatus.completed) _ambient.stop();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (JTMotion.reduced(context)) {
      _enter.value = 1;
    } else {
      _enter.forward();
      _ambient.repeat();
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (mounted) HapticFeedback.lightImpact();
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _enter.dispose();
    _fold.dispose();
    _ambient.dispose();
    _hop.dispose();
    super.dispose();
  }

  bool get _folding => _fold.value > 0 || _fold.isAnimating;

  void _start() {
    if (_folding) return;
    HapticFeedback.mediumImpact();
    if (JTMotion.reduced(context)) {
      _enter.value = 1;
      _fold.value = 1;
      setState(() {});
      return;
    }
    if (_enter.value < 1) _enter.value = 1;
    setState(() {
      _cheer = false;
      _look = Offset.zero;
    });
    _hop.forward(from: 0);
    _fold.forward();
  }

  void _poke() {
    if (_folding) return;
    HapticFeedback.selectionClick();
    setState(() {
      _line = (_line + 1) % _lines.length;
      _cheer = true;
    });
    _hop.forward(from: 0);
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted && !_folding) setState(() => _cheer = false);
    });
  }

  void _track(Offset pos, _Geo g) {
    if (_folding) return;
    final d = pos - g.pakoStart;
    setState(() => _look = Offset((d.dx / (g.w * 0.5)).clamp(-1.0, 1.0),
        (d.dy / (g.h * 0.4)).clamp(-1.0, 1.0)));
  }

  void _next() {
    if (_page.round() < 2) {
      _pages.nextPage(duration: JTMotion.lazy, curve: JTMotion.emphasized);
    } else {
      // "Izinkan & berangkat": the real OS location prompt (real mode); notifications,
      // pedometer and camera are asked when their engines land.
      final guide = ref.read(guideProvider);
      if (_perms['lokasi'] == true && !guide.isDemo) {
        unawaited(guide.requestLocation());
      }
      context.go('/setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _Geo(MediaQuery.sizeOf(context), MediaQuery.paddingOf(context));
    final last = _page > 1.5;
    final shrink = Curves.easeInOut.transform((_page - 1).clamp(0.0, 1.0));
    final bandPage = lerpDouble(g.bandBig, g.bandSmall, shrink)!;
    return Scaffold(
      backgroundColor: JT.cream,
      body: AnimatedBuilder(
        animation: Listenable.merge([_enter, _fold, _ambient, _hop]),
        builder: (context, _) {
          final f = _fold.value;
          final morph = JTMotion.emphasized.transform(_seg(f, 0.08, 1));
          final band = lerpDouble(g.h + 90, bandPage, morph)!;
          final content = Curves.easeOutCubic.transform(_seg(f, 0.55, 1));
          final welcomeOn = f < 1;
          return Stack(
            children: [
              // Pages + controls at their final place, rising in at the end of the fold.
              Positioned.fill(
                top: bandPage,
                child: Opacity(
                  opacity: content,
                  child: Transform.translate(
                    offset: Offset(0, 36 * (1 - content)),
                    child: IgnorePointer(
                      ignoring: welcomeOn,
                      child: Column(
                        children: [
                          Expanded(
                            child: PageView(
                              controller: _pages,
                              children: [
                                const _TextPage(
                                  kicker: 'Tahura Ir. H. Djuanda',
                                  before: 'Tarik napas,\n',
                                  highlight: 'mulai melangkah',
                                  body:
                                      'Pinus menjulang, udara sejuk, dan jalan setapak yang teduh. Pako menemani setiap langkah Anda.',
                                ),
                                const _TextPage(
                                  kicker: 'Dengar, lihat, rasakan',
                                  before: 'Biarkan hutan\n',
                                  highlight: 'bercerita',
                                  body:
                                      'Setiba di sebuah tempat, ceritanya mengalun pelan di telinga. Simpan ponsel, nikmati pemandangannya.',
                                ),
                                _PermissionPage(
                                  values: _perms,
                                  onToggle: (k) =>
                                      setState(() => _perms[k] = !_perms[k]!),
                                ),
                              ],
                            ),
                          ),
                          _Controls(
                            page: _page,
                            last: last,
                            onNext: _next,
                            onSkip: () => _pages.animateToPage(2,
                                duration: const Duration(milliseconds: 820),
                                curve: JTMotion.emphasized),
                            onLater: () => context.go('/setup'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // The sun band: full screen while welcoming, then folds up.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: band,
                child: SunHeader(height: band, seed: 5),
              ),
              // Header art for each page, parallaxing with the swipe.
              Positioned(
                left: 0,
                right: 0,
                top: g.illusTop,
                height: math.max(0, g.illusBottom(bandPage) - g.illusTop),
                child: _Illustration(
                  page: _page,
                  s: g.s,
                  reveal: Curves.easeOutBack.transform(_seg(f, 0.5, 1)),
                  cardSpread: g.cardSpread,
                ),
              ),
              if (welcomeOn)
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (e) => _track(e.localPosition, g),
                    onPointerMove: (e) => _track(e.localPosition, g),
                    onPointerHover: (e) => _track(e.localPosition, g),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _start,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              if (welcomeOn) ..._welcome(g, f, morph),
              // Pako: one instance from the welcome all the way into page 1's header.
              _travellingPako(g, f, morph),
            ],
          );
        },
      ),
    );
  }

  /// Pako: big and centred in the welcome (tap him to poke), then the page-1 spot in the
  /// header, following page 1's parallax afterwards.
  Widget _travellingPako(_Geo g, double f, double morph) {
    final e = _enter.value;
    final pop = Curves.elasticOut.transform(_seg(e, 0.04, 0.5));
    final appear = _seg(e, 0, 0.14);
    final center = Offset.lerp(g.pakoStart, g.pakoEnd, morph)!;
    final size = lerpDouble(g.pakoStartSize, g.pakoEndSize, morph)!;
    final d = _page;
    final o = (1 - d.abs()).clamp(0.0, 1.0);
    final rise = 70 * (1 - Curves.easeOutCubic.transform(_seg(e, 0.04, 0.38)));
    final hop = math.sin(_hop.value * math.pi) * size * 0.07;
    // Gentle float while waiting, settling as the band folds.
    final float = math.sin(_ambient.value * math.pi * 2 * 10) * 5 * (1 - morph);
    final eyes = Offset.lerp(_look, Offset.zero, morph)!;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: Opacity(
        opacity: appear * Curves.easeOut.transform(o),
        child: Transform.translate(
          offset: Offset(-d * g.w * 0.45, rise - hop + float),
          child: Transform.scale(
            scale: (0.35 + 0.65 * pop) * (0.85 + 0.15 * o),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: f > 0 ? null : _poke,
              child: Semantics(
                button: f == 0,
                label: f == 0 ? 'Sapa Pako' : null,
                child: Pako(
                  pose: _cheer ? PakoPose.cheer : PakoPose.wave,
                  size: size,
                  look: eyes,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The welcome layer: floating doodle burst, speech bubble, greeting, button.
  List<Widget> _welcome(_Geo g, double f, double morph) {
    final e = _enter.value;
    final amb = _ambient.value;
    final out = 1 - _seg(f, 0, 0.22);
    final center = Offset.lerp(g.pakoStart, g.pakoEnd, morph)!;
    final pSize = lerpDouble(g.pakoStartSize, g.pakoEndSize, morph)!;
    final bubbleIn = JTMotion.pop.transform(_seg(e, 0.36, 0.52));
    final textTop = g.pakoStart.dy + g.pakoStartSize * 0.64;
    final par = Offset.lerp(_look, Offset.zero, morph)!;
    Widget rise(double a, double b, Widget child) {
      final k = Curves.easeOutCubic.transform(_seg(e, a, b));
      return Opacity(
        opacity: k * out,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - k) - 24 * (1 - out)),
          child: child,
        ),
      );
    }

    final line = _lines[_line];
    final typed = _line == 0
        ? (line.length * _seg(e, 0.42, 0.66)).round()
        : line.length; // later lines pop in whole with the bubble bounce
    return [
      // Doodles bursting out of Pako, then floating with depth parallax; they fly off
      // as the band folds.
      for (final (i, b) in _bursts.indexed)
        Builder(builder: (context) {
          final k = Curves.easeOutCubic
              .transform(_seg(e, 0.12 + i * 0.03, 0.62 + i * 0.03));
          final dist = pSize * b.dist * (0.25 + 0.75 * k) * (1 + 0.9 * morph);
          final ph = amb * math.pi * 2 * 8 + i * 1.7;
          final bob = Offset(math.cos(ph) * 3, math.sin(ph * 1.3) * 6);
          final depth = 10.0 + (i % 3) * 8;
          final raw = center +
              Offset(math.cos(b.angle), math.sin(b.angle)) * dist +
              bob * (1 - morph) +
              par * depth * (1 - morph);
          final edge = b.size / 2 + 14;
          final p = Offset(
              lerpDouble(raw.dx.clamp(edge, g.w - edge), raw.dx, morph)!,
              raw.dy);
          return Positioned(
            left: p.dx - b.size / 2,
            top: p.dy - b.size / 2,
            child: IgnorePointer(
              child: Opacity(
                opacity: k * (1 - _seg(f, 0.05, 0.4)),
                child: Transform.rotate(
                  angle: b.spin * (1 - k) +
                      b.tilt +
                      math.sin(ph * 0.5) * 0.12 +
                      morph * b.spin,
                  child: Transform.scale(
                    scale: (0.3 + 0.7 * k) * (1 + 0.15 * _hop.value),
                    child: DoodleIcon(b.doodle,
                        size: b.size, color: b.color, stroke: 2.1),
                  ),
                ),
              ),
            ),
          );
        }),
      // Speech bubble: types the first line, pops a new line on every poke.
      Positioned(
        left: math.min(g.pakoStart.dx + g.pakoStartSize * 0.1, g.w * 0.5),
        right: 12,
        top: g.pakoStart.dy - g.pakoStartSize * 0.78,
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Opacity(
              opacity: _seg(e, 0.36, 0.44) * out,
              child: AnimatedSwitcher(
                duration: JTMotion.slow,
                switchInCurve: JTMotion.pop,
                transitionBuilder: (child, a) => ScaleTransition(
                  scale: Tween(begin: 0.6, end: 1.0).animate(a),
                  alignment: Alignment.bottomLeft,
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: Transform.scale(
                  key: ValueKey(_line),
                  scale: 0.5 + 0.5 * bubbleIn,
                  alignment: Alignment.bottomLeft,
                  child: _SpeechBubble(text: line, shown: typed),
                ),
              ),
            ),
          ),
        ),
      ),
      // Greeting.
      Positioned(
        left: 28,
        right: 28,
        top: textTop,
        child: IgnorePointer(
          child: Column(
            children: [
              rise(
                0.44,
                0.62,
                Text('Sampurasun!',
                    style: JTText.title.copyWith(color: JT.forest)),
              ),
              const SizedBox(height: 8),
              rise(
                0.5,
                0.72,
                HighlightHeadline(
                  before: 'Selamat datang di\n',
                  highlight: 'Jelajah Taman',
                  color: JT.forest,
                  style: JTText.display,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              rise(
                0.6,
                0.8,
                Text(
                  'Udara sejuk dan cerita hutan\nsudah menunggu Anda.',
                  textAlign: TextAlign.center,
                  style: JTText.body
                      .copyWith(color: JT.ink.withValues(alpha: 0.72)),
                ),
              ),
            ],
          ),
        ),
      ),
      // The one way forward (a tap anywhere does the same).
      Positioned(
        left: 24,
        right: 24,
        bottom: 20 + MediaQuery.paddingOf(context).bottom,
        child: rise(
          0.74,
          1,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryPill(
                label: 'Ayo, mulai',
                trailingIcon: Icons.arrow_forward_rounded,
                onTap: _start,
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

/// All layout numbers in one place, so the welcome Pako lands exactly on the header spot.
class _Geo {
  _Geo(Size size, EdgeInsets pad)
      : w = size.width,
        h = size.height,
        top = pad.top;

  final double w;
  final double h;
  final double top;

  double get bandBig => math.min(h * 0.5, 440.0);
  double get bandSmall => math.min(h * 0.29, 250.0);
  double get illusTop => top + 18;

  /// Bottom of the header art (above the canopy edge) for a given band height.
  double illusBottom(double band) => band - 56;

  /// Scale of the page-1 header art.
  double get s => math.min(illusBottom(bandBig) - illusTop, 330.0);

  /// Horizontal offset of the two photo cards beside Pako.
  double get cardSpread => math.min(s * 0.46, w / 2 - s * 0.23 - 12);

  double get pakoStartSize => math.min(math.min(w * 0.7, h * 0.36), 310.0);
  Offset get pakoStart => Offset(w / 2, top + h * 0.36);
  double get pakoEndSize => s * 0.66;
  Offset get pakoEnd =>
      Offset(w / 2, (illusTop + illusBottom(bandBig)) / 2 + s * 0.04);
}

class _Burst {
  const _Burst(this.doodle, this.angle, this.dist, this.size, this.color,
      {this.spin = 1.4, this.tilt = 0});

  final Doodle doodle;
  final double angle;
  final double dist;
  final double size;
  final Color color;
  final double spin;
  final double tilt;
}

const _bursts = [
  _Burst(Doodle.pine, -2.6, 0.78, 34, JT.forest, tilt: -0.2),
  _Burst(Doodle.leaf, -1.95, 0.86, 28, Colors.white, spin: -1.6),
  _Burst(Doodle.sparkle, -1.2, 0.84, 26, Colors.white, tilt: 0.3),
  _Burst(Doodle.butterfly, -0.45, 0.82, 32, JT.forest, spin: -1.2),
  _Burst(Doodle.sun, 0.25, 0.86, 30, Colors.white),
  _Burst(Doodle.mushroom, 0.95, 0.76, 28, JT.forest, tilt: 0.2),
  _Burst(Doodle.footprints, 2.2, 0.8, 30, Colors.white, spin: -1.4),
  _Burst(Doodle.deer, 2.9, 0.84, 34, JT.forest, tilt: -0.15),
];

/// White bubble with a tail. [shown] characters are visible; the rest is laid out but
/// transparent, so the bubble keeps its final size while the text types itself.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, required this.shown});

  final String text;
  final int shown;

  @override
  Widget build(BuildContext context) {
    final style = JTText.label.copyWith(fontSize: 15);
    final n = shown.clamp(0, text.length);
    return Semantics(
      label: text,
      child: CustomPaint(
        painter: _BubblePainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: ExcludeSemantics(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: text.substring(0, n)),
                TextSpan(
                    text: text.substring(n),
                    style: style.copyWith(color: Colors.transparent)),
              ]),
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height - 10),
        const Radius.circular(18));
    final tail = Path()
      ..moveTo(14, size.height - 12)
      ..quadraticBezierTo(10, size.height - 2, 4, size.height)
      ..quadraticBezierTo(22, size.height - 2, 30, size.height - 12)
      ..close();
    final p = Paint()..color = Colors.white;
    canvas.drawRRect(body, p);
    canvas.drawPath(tail, p);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => false;
}

/// Dots, the primary action and a quiet secondary text action, in fixed slots so nothing
/// jumps between pages.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.page,
    required this.last,
    required this.onNext,
    required this.onSkip,
    required this.onLater,
  });

  final double page;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 4, 24, 8 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          children: [
            PageDots(count: 3, page: page),
            const SizedBox(height: 20),
            PrimaryPill(
              label: last ? 'Izinkan & berangkat' : 'Lanjut',
              trailingIcon: Icons.arrow_forward_rounded,
              onTap: onNext,
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 44,
              child: AnimatedSwitcher(
                // Old label leaves quickly, new one arrives after: never two words overlapping.
                duration: JTMotion.slow,
                reverseDuration: JTMotion.fast,
                switchInCurve: const Interval(0.35, 1, curve: Curves.easeOut),
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
                child: TextButton(
                  key: ValueKey(last),
                  onPressed: last ? onLater : onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: JT.muted,
                    minimumSize: const Size(96, 44),
                  ),
                  child: Text(last ? 'Nanti saja' : 'Lewati',
                      style: JTText.label.copyWith(color: JT.muted)),
                ),
              ),
            ),
          ],
        ),
      );
}

/// Kicker, headline with one green phrase and a short line, centred in the space left.
class _TextPage extends StatelessWidget {
  const _TextPage({
    required this.kicker,
    required this.before,
    required this.highlight,
    required this.body,
  });

  final String kicker;
  final String before;
  final String highlight;
  final String body;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: JT.mint,
                      borderRadius: BorderRadius.circular(JT.rChip),
                    ),
                    child: Text(kicker,
                        style: JTText.label.copyWith(color: JT.forest)),
                  ),
                  const SizedBox(height: 16),
                  HighlightHeadline(
                    before: before,
                    highlight: highlight,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 330),
                    child: Text(body,
                        textAlign: TextAlign.center,
                        style: JTText.body.copyWith(color: JT.muted)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _PermissionPage extends StatelessWidget {
  const _PermissionPage({required this.values, required this.onToggle});

  final Map<String, bool> values;
  final ValueChanged<String> onToggle;

  static const _rows = [
    (
      'lokasi',
      Icons.near_me_rounded,
      'Lokasi',
      'Agar Pako tahu saat Anda tiba'
    ),
    (
      'notifikasi',
      Icons.notifications_active_rounded,
      'Notifikasi',
      'Kabar meski layar terkunci'
    ),
    (
      'aktivitas',
      Icons.directions_walk_rounded,
      'Aktivitas fisik',
      'Menghitung langkah Anda'
    ),
    (
      'kamera',
      Icons.qr_code_scanner_rounded,
      'Kamera',
      'Membuka cerita di dalam gua'
    ),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HighlightHeadline(
                    before: 'Siapkan diri,\nkita ',
                    highlight: 'berangkat',
                    style: JTText.display,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: JT.surface,
                      borderRadius: BorderRadius.circular(JT.rCard),
                      border: Border.all(color: JT.line),
                    ),
                    child: Column(
                      children: [
                        for (final (i, (key, icon, title, sub))
                            in _rows.indexed) ...[
                          if (i > 0)
                            const Divider(
                                height: 1, indent: 66, color: JT.line),
                          _PermRow(
                            icon: icon,
                            title: title,
                            sub: sub,
                            value: values[key]!,
                            onTap: () => onToggle(key),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 14, color: JT.muted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                            'Tanpa akun. Semuanya tetap di ponsel Anda.',
                            textAlign: TextAlign.center,
                            style: JTText.caption),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _PermRow extends StatelessWidget {
  const _PermRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.985,
        semanticLabel: '$title, ${value ? 'aktif' : 'nonaktif'}',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
          child: Row(
            children: [
              AnimatedContainer(
                duration: JTMotion.base,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: value ? JT.mint : JT.creamDeep,
                  borderRadius: BorderRadius.circular(13),
                ),
                child:
                    Icon(icon, color: value ? JT.forest : JT.muted, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: JTText.label),
                    const SizedBox(height: 2),
                    Text(sub, style: JTText.caption),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Switch(value: value, onChanged: (_) => onTap()),
              ),
            ],
          ),
        ),
      );
}

/// Header art per page, parallaxing with the swipe. Page 1's Pako is drawn by the screen
/// (it travels in from the welcome); this draws the photo cards around him.
class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.page,
    required this.s,
    required this.reveal,
    required this.cardSpread,
  });

  final double page;
  final double s;
  final double reveal;
  final double cardSpread;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          Widget scene(int i, Widget child) {
            final d = page - i;
            final o = (1 - d.abs()).clamp(0.0, 1.0);
            return IgnorePointer(
              child: Opacity(
                opacity: Curves.easeOut.transform(o),
                child: Transform.translate(
                  offset: Offset(-d * c.maxWidth * 0.45, 0),
                  child: Transform.scale(scale: 0.85 + 0.15 * o, child: child),
                ),
              ),
            );
          }

          Widget card(String asset, Doodle doodle, Color tint, double side,
              double angle, double dy) {
            final cw = s * 0.42;
            return Transform.translate(
              offset: Offset(side * cardSpread * reveal, dy * reveal),
              child: Transform.rotate(
                angle: angle * reveal,
                child: Transform.scale(
                  scale: 0.55 + 0.45 * reveal,
                  child: Opacity(
                    opacity: reveal.clamp(0.0, 1.0),
                    child: Container(
                      width: cw,
                      height: cw * 1.22,
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SceneImage(
                          asset: asset, tint: tint, doodle: doodle, radius: 7),
                    ),
                  ),
                ),
              ),
            );
          }

          final small = math.min(c.maxHeight * 0.92, s * 0.78);
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              scene(
                0,
                SizedBox(
                  width: c.maxWidth,
                  height: c.maxHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      card('p06_mulut_gua.jpg', Doodle.cave, JT.sejarah, -1,
                          -0.16, s * 0.06),
                      card('p07_rusa.jpg', Doodle.deer, JT.alam, 1, 0.13,
                          -s * 0.02),
                    ],
                  ),
                ),
              ),
              scene(
                1,
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    PulseRings(
                      color: Colors.white,
                      size: s * 1.02,
                      rings: 3,
                      child: Pako(pose: PakoPose.listen, size: s * 0.7),
                    ),
                    Positioned(
                      left: -s * 0.38,
                      top: s * 0.08,
                      child: Transform.rotate(
                        angle: -0.3,
                        child: DoodleIcon(Doodle.leaf,
                            size: s * 0.12, color: Colors.white, stroke: 2),
                      ),
                    ),
                    Positioned(
                      right: -s * 0.36,
                      bottom: s * 0.1,
                      child: Transform.rotate(
                        angle: 0.25,
                        child: DoodleIcon(Doodle.butterfly,
                            size: s * 0.13, color: JT.forest, stroke: 2),
                      ),
                    ),
                  ],
                ),
              ),
              scene(2, Pako(pose: PakoPose.navigate, size: small)),
            ],
          );
        },
      );
}
