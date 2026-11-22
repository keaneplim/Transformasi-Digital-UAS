import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../state/guide_controller.dart';
import '../state/places.dart';
import 'widgets.dart';

/// Root navigator key (set on the GoRouter) so sheets can open after a route pops.
final rootNavigatorKey = GlobalKey<NavigatorState>();
BuildContext? get rootNavigatorContext => rootNavigatorKey.currentContext;

/// Floats above every screen (it sits above the Navigator, so no Tooltip/Overlay widgets here):
/// UI04 approaching banner, UI05 trigger card, UI13 reminders; opens UI08 after a visit (F07).
class DemoOverlayHost extends ConsumerWidget {
  const DemoOverlayHost({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  void _push(String path) {
    final current = router.routerDelegate.currentConfiguration.uri.path;
    if (current != path) router.push(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    final approaching = demo.approaching;
    final trigger = demo.pendingTrigger;
    final reminder = demo.reminder;
    final path = router.routerDelegate.currentConfiguration.uri.path;
    final onAppScreens =
        demo.onboarded && path != '/' && path != '/welcome' && path != '/setup';

    // UC-F07-1: UI08 right after a visit, once the trigger card / reminder are out of the way.
    if (demo.recommendationCue != null &&
        trigger == null &&
        reminder == null &&
        onAppScreens) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = rootNavigatorContext;
        if (ctx == null || !demo.takeRecommendationCue()) return;
        showRecommendations(ctx);
      });
    }

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          child,
          // UI04
          AnimatedPositioned(
            duration: JTMotion.slow,
            curve: JTMotion.pop,
            left: 12,
            right: 12,
            top: approaching != null && trigger == null && onAppScreens
                ? MediaQuery.paddingOf(context).top + 8
                : -180,
            child: approaching == null
                ? const SizedBox(height: 100)
                : _ApproachBanner(
                    place: approaching.place,
                    distanceM: approaching.distanceM,
                    onClose: demo.dismissApproaching,
                  ),
          ),
          // UI05
          _Dimmer(visible: trigger != null && onAppScreens),
          AnimatedSwitcher(
            duration: JTMotion.lazy,
            switchInCurve: JTMotion.emphasized,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (c, a) => SlideTransition(
              position: Tween(begin: const Offset(0, 0.6), end: Offset.zero)
                  .animate(a),
              child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.0).animate(a),
                alignment: Alignment.bottomCenter,
                child: FadeTransition(opacity: a, child: c),
              ),
            ),
            child: trigger != null && onAppScreens
                ? Align(
                    key: ValueKey(trigger.id),
                    alignment: Alignment.bottomCenter,
                    child: _TriggerCard(
                      place: trigger,
                      onListen: () {
                        demo.resolveTrigger(
                            engaged: true, how: EngagementKind.listened);
                        demo.playAudio(trigger);
                        _push('/play/${trigger.id}');
                      },
                      onDetail: () {
                        demo.resolveTrigger(engaged: true);
                        _push('/poi/${trigger.id}');
                      },
                      onLater: () => demo.resolveTrigger(engaged: false),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
          // UI13
          _Dimmer(visible: reminder != null && trigger == null && onAppScreens),
          AnimatedSwitcher(
            duration: JTMotion.lazy,
            switchInCurve: JTMotion.emphasized,
            transitionBuilder: (c, a) => SlideTransition(
              position: Tween(begin: const Offset(0, 0.5), end: Offset.zero)
                  .animate(a),
              child: FadeTransition(opacity: a, child: c),
            ),
            child: reminder != null && trigger == null && onAppScreens
                ? Align(
                    key: ValueKey(reminder),
                    alignment: Alignment.bottomCenter,
                    child: _ReminderCard(
                      kind: reminder,
                      onNavigate: () {
                        if (demo.navigateForReminder(reminder)) {
                          _push('/navigate');
                        }
                      },
                      onLater: demo.dismissReminder,
                      onSnooze: demo.snoozeReminder,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
        ],
      ),
    );
  }
}

class _Dimmer extends StatelessWidget {
  const _Dimmer({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: JTMotion.slow,
          child: Container(color: JT.ink.withValues(alpha: 0.42)),
        ),
      );
}

class _ApproachBanner extends StatelessWidget {
  const _ApproachBanner(
      {required this.place, required this.distanceM, required this.onClose});

  final Place place;
  final double distanceM;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final r = place.poi?.radiusM ?? 25;
    final frac = ((distanceM - r) / 30).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      decoration: BoxDecoration(
        color: JT.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              PulseRings(
                color: place.tint,
                size: 52,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(color: place.tint, shape: BoxShape.circle),
                  child: Icon(place.icon, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vibration_rounded,
                            size: 14, color: JT.muted),
                        const SizedBox(width: 4),
                        Text('Hampir sampai', style: JTText.caption),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JTText.title),
                  ],
                ),
              ),
              AnimatedCount(
                value: distanceM,
                duration: JTMotion.base,
                format: (v) => '${v.round()} m',
                style: JTText.number(26, color: place.tint),
              ),
              IconButton(
                onPressed: onClose,
                icon:
                    const Icon(Icons.close_rounded, color: JT.muted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: 1 - frac),
                duration: JTMotion.base,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 5,
                  color: place.tint,
                  backgroundColor: place.tintSoft,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TriggerCard extends StatelessWidget {
  const _TriggerCard({
    required this.place,
    required this.onListen,
    required this.onDetail,
    required this.onLater,
  });

  final Place place;
  final VoidCallback onListen;
  final VoidCallback onDetail;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final secs = place.poi?.audioSeconds ?? 90;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          12, 0, 12, 12 + MediaQuery.paddingOf(context).bottom),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              decoration: BoxDecoration(
                color: JT.surface,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ANDA TIBA DI',
                      style: JTText.overline.copyWith(color: place.tint)),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 96),
                    child: Text(place.name, style: JTText.display),
                  ),
                  const SizedBox(height: 8),
                  Pill(
                      label: place.groupLabel,
                      icon: place.icon,
                      color: place.tint),
                  const SizedBox(height: 14),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: PlacePhoto(place: place, radius: 20, hero: false),
                  ),
                  const SizedBox(height: 14),
                  Text('Ingin mendengar ceritanya?', style: JTText.h3),
                  const SizedBox(height: 12),
                  PrimaryPill(
                    label:
                        'Dengarkan · ${durationClock(Duration(seconds: secs))}',
                    icon: Icons.play_arrow_rounded,
                    onTap: onListen,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: SoftButton(
                              label: 'Lihat detail', onTap: onDetail)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SoftButton(
                            label: 'Nanti', color: JT.cream, onTap: onLater),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Positioned(
              right: 8,
              top: -46,
              child: Pako(pose: PakoPose.curious, size: 112),
            ),
          ],
        ),
      ),
    );
  }
}

/// UI13: closing (A03) or hydration (F08) reminder. The main button navigates (gate / nearest
/// rest point); hydration snoozes for 10 minutes (#33), closing is "Nanti".
class _ReminderCard extends ConsumerWidget {
  const _ReminderCard(
      {required this.kind,
      required this.onNavigate,
      required this.onLater,
      required this.onSnooze});

  final GuideReminder kind;
  final VoidCallback onNavigate;
  final VoidCallback onLater;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    final finalCall = kind == GuideReminder.finalCall;
    final closing = kind == GuideReminder.closing || finalCall;
    final to = demo.reminderDestination(kind);
    final tint = closing ? JT.terracotta : JT.sky;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          12, 0, 12, 12 + MediaQuery.paddingOf(context).bottom),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: JT.surface,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 136,
                child: Stack(
                  children: [
                    Positioned.fill(
                        child: ColoredBox(
                            color: Color.lerp(
                                tint, JT.cream, finalCall ? 0.62 : 0.78)!)),
                    Positioned.fill(
                      child: DoodlePattern(
                          color:
                              tint.withValues(alpha: finalCall ? 0.45 : 0.35),
                          seed: closing ? 3 : 8,
                          iconSize: 26),
                    ),
                    Center(
                      child: Pako(
                          pose: closing ? PakoPose.sleepy : PakoPose.drink,
                          size: 122),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Pill(
                      label: finalCall
                          ? 'Panggilan terakhir'
                          : closing
                              ? 'Pengingat jam tutup'
                              : 'Waktunya istirahat',
                      icon: finalCall
                          ? Icons.warning_amber_rounded
                          : closing
                              ? Icons.schedule_rounded
                              : Icons.water_drop_rounded,
                      color: tint,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      finalCall
                          ? 'Segera menuju gerbang sekarang'
                          : closing
                              ? 'Kawasan tutup pukul ${clockLabel(demo.closingTime)}'
                              : demo.hydrationLine,
                      style: JTText.h2,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      finalCall
                          ? 'Waktu jalan ke gerbang sudah mepet dengan jam tutup kawasan.'
                          : closing
                              ? 'Mulai kembali sekarang agar tidak terburu-buru.'
                              : 'Istirahat sebentar di tempat teduh terdekat.',
                      style: JTText.body.copyWith(color: JT.muted),
                    ),
                    const SizedBox(height: 14),
                    if (closing)
                      Row(
                        children: [
                          Expanded(
                            child: _ReminderFact(
                              icon: Icons.door_front_door_rounded,
                              color: tint,
                              label: 'Ke gerbang',
                              value: '±${minutesLabel(demo.walkToGate)}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ReminderFact(
                              icon: Icons.lock_clock_rounded,
                              color: tint,
                              label: 'Kawasan tutup',
                              value: clockLabel(demo.closingTime),
                            ),
                          ),
                        ],
                      )
                    else
                      _RestTile(
                        place: to,
                        detail:
                            '${distanceLabel(demo.walkingM(to))} · ±${minutesLabel(demo.walkingTime(to))} jalan kaki',
                        onTap: onNavigate,
                      ),
                    const SizedBox(height: 16),
                    PrimaryPill(
                      label: closing
                          ? 'Navigasi ke gerbang'
                          : 'Navigasi ke tempat istirahat',
                      icon: Icons.navigation_rounded,
                      color: closing ? JT.terracotta : JT.forest,
                      onTap: onNavigate,
                    ),
                    const SizedBox(height: 8),
                    SoftButton(
                      label: closing ? 'Nanti' : 'Ingatkan 10 menit lagi',
                      icon: closing ? null : Icons.snooze_rounded,
                      color: JT.cream,
                      onTap: closing ? onLater : onSnooze,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One number on the closing reminder ("Ke gerbang ±25 mnt", "Kawasan tutup 16.00").
class _ReminderFact extends StatelessWidget {
  const _ReminderFact(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: Color.lerp(color, JT.cream, 0.9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JTText.caption),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(value, style: JTText.number(20)),
            ],
          ),
        ),
      );
}

/// The nearest rest point on the hydration reminder (UC-F08-3), tappable like the button.
class _RestTile extends StatelessWidget {
  const _RestTile(
      {required this.place, required this.detail, required this.onTap});

  final Place place;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: 'Tempat istirahat terdekat: ${place.name}, $detail',
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            color: JT.cream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: JT.line),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Color.lerp(place.tint, JT.cream, 0.8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(place.icon, color: place.tint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TEMPAT ISTIRAHAT TERDEKAT',
                        style: JTText.overline.copyWith(fontSize: 10.5)),
                    const SizedBox(height: 2),
                    Text(place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JTText.title),
                    Text(detail, style: JTText.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: JT.faint),
            ],
          ),
        ),
      );
}

/// UI08 "Berikutnya": 1 main recommendation + 2 alternatives with reasons, or back to the gate.
Future<void> showRecommendations(BuildContext context) => showJTSheet<void>(
      context,
      builder: (context) => const _RecommendationSheet(),
    );

class _RecommendationSheet extends ConsumerWidget {
  const _RecommendationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    final rec = demo.recommend();
    void navigate(Place p) {
      Navigator.of(context).pop();
      if (demo.startNavigation(p)) context.push('/navigate');
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Grabber(),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: rec.backToGate
                      ? HighlightHeadline(
                          before:
                              rec.allVisited ? 'Semua sudah,\n' : 'Waktunya\n',
                          highlight: rec.allVisited ? 'hebat!' : 'kembali',
                          style: JTText.display,
                          color:
                              rec.allVisited ? JT.forestBright : JT.terracotta,
                        )
                      : HighlightHeadline(
                          before: 'Berikutnya,\n',
                          highlight: 'ke sini?',
                          style: JTText.display,
                        ),
                ),
                Pako(
                  pose: rec.backToGate
                      ? (rec.allVisited ? PakoPose.cheer : PakoPose.sleepy)
                      : PakoPose.navigate,
                  size: 96,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (rec.backToGate) ...[
              Text(
                rec.allVisited
                    ? 'Semua tempat sudah Anda kunjungi. Saatnya kembali ke gerbang.'
                    : 'Waktu tidak cukup untuk mampir ke tempat lain sebelum kawasan tutup pukul ${clockLabel(demo.closingTime)}.',
                style: JTText.body.copyWith(color: JT.muted),
              ),
              const SizedBox(height: 12),
              Pill(
                label: gateWalkLabel(rec.gateWalk),
                icon: Icons.directions_walk_rounded,
                color: rec.allVisited ? JT.forest : JT.terracotta,
              ),
              const SizedBox(height: 16),
              PrimaryPill(
                label: 'Navigasi ke gerbang',
                icon: Icons.door_front_door_rounded,
                onTap: () => navigate(demo.gatePlace),
              ),
              if (rec.allVisited) ...[
                const SizedBox(height: 10),
                SoftButton(
                  label: 'Akhiri Jelajah',
                  icon: Icons.flag_rounded,
                  onTap: () {
                    Navigator.of(context).pop();
                    rootNavigatorContext?.push('/summary');
                  },
                ),
              ],
            ] else ...[
              _MainRec(item: rec.items.first, onNavigate: navigate),
              if (rec.items.length > 1) ...[
                const SizedBox(height: 18),
                Text('Atau', style: JTText.label.copyWith(color: JT.muted)),
                const SizedBox(height: 10),
                for (final (i, it) in rec.items.skip(1).indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Entrance(
                      delay: JTMotion.stagger * (i + 2),
                      child: PlaceTile(
                        place: it.place,
                        heroSuffix: '-rec',
                        onTap: () => navigate(it.place),
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MainRec extends ConsumerWidget {
  const _MainRec({required this.item, required this.onNavigate});

  final ({Place place, List<String> reasons}) item;
  final ValueChanged<Place> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    final p = item.place;
    return Entrance(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: JT.cream,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: JT.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 8,
              child: PlacePhoto(place: p, radius: 18, heroSuffix: '-recmain'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(p.name, style: JTText.h2)),
                Text(distanceLabel(demo.walkingM(p)), style: JTText.number(18)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                '${minutesLabel(demo.walkingTime(p))} jalan kaki · ±${p.poi!.visitMinutes} mnt di lokasi',
                style: JTText.caption),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in item.reasons.take(3))
                  Pill(
                      label: r,
                      icon: Icons.auto_awesome_rounded,
                      color: JT.forest),
              ],
            ),
            const SizedBox(height: 12),
            PrimaryPill(
              label: 'Navigasi ke sini',
              icon: Icons.navigation_rounded,
              onTap: () => onNavigate(p),
            ),
          ],
        ),
      ),
    );
  }
}
