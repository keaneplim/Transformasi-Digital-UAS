import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'motion.dart';

/// The one primary action per screen: forest-green pill, white label, spring press.
class PrimaryPill extends StatelessWidget {
  const PrimaryPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.trailingIcon,
    this.color = JT.forest,
    this.foreground = Colors.white,
    this.height = 58,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color color;
  final Color foreground;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: JTText.button.copyWith(color: foreground)),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 10),
          Icon(trailingIcon, color: foreground, size: 20),
        ],
      ],
    );
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: JTMotion.base,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(
          color: enabled ? color : JT.line,
          borderRadius: BorderRadius.circular(JT.rChip),
        ),
        child: ExcludeSemantics(child: content),
      ),
    );
  }
}

/// Secondary action: soft mint fill (Ahead-style), ink label.
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color = JT.mint,
    this.foreground = JT.ink,
    this.height = 54,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;
  final Color foreground;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(JT.rChip),
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 19, color: foreground),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: JTText.label.copyWith(color: foreground)),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Round icon button (48 dp min), flat disc.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 48,
    this.background = JT.surface,
    this.foreground = JT.ink,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final double size;
  final Color background;
  final Color foreground;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Pressable(
          onTap: onTap,
          scale: 0.9,
          semanticLabel: tooltip,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: iconSize, color: foreground),
          ),
        ),
      );
}

/// "Lewati" chip on the sun band (Sliq's Skip).
class SkipChip extends StatelessWidget {
  const SkipChip({super.key, required this.onTap, this.label = 'Lewati'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: JT.surface,
            borderRadius: BorderRadius.circular(JT.rChip),
          ),
          child: Text(label, style: JTText.label, textAlign: TextAlign.center),
        ),
      );
}

/// Selectable chip with icon; pops when toggled.
class ChipToggle extends StatelessWidget {
  const ChipToggle({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.tint = JT.forest,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color tint;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : JT.ink;
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        scale: 0.92,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: JTMotion.base,
          curve: JTMotion.emphasized,
          constraints: BoxConstraints(minHeight: dense ? 40 : 48),
          padding: EdgeInsets.symmetric(
              horizontal: dense ? 14 : 18, vertical: dense ? 8 : 12),
          decoration: BoxDecoration(
            color: selected ? tint : JT.surface,
            borderRadius: BorderRadius.circular(JT.rChip),
            border: Border.all(
                color: selected ? tint : JT.line, width: selected ? 0 : 1.4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: JTMotion.base,
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: selected
                    ? Icon(Icons.check_rounded,
                        key: const ValueKey('on'), size: 18, color: fg)
                    : (icon != null
                        ? Icon(icon,
                            key: const ValueKey('off'), size: 18, color: tint)
                        : const SizedBox(key: ValueKey('none'))),
              ),
              if (selected || icon != null) const SizedBox(width: 8),
              Text(label,
                  style: (dense ? JTText.bodySm : JTText.label)
                      .copyWith(color: fg, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small coloured pill (category, reason, status).
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.icon,
    this.color = JT.forest,
    this.background,
    this.dot = false,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color? background;
  final bool dot;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: background ?? Color.lerp(color, JT.cream, 0.84),
          borderRadius: BorderRadius.circular(JT.rChip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: JTText.caption.copyWith(
                    color: Color.lerp(color, JT.ink, 0.35),
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

/// Soft card surface.
class JTCard extends StatelessWidget {
  const JTCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = JT.surface,
    this.onTap,
    this.radius = JT.rCard,
    this.border = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;
  final double radius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: JT.line, width: 1.2) : null,
      ),
      child: child,
    );
    return onTap == null
        ? box
        : Pressable(onTap: onTap, scale: 0.975, child: box);
  }
}

/// Headline where one word is painted green (Sliq's coloured "smarter").
class HighlightHeadline extends StatelessWidget {
  const HighlightHeadline({
    super.key,
    required this.before,
    required this.highlight,
    this.after = '',
    this.style,
    this.color = JT.forestBright,
    this.textAlign = TextAlign.start,
  });

  final String before;
  final String highlight;
  final String after;
  final TextStyle? style;
  final Color color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final s = style ?? JTText.hero;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: before),
        TextSpan(text: highlight, style: s.copyWith(color: color)),
        TextSpan(text: after),
      ]),
      style: s,
      textAlign: textAlign,
    );
  }
}

/// Fluid page indicator: the active dot stretches into a pill.
class PageDots extends StatelessWidget {
  const PageDots(
      {super.key,
      required this.count,
      required this.page,
      this.color = JT.forest});

  final int count;
  final double page;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Builder(builder: (context) {
              final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3.5),
                width: 8 + 22 * t,
                height: 8,
                decoration: BoxDecoration(
                  color: Color.lerp(JT.line, color, t),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
        ],
      );
}

/// Counts up to [value] whenever it changes (stats, summary).
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = JTMotion.lazy,
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: JTMotion.of(context, duration),
        curve: JTMotion.emphasized,
        builder: (context, v, _) => Text(format(v), style: style),
      );
}

/// Section title row with optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
      {super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(JT.gutter, 8, JT.gutter - 8, 12),
        child: Row(
          children: [
            Expanded(child: Text(title, style: JTText.h2)),
            if (action != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: JT.forest,
                  minimumSize: const Size(48, 44),
                ),
                child: Text(action!,
                    style: JTText.label.copyWith(color: JT.forest)),
              ),
          ],
        ),
      );
}

/// The little drag handle on sheets.
class Grabber extends StatelessWidget {
  const Grabber({super.key, this.color = JT.line});

  final Color color;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 42,
          height: 5,
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(5)),
        ),
      );
}

/// Opens a rounded modal sheet with the app's spring feel.
Future<T?> showJTSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color background = JT.surface,
  bool scrollControlled = true,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: scrollControlled,
      useSafeArea: true,
      backgroundColor: background,
      barrierColor: const Color(0x661C1B16),
      showDragHandle: false,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 420),
        reverseDuration: Duration(milliseconds: 260),
        curve: JTMotion.emphasized,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(JT.rSheet)),
      ),
      builder: builder,
    );
