import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../demo/demo_controller.dart';
import '../demo/places.dart';
import 'widgets.dart';

/// UI07 Eyes-free "Mode dengar": dusk-green full screen, oversized controls, Pako listening.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final place = demo.place(id);
    if (place == null) return const Scaffold();
    final mine = demo.nowPlaying?.id == id;
    final playing = mine && demo.audioPlaying;
    final len = demo.audioLength(place);
    final pos = mine ? demo.audioPos : 0.0;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: JT.dusk,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DoodlePattern(
                color: JT.duskSoft, seed: 13, iconSize: 34, cell: 72),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 0.9,
                  colors: [
                    place.tint.withValues(alpha: 0.45),
                    JT.dusk.withValues(alpha: 0)
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        tooltip: 'Tutup',
                        background: Colors.white.withValues(alpha: 0.1),
                        foreground: Colors.white,
                        iconSize: 28,
                        onTap: () => context.pop(),
                      ),
                      Expanded(
                        child: Text('MODE DENGAR',
                            textAlign: TextAlign.center,
                            style: JTText.overline
                                .copyWith(color: Colors.white70)),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                        ),
                        child:
                            PlacePhoto(place: place, radius: 34, hero: false),
                      ),
                      Positioned(
                        right: -34,
                        bottom: -40,
                        child: Pako(
                          pose: playing ? PakoPose.listen : PakoPose.idle,
                          size: 130,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(place.name,
                      textAlign: TextAlign.center,
                      style: JTText.display.copyWith(color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('Cerita tempat · ${place.groupLabel}',
                      style: JTText.body.copyWith(color: Colors.white70)),
                  const Spacer(),
                  Waveform(
                    progress: pos / len,
                    playing: playing,
                    seed: place.seed,
                    height: 70,
                    bars: 46,
                    rest: Colors.white.withValues(alpha: 0.35),
                    onSeek: (f) {
                      if (!mine) demo.playAudio(place);
                      demo.seekAudio(f);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(durationClock(Duration(seconds: pos.round())),
                          style:
                              JTText.number(15, color: Colors.white70, w: 600)),
                      const Spacer(),
                      Text(
                          '-${durationClock(Duration(seconds: (len - pos).round()))}',
                          style:
                              JTText.number(15, color: Colors.white70, w: 600)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleIconButton(
                        icon: Icons.replay_10_rounded,
                        tooltip: 'Mundur 10 detik',
                        size: 66,
                        iconSize: 32,
                        background: Colors.white.withValues(alpha: 0.1),
                        foreground: Colors.white,
                        onTap: () => demo.skipAudio(-10),
                      ),
                      const SizedBox(width: 26),
                      Pressable(
                        onTap: () => demo.toggleAudio(place),
                        scale: 0.9,
                        semanticLabel: playing ? 'Jeda' : 'Putar',
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: JT.sun,
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedSwitcher(
                            duration: JTMotion.base,
                            transitionBuilder: (c, a) =>
                                ScaleTransition(scale: a, child: c),
                            child: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              key: ValueKey(playing),
                              size: 54,
                              color: JT.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 26),
                      CircleIconButton(
                        icon: Icons.forward_10_rounded,
                        tooltip: 'Maju 10 detik',
                        size: 66,
                        iconSize: 32,
                        background: Colors.white.withValues(alpha: 0.1),
                        foreground: Colors.white,
                        onTap: () => demo.skipAudio(10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _Toggle(
                    icon: Icons.auto_mode_rounded,
                    label: 'Putar otomatis saat tiba',
                    value: demo.autoPlay,
                    onChanged: (v) => demo.update(() => demo.autoPlay = v),
                  ),
                  const SizedBox(height: 10),
                  Text('Kontrol juga ada di layar kunci dan earphone.',
                      textAlign: TextAlign.center,
                      style: JTText.bodySm.copyWith(color: Colors.white60)),
                  SizedBox(height: 12 + pad.bottom * 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: JT.sun, size: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: JTText.label.copyWith(color: Colors.white))),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );
}
