import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:jelajah_taman/modules/content/content.dart';

import '../state/guide_controller.dart';
import '../state/places.dart';

/// UI02 personalisation: interests, then the Wellness Trail route.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _step = 0;
  PakoPose _pose = PakoPose.idle;

  void _finish() {
    ref.read(guideProvider).finishOnboarding();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(guideProvider);
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: JT.cream,
      body: Column(
        children: [
          SizedBox(height: pad.top + 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Kembali',
                  background: Colors.transparent,
                  onTap: () => _step == 0
                      ? context.go('/welcome')
                      : setState(() => _step = 0),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: _step == 0 ? 0.5 : 1),
                      duration: JTMotion.slow,
                      curve: JTMotion.emphasized,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 8,
                        backgroundColor: JT.line,
                        color: JT.forest,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text('${_step + 1}/2',
                    style: JTText.label.copyWith(color: JT.muted)),
                const SizedBox(width: 12),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: JTMotion.slow,
              switchInCurve: JTMotion.emphasized,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position:
                      Tween(begin: const Offset(0.08, 0), end: Offset.zero)
                          .animate(a),
                  child: child,
                ),
              ),
              child: _step == 0
                  ? _Interests(
                      key: const ValueKey(0),
                      pose: _pose,
                      onChanged: (c) {
                        demo.toggleInterest(c);
                        setState(() => _pose = demo.interests.contains(c)
                            ? PakoPose.cheer
                            : PakoPose.curious);
                      },
                    )
                  : const _Routes(key: ValueKey(1)),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + pad.bottom),
            child: PrimaryPill(
              label: _step == 0 ? 'Lanjut' : 'Mulai Jelajah',
              icon: _step == 0 ? null : Icons.explore_rounded,
              trailingIcon: _step == 0 ? Icons.arrow_forward_rounded : null,
              onTap: _step == 0
                  ? (demo.interests.isEmpty
                      ? null
                      : () => setState(() => _step = 1))
                  : _finish,
            ),
          ),
        ],
      ),
    );
  }
}

class _Interests extends ConsumerWidget {
  const _Interests({super.key, required this.pose, required this.onChanged});

  final PakoPose pose;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('sejarah', 'Sejarah', 'Gua, monumen, museum', Doodle.cave),
    ('alam', 'Alam', 'Pinus, rusa, tanaman', Doodle.pine),
    ('rekreasi', 'Rekreasi', 'Piknik dan bersantai', Doodle.butterfly),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      children: [
        Center(child: Pako(pose: pose, size: 130)),
        const SizedBox(height: 10),
        const HighlightHeadline(
          before: 'Apa yang ingin Anda ',
          highlight: 'temukan?',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
            'Pilih satu atau lebih. Rekomendasi tempat berikutnya akan menyesuaikan.',
            textAlign: TextAlign.center,
            style: JTText.body.copyWith(color: JT.muted)),
        const SizedBox(height: 22),
        for (final (i, (id, label, sub, doodle)) in _options.indexed)
          Entrance(
            delay: JTMotion.stagger * (i + 1),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InterestCard(
                label: label,
                sub: sub,
                doodle: doodle,
                tint: JT.category(id),
                selected: demo.interests.contains(id),
                onTap: () => onChanged(id),
              ),
            ),
          ),
      ],
    );
  }
}

class _InterestCard extends StatelessWidget {
  const _InterestCard({
    required this.label,
    required this.sub,
    required this.doodle,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final Doodle doodle;
  final Color tint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        child: Pressable(
          onTap: onTap,
          scale: 0.97,
          semanticLabel: label,
          child: AnimatedContainer(
            duration: JTMotion.base,
            curve: JTMotion.emphasized,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? Color.lerp(tint, JT.cream, 0.86) : JT.surface,
              borderRadius: BorderRadius.circular(JT.rCard),
              border: Border.all(
                  color: selected ? tint : JT.line, width: selected ? 2 : 1.2),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: JTMotion.base,
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: selected ? tint : Color.lerp(tint, JT.cream, 0.82),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: DoodleIcon(doodle,
                        size: 32,
                        color: selected ? Colors.white : tint,
                        stroke: 1.9),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: JTText.h3),
                      const SizedBox(height: 2),
                      Text(sub, style: JTText.bodySm.copyWith(color: JT.muted)),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: JTMotion.base,
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected ? tint : Colors.transparent,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: selected ? tint : JT.line, width: 2),
                  ),
                  child: AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: JTMotion.base,
                    curve: JTMotion.pop,
                    child: const Icon(Icons.check_rounded,
                        size: 17, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Routes extends ConsumerWidget {
  const _Routes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      children: [
        const HighlightHeadline(
          before: 'Pilih rute\n',
          highlight: 'sesuai tenaga',
          style: null,
        ),
        const SizedBox(height: 10),
        Text(
            'Semua rute dimulai dan berakhir di gerbang. Anda tetap bisa mampir ke tempat lain.',
            style: JTText.body.copyWith(color: JT.muted)),
        const SizedBox(height: 20),
        for (final (i, r) in demo.content.routes.indexed)
          Entrance(
            delay: JTMotion.stagger * (i + 1),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RouteCard(
                route: r,
                selected: demo.routeId == r.id,
                onTap: () => demo.chooseRoute(r.id),
              ),
            ),
          ),
      ],
    );
  }
}

/// Selectable route card with an elevation sparkline and a closing-time check.
class RouteCard extends ConsumerWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final TrailRoute route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    final graph = demo.content.graph;
    final elev = [
      for (final id in route.nodePath)
        if (graph.nodes[id] case final n?) n.elevationM,
    ];
    final ends = demo.now().add(Duration(minutes: route.durationMin));
    final fits = !ends.isAfter(demo.closingTime);
    final pois = route.poiSequence.toSet().length - 1;
    final color = switch (route.difficulty) {
      1 => JT.leaf,
      2 => JT.doodle,
      _ => JT.terracotta,
    };
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        scale: 0.98,
        semanticLabel: 'Rute ${route.name}',
        child: AnimatedContainer(
          duration: JTMotion.base,
          curve: JTMotion.emphasized,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: JT.surface,
            borderRadius: BorderRadius.circular(JT.rCard),
            border: Border.all(
                color: selected ? JT.forest : JT.line,
                width: selected ? 2.4 : 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(route.name, style: JTText.h2),
                  const SizedBox(width: 10),
                  for (var i = 0; i < 3; i++)
                    Container(
                      margin: const EdgeInsets.only(right: 3),
                      width: 14,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < route.difficulty ? color : JT.line,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(difficultyLabel(route.difficulty),
                      style: JTText.caption),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: JTMotion.base,
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: selected
                        ? const Icon(Icons.check_circle_rounded,
                            key: ValueKey('y'), color: JT.forest, size: 26)
                        : const Icon(Icons.circle_outlined,
                            key: ValueKey('n'), color: JT.line, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _Meta(Icons.straighten_rounded, '${km(route.distanceM)} km'),
                  _Meta(Icons.schedule_rounded,
                      minutesLabel(Duration(minutes: route.durationMin))),
                  _Meta(
                      Icons.trending_up_rounded, '+${route.ascentM.round()} m'),
                  _Meta(Icons.place_rounded, '$pois tempat'),
                ],
              ),
              const SizedBox(height: 10),
              Sparkline(
                  values: elev,
                  color: selected ? JT.forest : JT.faint,
                  height: 38),
              AnimatedSize(
                duration: JTMotion.base,
                curve: JTMotion.emphasized,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            Icon(
                                fits
                                    ? Icons.check_circle_rounded
                                    : Icons.error_rounded,
                                size: 17,
                                color: fits ? JT.leaf : JT.terracotta),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                fits
                                    ? 'Selesai sebelum kawasan tutup pukul ${clockLabel(demo.closingTime)}'
                                    : 'Lebih lama dari sisa waktu hari ini',
                                style: JTText.caption.copyWith(
                                    color: fits ? JT.forest : JT.terracotta,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: JT.muted),
          const SizedBox(width: 4),
          Text(text,
              style: JTText.bodySm.copyWith(fontWeight: FontWeight.w600)),
        ],
      );
}
