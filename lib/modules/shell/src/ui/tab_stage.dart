import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

/// Where a page's sun band sits on screen, so the tab transition can pick the canopy up
/// exactly where one page leaves it and set it down where the next one wants it.
@immutable
class BandGeometry {
  const BandGeometry({
    required this.shift,
    required this.bottom,
    required this.edge,
    this.body = 1,
  });

  /// How far the cream mist reaches below the canopy once the page body is gone.
  static const mist = 72.0;

  /// Top of the band (its doodles are anchored here); negative once the page has scrolled.
  final double shift;

  /// Bottom of the band = the foot of the canopy edge.
  final double bottom;

  /// Height of the canopy edge.
  final double edge;

  /// Opacity of the cream page body under the band (0 = the map shows).
  final double body;

  /// The same band lifted clear of the screen, with nothing under it: the map.
  BandGeometry lifted() =>
      BandGeometry(shift: shift, bottom: -(mist + 8), edge: edge, body: 0);

  static BandGeometry lerp(BandGeometry a, BandGeometry b, double t) =>
      BandGeometry(
        shift: lerpDouble(a.shift, b.shift, t)!,
        bottom: lerpDouble(a.bottom, b.bottom, t)!,
        edge: lerpDouble(a.edge, b.edge, t)!,
        body: lerpDouble(a.body, b.body, t)!.clamp(0.0, 1.0),
      );
}

/// Runs the choreography between the three tabs, in three acts:
///
/// 1. the content of the page being left clears out (its sun band stays);
/// 2. the canopy moves on its own: it folds up or down between Home and Search, lifts off
///    the top for the map (the cream body melts away under it) and comes back down from it;
/// 3. the content of the new page arrives, the header first, the rest once the canopy has
///    landed.
///
/// While the canopy moves it is drawn by [CanopyStage] and the pages draw no band of their
/// own ([bare]). A run can be redirected at any point; it carries on from wherever the
/// content and the canopy are.
class TabStage extends ChangeNotifier {
  TabStage({required TickerProvider vsync, int initial = home})
      : _shown = initial,
        _from = initial,
        _to = initial {
    _run = AnimationController(vsync: vsync, duration: duration)
      ..addListener(_tick)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      });
  }

  static const home = 0;
  static const map = 1;
  static const search = 2;

  /// One whole run. The canopy has landed (and the page can be touched) at [landed].
  static const duration = Duration(milliseconds: 760);

  /// Fractions of a run: content gone, canopy landed, first content arriving.
  static const cleared = 0.21;
  static const landed = 0.68;
  static const arriving = 0.50;

  /// Enter progress (see [Staged.at]) from which the canopy is sure to have landed:
  /// anything that would not sit right on a moving canopy starts here or later.
  static const settled = (landed - arriving) / (1 - arriving);

  /// The doodle/canopy seed every tab band and the stage share.
  static const seed = 11;

  /// One [StagePresence] per tab, read by the [Staged] pieces of that page.
  final presence = List.generate(3, (_) => StagePresence());

  /// True while the stage draws the sun band: pages leave out their own.
  final bare = ValueNotifier<bool>(false);

  /// Ticks when something structural changes (page shown, map underneath, touch blocked).
  final layout = ValueNotifier<int>(0);

  late final AnimationController _run;
  final _read = <int, BandGeometry Function()>{};
  final _onArrival = <VoidCallback>[];

  int _shown;
  int _from;
  int _to;
  bool _running = false;
  bool _swapped = true;
  bool _arrived = true;
  bool _mapUnder = false;
  double _enter0 = 1;
  double _exit0 = 0;
  BandGeometry? _g;
  BandGeometry? _gFrom;
  BandGeometry? _gTo;

  /// The tab whose page is on screen right now.
  int get shown => _shown;

  /// The band the stage is drawing, or null when the pages draw their own.
  BandGeometry? get geometry => bare.value ? _g : null;

  /// How much of the map the page body covers (0 on the map itself).
  double get cover => geometry?.body ?? 0;

  /// The map has to be on screen: it is the page shown, or it shows through the stage.
  bool get mapVisible => _shown == map || _mapUnder;

  /// Touches are held back until the new page's canopy has landed.
  bool get blocking => _running && !_arrived;

  /// A page with a sun band reports where it is.
  void attach(int tab, BandGeometry Function() read) => _read[tab] = read;

  void detach(int tab, BandGeometry Function() read) {
    if (_read[tab] == read) _read.remove(tab);
  }

  /// Runs [then] once the page on its way in can be used (now, if nothing is moving).
  void afterArrival(VoidCallback then) {
    if (blocking) {
      _onArrival.add(then);
    } else {
      then();
    }
  }

  /// Starts (or redirects) the transition to [to].
  void go(int to, {bool reduced = false}) {
    if (!_running && to == _shown) return;
    if (reduced) {
      _run.stop();
      _rest(to);
      return;
    }
    _from = _shown;
    _to = to;
    _enter0 = presence[_from].enter;
    _exit0 = presence[_from].exit;
    // a canopy already in flight carries on from where it is
    _gFrom = geometry;
    // (turning back to the map: the canopy finishes lifting off)
    _gTo = _from == _to ? _read[_to]?.call() ?? _gFrom?.lifted() : null;
    _swapped = _from == _to;
    _running = true;
    _arrived = false;
    _run.forward(from: 0);
    _mark();
  }

  void _tick() {
    final v = _run.value;
    if (_from == _to) {
      // turned back before the page had left: its content simply returns
      final k = Curves.easeOutCubic.transform((v / arriving).clamp(0.0, 1.0));
      presence[_to].set(
          enter: lerpDouble(_enter0, 1, k), exit: lerpDouble(_exit0, 0, k));
      if (bare.value) _fly((v / landed).clamp(0.0, 1.0));
      if (v >= landed) _land();
      notifyListeners();
      return;
    }
    if (!_swapped) {
      final x = (v / cleared).clamp(0.0, 1.0);
      presence[_from].set(exit: _exit0 + (1 - _exit0) * x);
      if (x < 1) return;
      _swap();
    }
    if (bare.value) {
      _fly(((v - cleared) / (landed - cleared)).clamp(0.0, 1.0));
    }
    if (v >= landed) _land();
    presence[_to]
        .set(enter: ((v - arriving) / (1 - arriving)).clamp(0.0, 1.0), exit: 0);
    notifyListeners();
  }

  /// The old page is empty: the stage takes over its band and the new page comes on.
  void _swap() {
    final a = _gFrom ?? _read[_from]?.call();
    final b = _read[_to]?.call();
    // the map has no band: seen from the other page, it is that page's band lifted away
    _gFrom = a ??
        b?.lifted() ??
        const BandGeometry(shift: 0, bottom: 0, edge: 64, body: 0);
    _gTo = b ?? _gFrom!.lifted();
    _g = _gFrom;
    _shown = _to;
    _swapped = true;
    presence[_to].set(enter: 0, exit: 0);
    bare.value = true;
    _mapUnder = _g!.body < 1;
    _mark();
  }

  void _fly(double t) {
    final from = _gFrom, to = _gTo;
    if (from == null || to == null) return;
    _g = BandGeometry.lerp(from, to, JTMotion.emphasized.transform(t));
    final under = _g!.body < 1;
    if (under != _mapUnder) {
      _mapUnder = under;
      _mark();
    }
  }

  /// The canopy is where the new page draws its own: hand the band back to the page.
  void _land() {
    if (_arrived) return;
    _arrived = true;
    bare.value = false;
    _g = null;
    _mapUnder = false;
    _mark();
    _flush();
  }

  void _finish() {
    _land();
    _running = false;
    presence[_to].set(enter: 1, exit: 0);
    _mark();
  }

  /// No motion: the new page is simply there.
  void _rest(int tab) {
    _shown = _from = _to = tab;
    _running = false;
    _swapped = true;
    _arrived = true;
    _mapUnder = false;
    _g = null;
    bare.value = false;
    for (final p in presence) {
      p.set(enter: 1, exit: 0);
    }
    _mark();
    _flush();
    notifyListeners();
  }

  void _flush() {
    final todo = List.of(_onArrival);
    _onArrival.clear();
    for (final f in todo) {
      f();
    }
  }

  void _mark() => layout.value++;

  @override
  void dispose() {
    _run.dispose();
    bare.dispose();
    layout.dispose();
    for (final p in presence) {
      p.dispose();
    }
    super.dispose();
  }
}

/// Hands the [TabStage] to the tabs.
class TabStageScope extends InheritedWidget {
  const TabStageScope({super.key, required this.stage, required super.child});

  final TabStage stage;

  static TabStage? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabStageScope>()?.stage;

  @override
  bool updateShouldNotify(TabStageScope old) => old.stage != stage;
}

/// The layer between the map and the pages that draws the travelling canopy: the cream
/// body (fading when the map is involved), a cream mist under the canopy so it never ends
/// in a hard line over the map, and the sun band itself.
class CanopyStage extends StatelessWidget {
  const CanopyStage({super.key, required this.stage});

  final TabStage stage;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ListenableBuilder(
          listenable: Listenable.merge([stage, stage.bare]),
          builder: (context, _) {
            final g = stage.geometry;
            if (g == null) return const SizedBox.shrink();
            final height = g.bottom - g.shift;
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: JT.cream.withValues(alpha: g.body)),
                Positioned(
                  left: 0,
                  right: 0,
                  top: g.bottom - 1,
                  height: BandGeometry.mist,
                  child: Opacity(
                    opacity: 1 - g.body,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [JT.cream, JT.cream.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: g.shift,
                  height: height > 0 ? height : 0,
                  child: SunBand(seed: TabStage.seed, edgeHeight: g.edge),
                ),
              ],
            );
          },
        ),
      );
}
