import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../demo/demo_controller.dart';
import '../demo/places.dart';
import 'overlays.dart';
import 'widgets.dart';

/// UI11 Arrived. Leaf confetti + Pako cheering. Arrival never re-triggers a POI (D06):
/// it only offers to open the detail.
class ArrivedScreen extends ConsumerStatefulWidget {
  const ArrivedScreen({super.key});

  @override
  ConsumerState<ArrivedScreen> createState() => _ArrivedScreenState();
}

class _ArrivedScreenState extends ConsumerState<ArrivedScreen> {
  Place? _place;

  @override
  void initState() {
    super.initState();
    final demo = ref.read(demoProvider);
    _place = demo.arrivedAt ?? demo.navigation?.to;
    WidgetsBinding.instance.addPostFrameCallback((_) => demo.finishArrival());
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(demoProvider);
    final place = _place;
    if (place == null) {
      return Scaffold(
          body: Center(
              child:
                  SoftButton(label: 'Kembali', expand: false, onTap: _close)));
    }
    final visited = demo.visited.contains(place.id);
    final pad = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final photo = (size.width * 0.74).clamp(220.0, 330.0);
    // The yellow band ends three quarters down the photo, so the photo straddles the edge.
    final headerH = pad.top + 64 + photo * 0.74;
    final description = place.isPoi
        ? _shortDescription(place.poi?.displayText ?? '')
        : _facilityLine(place);
    return Scaffold(
      backgroundColor: JT.cream,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SunHeader(
              height: headerH,
              seed: place.seed,
              child: const SizedBox.expand(),
            ),
          ),
          const Positioned.fill(
              child: IgnorePointer(child: LeafConfetti(count: 34))),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          24, pad.top + 64, 24, 16 + pad.bottom),
                      child: Column(
                        children: [
                          Entrance(
                            scaleFrom: 0.6,
                            duration: JTMotion.lazy,
                            child: _Photo(place: place, size: photo),
                          ),
                          const Spacer(flex: 2),
                          const SizedBox(height: 28),
                          Entrance(
                            delay: const Duration(milliseconds: 260),
                            child: const Pill(
                              icon: Icons.flag_rounded,
                              label: 'Anda sudah sampai!',
                              color: JT.forest,
                              background: JT.mint,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Entrance(
                            delay: const Duration(milliseconds: 320),
                            child: Text(place.name,
                                textAlign: TextAlign.center,
                                style: JTText.display),
                          ),
                          const SizedBox(height: 10),
                          Entrance(
                            delay: const Duration(milliseconds: 380),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Text(
                                description,
                                textAlign: TextAlign.center,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: JTText.body.copyWith(color: JT.muted),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Entrance(
                            delay: const Duration(milliseconds: 440),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                Pill(
                                  icon: Icons.directions_walk_rounded,
                                  label: '${thousands(demo.steps)} langkah',
                                  background: JT.surface,
                                ),
                                Pill(
                                  icon: Icons.route_rounded,
                                  label: '${km(demo.walkedM)} km',
                                  background: JT.surface,
                                ),
                                Pill(
                                  icon: Icons.schedule_rounded,
                                  label:
                                      'Tutup ${clockLabel(demo.closingTime)}',
                                  background: JT.surface,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(flex: 3),
                          const SizedBox(height: 24),
                          Entrance(
                            delay: const Duration(milliseconds: 520),
                            child: _Actions(
                              place: place,
                              visited: visited,
                              onClose: _close,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: pad.top + 8,
            right: 12,
            child: SkipChip(label: 'Tutup', onTap: _close),
          ),
        ],
      ),
    );
  }

  /// First sentence or two of the place text, so the visitor gets a glimpse before listening.
  static String _shortDescription(String text) {
    final sentences = text.trim().split(RegExp(r'(?<=[.!?])\s+'));
    var out = '';
    for (final s in sentences) {
      if (out.isNotEmpty && out.length + s.length > 170) break;
      out = out.isEmpty ? s : '$out $s';
      if (out.length >= 90) break;
    }
    return out.isEmpty
        ? 'Luangkan waktu sejenak, lalu dengarkan cerita tempat ini.'
        : out;
  }

  String _facilityLine(Place p) => switch (p.facility?.type) {
        'toilet' => 'Toilet ada di sekitar Anda. Kami tunggu di jalur, ya.',
        'musala' => 'Selamat beribadah. Jalur akan tetap tersimpan.',
        'istirahat' => 'Duduk sebentar, minum, lalu lanjutkan perjalanan.',
        _ => 'Silakan, lalu lanjutkan perjalanan.',
      };
}

class _Photo extends StatelessWidget {
  const _Photo({required this.place, required this.size});

  final Place place;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size + 40,
        height: size + 24,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: JT.surface, width: 6),
              ),
              child: PlacePhoto(place: place, radius: 34, hero: false),
            ),
            Positioned(
              right: -6,
              bottom: -30,
              child: Pako(pose: PakoPose.cheer, size: size * 0.46),
            ),
          ],
        ),
      );
}

class _Actions extends ConsumerWidget {
  const _Actions({
    required this.place,
    required this.visited,
    required this.onClose,
  });

  final Place place;
  final bool visited;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.read(demoProvider);
    if (!place.isPoi) {
      return PrimaryPill(
          label: 'Oke, lanjut', icon: Icons.check_rounded, onTap: onClose);
    }
    return Column(
      children: [
        PrimaryPill(
          label: visited ? 'Buka detail' : 'Dengarkan ceritanya',
          icon: visited ? Icons.article_rounded : Icons.headphones_rounded,
          onTap: () {
            if (visited) {
              context.pushReplacement('/poi/${place.id}');
            } else {
              demo
                ..markVisited(place)
                ..playAudio(place);
              context.pushReplacement('/play/${place.id}');
            }
          },
        ),
        const SizedBox(height: 10),
        SoftButton(
          label: 'Lihat tujuan berikutnya',
          icon: Icons.explore_rounded,
          onTap: () {
            demo.markVisited(place);
            onClose();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final ctx = rootNavigatorContext;
              if (ctx != null) {
                showRecommendations(ctx);
              }
            });
          },
        ),
      ],
    );
  }
}
