import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../demo/demo_controller.dart';

/// Splash for returning visitors: the sun rises, Pako pops up and waves, the wordmark types
/// itself in. First-time visitors skip it: a plain sun-yellow frame hands straight over to
/// the onboarding welcome, which opens on the same yellow.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..forward();
  Timer? _go;
  late final bool _firstRun = !ref.read(demoProvider).onboarded;

  @override
  void initState() {
    super.initState();
    if (_firstRun) {
      _go = Timer(Duration.zero, () {
        if (mounted) context.go('/welcome');
      });
      return;
    }
    _go = Timer(const Duration(milliseconds: 2300), () {
      if (!mounted) return;
      final onboarded = ref.read(demoProvider).onboarded;
      context.go(onboarded ? '/home' : '/welcome');
    });
  }

  @override
  void dispose() {
    _go?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const word = 'jelajah taman';
    if (_firstRun) return const Scaffold(backgroundColor: JT.sun);
    return Scaffold(
      backgroundColor: JT.cream,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final sun =
              Curves.easeOutBack.transform((_c.value / 0.55).clamp(0, 1));
          final pako = ((_c.value - 0.25) / 0.45).clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.35 * sun,
                  child: const DoodlePattern(color: JT.sunSoft, seed: 2),
                ),
              ),
              Transform.scale(
                scale: 0.2 + 0.8 * sun,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      JT.sun,
                      JT.sun.withValues(alpha: 0.65),
                      JT.sun.withValues(alpha: 0),
                    ], stops: const [
                      0.5,
                      0.75,
                      1
                    ]),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: pako,
                    child: Transform.translate(
                      offset: Offset(
                          0, 40 * (1 - Curves.easeOutBack.transform(pako))),
                      child: const Pako(pose: PakoPose.wave, size: 170),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < word.length; i++)
                          Builder(builder: (context) {
                            final t = ((_c.value - 0.45 - i * 0.03) / 0.25)
                                .clamp(0.0, 1.0);
                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(
                                    0,
                                    14 *
                                        (1 - Curves.easeOutCubic.transform(t))),
                                child: Text(
                                  word[i],
                                  style: JTText.display.copyWith(
                                    color: i >= 8 ? JT.forestBright : JT.ink,
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: ((_c.value - 0.8) / 0.2).clamp(0.0, 1.0),
                    child: Text('Tahura Ir. H. Djuanda · Dago Pakar',
                        style: JTText.bodySm.copyWith(color: JT.muted)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
