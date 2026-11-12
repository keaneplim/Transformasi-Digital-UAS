import 'package:flutter/physics.dart';
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
