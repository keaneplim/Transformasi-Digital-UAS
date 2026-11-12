import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:jelajah_taman/modules/map/map.dart';
import 'package:jelajah_taman/modules/routing/routing.dart';

import '../state/guide_controller.dart';
import '../state/places.dart';
import 'park_map.dart';
import 'widgets.dart';

/// UI10 Navigation on the trail graph. "Mulai jalan" walks the simulated dot along the
/// route (no GPS needed); instructions change at junctions; arrival opens UI11.
class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen>
    with TickerProviderStateMixin {
  final ParkMapController mapController = ParkMapController();
  bool _arrivedPushed = false;

  /// Keeps the whole route clear of the instruction card (top) and the panel (bottom).
  static const _fitPadding = EdgeInsets.fromLTRB(36, 230, 36, 330);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  void _fit() {
    final nav = ref.read(guideProvider).navigation;
    if (nav == null || nav.route.polyline.length < 2) return;
    mapController.fit(nav.route.polyline, padding: _fitPadding, maxZoom: 18);
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(guideProvider);
    final nav = demo.navigation;
    ref.listen(guideProvider.select((d) => d.reroutes), (_, __) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
              'Anda keluar dari rute. Rute baru dibuat dari posisi Anda.',
              style: JTText.body.copyWith(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: JT.ink,
        ));
    });
    ref.listen(guideProvider.select((d) => d.position), (_, p) {
      final g = ref.read(guideProvider);
      // demo walk, or live GPS inside the park: keep the visitor in view
      if (g.walking || (!g.isDemo && g.showUser && !g.outsideZone)) {
        mapController.move(
            p, mapController.zoom < 17.3 ? 17.6 : mapController.zoom);
      }
    });
    if (demo.arrivedAt != null && !_arrivedPushed) {
      _arrivedPushed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement('/arrived');
      });
    }
    if (nav == null) {
      return Scaffold(
        body: Center(
          child: SoftButton(
              label: 'Kembali', expand: false, onTap: () => context.pop()),
        ),
      );
    }
    final pad = MediaQuery.paddingOf(context);
    final turn = demo.nextTurn;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ParkMap(
              controller: mapController,
              route: nav.route.polyline,
              walkedM: demo.navProgressM,
              destinationId: nav.to.id,
              highlightId: demo.approaching?.place.id,
              showFacilities: !nav.to.isPoi,
              initialZoom: 16.6,
              fitPadding: _fitPadding,
              showLabels: false,
              chromeInsets:
                  EdgeInsets.fromLTRB(16, pad.top + 150, 84, 290 + pad.bottom),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: pad.top + 8,
            child: _InstructionCard(
              turn: turn,
              distanceM: demo.distanceToNextTurn,
              onClose: () {
                demo.cancelNavigation();
                context.pop();
              },
            ),
          ),
          Positioned(
            right: 16,
            bottom: 250 + pad.bottom,
            child: CircleIconButton(
              icon: Icons.route_rounded,
              tooltip: 'Lihat seluruh rute',
              onTap: _fit,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(to: nav.to, total: nav.route.distanceM),
          ),
        ],
      ),
    );
  }
}

IconData turnIcon(TurnDirection? d) => switch (d) {
      TurnDirection.left => Icons.turn_left_rounded,
      TurnDirection.right => Icons.turn_right_rounded,
      TurnDirection.arrive => Icons.flag_rounded,
      _ => Icons.straight_rounded,
    };

class _InstructionCard extends StatelessWidget {
  const _InstructionCard(
      {required this.turn, required this.distanceM, required this.onClose});

  final TurnInstruction? turn;
  final double distanceM;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        decoration: BoxDecoration(
          color: JT.forest,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: JTMotion.slow,
              transitionBuilder: (c, a) => RotationTransition(
                turns: Tween(begin: -0.1, end: 0.0).animate(a),
                child: ScaleTransition(scale: a, child: c),
              ),
              child: Container(
                key: ValueKey('${turn?.nodeId}${turn?.direction}'),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: JT.sun,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(turnIcon(turn?.direction), size: 34, color: JT.ink),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedCount(
                    value: distanceM,
                    duration: JTMotion.fast,
                    format: (v) => turn?.direction == TurnDirection.arrive
                        ? 'Tujuan dalam ${distanceLabel(v)}'
                        : 'Dalam ${distanceLabel(v)}',
                    style: JTText.number(22, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: JTMotion.base,
                    child: Text(
                      turn?.text ?? 'Ikuti jalur setapak',
                      key: ValueKey(turn?.text),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: JTText.bodySm.copyWith(
                          color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Akhiri navigasi',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ],
        ),
      );
}

class _BottomPanel extends ConsumerWidget {
  const _BottomPanel({required this.to, required this.total});

  final Place to;
  final double total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    final pad = MediaQuery.paddingOf(context);
    final frac = total == 0 ? 1.0 : (demo.navProgressM / total).clamp(0.0, 1.0);
    final arriveAt = demo.now().add(demo.navRemainingTime);
    return Container(
      padding: EdgeInsets.fromLTRB(18, 8, 18, 16 + pad.bottom),
      decoration: BoxDecoration(
        color: JT.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(JT.rSheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Grabber(),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox.square(
                dimension: 54,
                child: PlacePhoto(place: to, radius: 16, hero: false),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Menuju', style: JTText.caption),
                    Text(to.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JTText.h3),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Big(
                value: AnimatedCount(
                  value: demo.navRemainingM,
                  duration: JTMotion.fast,
                  format: distanceLabel,
                  style: JTText.number(24),
                ),
                label: 'SISA JARAK',
              ),
              _Big(
                value: Text(minutesLabel(demo.navRemainingTime),
                    style: JTText.number(24)),
                label: 'WAKTU',
              ),
              _Big(
                value: Text(clockLabel(arriveAt),
                    style: JTText.number(24, color: JT.forestBright)),
                label: 'TIBA',
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              color: JT.forest,
              backgroundColor: JT.mint,
            ),
          ),
          const SizedBox(height: 16),
          if (!demo.isDemo)
            Row(
              children: [
                Icon(
                    demo.noPosition || demo.outsideZone
                        ? Icons.location_off_rounded
                        : Icons.directions_walk_rounded,
                    color: JT.forest,
                    size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    demo.noPosition
                        ? 'Aktifkan lokasi agar arah mengikuti langkah Anda.'
                        : demo.outsideZone
                            ? 'Anda di luar kawasan. Arah dimulai dari gerbang.'
                            : 'Ikuti garis hijau. Arah diperbarui saat Anda berjalan.',
                    style: JTText.caption.copyWith(color: JT.ink),
                  ),
                ),
              ],
            )
          else
            PrimaryPill(
              label: demo.walking
                  ? 'Berhenti sejenak'
                  : (frac > 0 ? 'Lanjut jalan' : 'Mulai jalan'),
              icon: demo.walking
                  ? Icons.pause_rounded
                  : Icons.directions_walk_rounded,
              color: demo.walking ? JT.ink : JT.forest,
              onTap: demo.toggleWalking,
            ),
        ],
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.value, required this.label});

  final Widget value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: value),
            const SizedBox(height: 4),
            Text(label, style: JTText.overline),
          ],
        ),
      );
}
