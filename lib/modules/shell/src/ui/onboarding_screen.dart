import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

/// UI01 Onboarding (Sliq-style): sun band with drifting doodles and a canopy edge, Pako
/// changing pose per page, big headline with one green word. Page 3 asks for permissions.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  double _page = 0;
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
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page.round() < 2) {
      _pages.nextPage(duration: JTMotion.slow, curve: JTMotion.emphasized);
    } else {
      context.go('/setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final band = math.min(h * 0.44, 380.0);
    final top = MediaQuery.paddingOf(context).top;
    final last = _page > 1.5;
    return Scaffold(
      backgroundColor: JT.cream,
      body: Column(
        children: [
          SunHeader(
            height: band,
            seed: 5,
            child: Stack(
              children: [
                Positioned.fill(
                  top: top + 36,
                  bottom: 48,
                  child: _Illustration(page: _page),
                ),
                Positioned(
                  top: top + 12,
                  right: 16,
                  child: AnimatedOpacity(
                    opacity: last ? 0 : 1,
                    duration: JTMotion.base,
                    child: IgnorePointer(
                      ignoring: last,
                      child: SkipChip(
                        onTap: () => _pages.animateToPage(2,
                            duration: JTMotion.lazy,
                            curve: JTMotion.emphasized),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              children: [
                const _TextPage(
                  kicker: 'Selamat datang di Jelajah Taman',
                  before: 'Jelajahi Tahura,\n',
                  highlight: 'lebih dekat',
                  body:
                      'Cerita setiap tempat muncul sendiri saat Anda tiba, bahkan ketika sinyal hilang di tengah hutan.',
                ),
                const _TextPage(
                  kicker: 'Tanpa terus menatap layar',
                  before: 'Dengarkan\n',
                  highlight: 'sambil berjalan',
                  body:
                      'Ponsel bergetar saat Anda mendekat, lalu narasi diputar lewat earphone. Layar boleh tetap di saku.',
                ),
                _PermissionPage(
                  values: _perms,
                  onToggle: (k) => setState(() => _perms[k] = !_perms[k]!),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 8, 24, 16 + MediaQuery.paddingOf(context).bottom),
            child: Column(
              children: [
                PageDots(count: 3, page: _page),
                const SizedBox(height: 18),
                PrimaryPill(
                  label: last ? 'Izinkan & lanjutkan' : 'Lanjut',
                  trailingIcon: Icons.arrow_forward_rounded,
                  onTap: _next,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 40,
                  child: AnimatedSwitcher(
                    duration: JTMotion.base,
                    child: last
                        ? TextButton(
                            key: const ValueKey('later'),
                            onPressed: () => context.go('/setup'),
                            style:
                                TextButton.styleFrom(foregroundColor: JT.muted),
                            child: Text('Nanti saja',
                                style: JTText.label.copyWith(color: JT.muted)),
                          )
                        : Text(
                            key: const ValueKey('note'),
                            'Tanpa akun. Semua data tetap di ponsel Anda.',
                            style: JTText.caption,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
        child: Column(
          children: [
            Text(kicker, style: JTText.title.copyWith(color: JT.muted)),
            const SizedBox(height: 14),
            HighlightHeadline(
              before: before,
              highlight: highlight,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(body,
                textAlign: TextAlign.center,
                style: JTText.body.copyWith(color: JT.muted)),
          ],
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
      'Tahu saat Anda tiba di sebuah tempat'
    ),
    (
      'notifikasi',
      Icons.notifications_active_rounded,
      'Notifikasi',
      'Memberi tahu meski layar terkunci'
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
      'Memindai kode QR di dalam gua'
    ),
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Column(
          children: [
            Text('Hampir siap', style: JTText.title.copyWith(color: JT.muted)),
            const SizedBox(height: 10),
            HighlightHeadline(
              before: 'Izinkan, lalu ',
              highlight: 'berangkat',
              style: JTText.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            for (final (i, (key, icon, title, sub)) in _rows.indexed)
              Entrance(
                delay: JTMotion.stagger * i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Pressable(
                    onTap: () => onToggle(key),
                    scale: 0.98,
                    semanticLabel: title,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      decoration: BoxDecoration(
                        color: JT.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: JT.mint,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(icon, color: JT.forest, size: 21),
                          ),
                          const SizedBox(width: 12),
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
                          Switch(
                              value: values[key]!,
                              onChanged: (_) => onToggle(key)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// The band illustration. Each page's scene parallaxes with the swipe.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.page});

  final double page;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final s = math.min(c.maxHeight, 300.0);
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

          return Stack(
            alignment: Alignment.center,
            children: [
              scene(
                0,
                SizedBox(
                  width: s * 1.2,
                  height: s,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: -0.07,
                        child: Container(
                          width: s * 0.62,
                          height: s * 0.78,
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 26),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const SceneImage(
                            asset: 'p01_gerbang.jpg',
                            tint: JT.forest,
                            doodle: Doodle.map,
                            radius: 8,
                          ),
                        ),
                      ),
                      Positioned(
                        right: s * 0.02,
                        bottom: -s * 0.02,
                        child: Pako(pose: PakoPose.wave, size: s * 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              scene(
                1,
                PulseRings(
                  color: Colors.white,
                  size: s * 1.05,
                  rings: 3,
                  child: Pako(pose: PakoPose.listen, size: s * 0.72),
                ),
              ),
              scene(2, Pako(pose: PakoPose.navigate, size: s * 0.78)),
            ],
          );
        },
      );
}
