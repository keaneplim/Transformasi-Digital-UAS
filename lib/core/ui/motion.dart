import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Motion tokens (DESIGN.md §6). Motion explains state; it is never just decoration.
abstract final class JTMotion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 380);
  static const lazy = Duration(milliseconds: 620);
  static const stagger = Duration(milliseconds: 45);

  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const out = Curves.easeOutCubic;
  static const pop = Cubic(0.34, 1.56, 0.64, 1.0); // gentle overshoot

  static const pressSpring =
      SpringDescription(mass: 1, stiffness: 420, damping: 24);
  static const sheetSpring =
      SpringDescription(mass: 1, stiffness: 300, damping: 28);

  /// True when the OS asks for reduced motion: animations collapse to fades/instant.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Spring-scale on press + light haptic. Wraps any tappable surface.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.haptic = true,
    this.semanticLabel,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final String? semanticLabel;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  void _to(double target) {
    if (JTMotion.reduced(context)) {
      _c.value = target;
      return;
    }
    _c.animateWith(
        SpringSimulation(JTMotion.pressSpring, _c.value, target, _c.velocity));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    return Semantics(
      button: true,
      enabled: active,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: active ? (_) => _to(widget.scale) : null,
        onTapCancel: active ? () => _to(1) : null,
        onTapUp: active ? (_) => _to(1) : null,
        onTap: active
            ? () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) =>
              Transform.scale(scale: _c.value, child: child),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fades + slides a child in after [delay]. Lists stagger it via `delay`.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 18),
    this.duration = JTMotion.slow,
    this.scaleFrom = 1,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;
  final double scaleFrom;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (JTMotion.reduced(context)) return widget.child;
    final t = CurvedAnimation(parent: _c, curve: JTMotion.emphasized);
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) => Opacity(
        opacity: t.value.clamp(0, 1),
        child: Transform.translate(
          offset: widget.offset * (1 - t.value),
          child: Transform.scale(
            scale: widget.scaleFrom + (1 - widget.scaleFrom) * t.value,
            child: child,
          ),
        ),
      ),
      child: widget.child,
    );
  }
}

/// One clock for every ambient loop below it (doodle drift, canopy breathing), so two
/// copies of the same pattern are always in the same phase. A page and the transition
/// layer can then draw the same sun band and hand over without a jump.
class AmbientClock extends ChangeNotifier {
  AmbientClock(TickerProvider vsync) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  Duration _base = Duration.zero;

  /// Seconds the clock has been running (it stands still under reduced motion).
  double get seconds =>
      _elapsed.inMicroseconds / Duration.microsecondsPerSecond;

  set running(bool on) {
    if (on == _ticker.isActive) return;
    if (on) {
      _base = _elapsed; // a ticker counts from zero again every time it starts
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  void _tick(Duration sinceStart) {
    _elapsed = _base + sinceStart;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// Hands an [AmbientClock] to the ambient loops below it.
class AmbientScope extends InheritedWidget {
  const AmbientScope({super.key, required this.clock, required super.child});

  final AmbientClock clock;

  static AmbientClock? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AmbientScope>()?.clock;

  @override
  bool updateShouldNotify(AmbientScope old) => old.clock != clock;
}

/// How far a page's content is into a staged transition: [enter] runs 0 → 1 while the
/// content arrives, [exit] 0 → 1 while it leaves. At rest it is 1 and 0.
class StagePresence extends ChangeNotifier {
  double _enter = 1;
  double _exit = 0;

  double get enter => _enter;
  double get exit => _exit;

  void set({double? enter, double? exit}) {
    final e = enter ?? _enter;
    final x = exit ?? _exit;
    if (e == _enter && x == _exit) return;
    _enter = e;
    _exit = x;
    notifyListeners();
  }
}

/// Gives the [Staged] widgets below it their [StagePresence].
class StageScope extends InheritedWidget {
  const StageScope({super.key, required this.presence, required super.child});

  final StagePresence presence;

  static StagePresence? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StageScope>()?.presence;

  @override
  bool updateShouldNotify(StageScope old) => old.presence != presence;
}

/// A piece of a page that leaves and arrives with the page's [StagePresence]: it fades and
/// slides in from [from] once the enter progress passes [at], and leaves the way it came.
/// Without a [StageScope] above it, it is just its child.
class Staged extends StatelessWidget {
  const Staged({
    super.key,
    required this.child,
    this.at = 0,
    this.span = 0.5,
    this.from = const Offset(0, 16),
    this.scaleFrom = 1,
    this.curve = JTMotion.emphasized,
    this.exit = 0.4,
    this.alignment = Alignment.center,
  });

  final Widget child;

  /// Where in the enter progress (0…1) this piece starts, and how much of it it takes.
  final double at;
  final double span;

  /// Offset and scale it arrives from.
  final Offset from;
  final double scaleFrom;
  final Curve curve;

  /// How much of the way back to [from] it travels while leaving (1 = all the way).
  final double exit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final presence = StageScope.maybeOf(context);
    if (presence == null) return child;
    return AnimatedBuilder(
      animation: presence,
      child: child,
      builder: (context, child) {
        final p = ((presence.enter - at) / span).clamp(0.0, 1.0);
        final e = curve.transform(p);
        final x = Curves.easeInCubic.transform(presence.exit);
        final away = (1 - e) + exit * x;
        final scale = 1 - (1 - scaleFrom) * away;
        return Opacity(
          // the fade is done early, so an overshooting curve never shows half-faded
          opacity:
              (Curves.easeOut.transform((p * 1.6).clamp(0.0, 1.0)) * (1 - x))
                  .clamp(0.0, 1.0),
          child: Transform(
            transform: Matrix4.identity()
              ..translateByDouble(from.dx * away, from.dy * away, 0, 1)
              ..scaleByDouble(scale, scale, 1, 1),
            alignment: alignment,
            child: child,
          ),
        );
      },
    );
  }
}
