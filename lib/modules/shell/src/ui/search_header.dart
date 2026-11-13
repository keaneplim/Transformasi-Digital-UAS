import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

/// The search tab's sun band, the same motif as Home, that folds away as the list scrolls:
/// the headline fades, Pako ducks behind the canopy, and the band shrinks to a strip with
/// the field still straddling its scalloped edge.
class SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  SearchHeaderDelegate({
    required this.topPadding,
    required this.field,
    this.look = const Offset(-0.5, 0.8),
    this.hidePako = false,
  });

  /// Heights below the status bar.
  static const expanded = 232.0;
  static const collapsed = 84.0;

  /// Scroll distance between the two.
  static const range = expanded - collapsed;

  static const _fieldHeight = 58.0;
  static const _fieldBottom = 10.0;

  final double topPadding;
  final Widget field;

  /// Where Pako's eyes point (they follow the text being typed).
  final Offset look;

  /// Pako ducks out of sight (the empty state has its own).
  final bool hidePako;

  @override
  double get maxExtent => topPadding + expanded;
  @override
  double get minExtent => topPadding + collapsed;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    final extent = maxExtent - shrinkOffset.clamp(0.0, range);
    // the field only dips its top into the band, so the canopy shows above it
    final band = extent - _fieldBottom - _fieldHeight + 20;
    final edge = lerpDouble(56, 30, t)!;
    const pako = 108.0;
    return ColoredBox(
      color: JT.cream,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: band,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: JT.sun),
                  const DoodlePattern(seed: 5),
                  // Pako peeks over the canopy at the field.
                  Positioned(
                    right: 14,
                    top: band - pako - 22 + 60 * t,
                    child: Opacity(
                      opacity: (1 - t * 2.2).clamp(0.0, 1.0),
                      child: AnimatedSlide(
                        offset: hidePako ? const Offset(0, 0.9) : Offset.zero,
                        duration: JTMotion.of(context, JTMotion.slow),
                        curve: JTMotion.emphasized,
                        child: ExcludeSemantics(
                          child: Pako(
                            pose: PakoPose.curious,
                            size: pako,
                            shadow: false,
                            look: look,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -1,
                    child: CanopyEdge(height: edge, seed: 5),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: JT.gutter,
            right: pako + 22,
            top: topPadding + 14 - 18 * t,
            child: IgnorePointer(
              child: Opacity(
                opacity: (1 - t * 1.9).clamp(0.0, 1.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.travel_explore_rounded,
                            size: 19, color: JT.ink),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('Cari & temukan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: JTText.label),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    HighlightHeadline(
                      before: 'Mau ke ',
                      highlight: 'mana',
                      after: '\nhari ini?',
                      style: JTText.display,
                      color: JT.forest,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: JT.gutter,
            right: JT.gutter,
            bottom: _fieldBottom,
            height: _fieldHeight,
            child: field,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(SearchHeaderDelegate old) =>
      old.topPadding != topPadding ||
      old.field != field ||
      old.look != look ||
      old.hidePako != hidePako;
}

/// The search field: a mint search disc that turns forest on focus, a hint that cycles
/// through things worth looking for, and a clear button that pops in with the first letter.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onClear,
    this.onSubmitted,
    this.hints = const ['gua', 'toilet', 'saung', 'rusa', 'musala', 'pinus'],
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String>? onSubmitted;
  final List<String> hints;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField>
    with SingleTickerProviderStateMixin {
  static const _perHint = Duration(milliseconds: 2800);

  late final AnimationController _cycle = AnimationController(
      vsync: this, duration: _perHint * widget.hints.length);
  final _hint = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _cycle.addListener(() {
      final n = widget.hints.length;
      _hint.value = (_cycle.value * n).floor().clamp(0, n - 1);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (JTMotion.reduced(context)) {
      _cycle.stop();
    } else if (!_cycle.isAnimating) {
      _cycle.repeat();
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    _hint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([widget.controller, widget.focus]),
        builder: (context, _) {
          final on = widget.focus.hasFocus;
          final empty = widget.controller.text.isEmpty;
          return AnimatedContainer(
            duration: JTMotion.base,
            curve: JTMotion.emphasized,
            padding: const EdgeInsets.only(left: 8, right: 6),
            decoration: BoxDecoration(
              color: JT.surface,
              borderRadius: BorderRadius.circular(29),
              border: Border.all(
                  color: on ? JT.forest : JT.line, width: on ? 2 : 1.2),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: JTMotion.base,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: on ? JT.forest : JT.mint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.search_rounded,
                      size: 21, color: on ? Colors.white : JT.forest),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (empty)
                        IgnorePointer(
                          child: ExcludeSemantics(
                            child:
                                _CyclingHint(index: _hint, hints: widget.hints),
                          ),
                        ),
                      TextField(
                        controller: widget.controller,
                        focusNode: widget.focus,
                        onChanged: widget.onChanged,
                        onSubmitted: widget.onSubmitted,
                        textInputAction: TextInputAction.search,
                        style: JTText.body,
                        cursorColor: JT.forest,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          // read by screen readers; the visible hint is the cycling one
                          hintText: 'Cari tempat atau fasilitas',
                          hintStyle:
                              JTText.body.copyWith(color: Colors.transparent),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedScale(
                  scale: empty ? 0 : 1,
                  duration: JTMotion.base,
                  curve: JTMotion.pop,
                  child: CircleIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Hapus',
                    size: 40,
                    iconSize: 18,
                    background: JT.cream,
                    foreground: JT.muted,
                    onTap: empty ? null : widget.onClear,
                  ),
                ),
              ],
            ),
          );
        },
      );
}

/// "Cari “gua”…" where the quoted word rolls up to the next suggestion.
class _CyclingHint extends StatelessWidget {
  const _CyclingHint({required this.index, required this.hints});

  final ValueListenable<int> index;
  final List<String> hints;

  @override
  Widget build(BuildContext context) {
    final style = JTText.body.copyWith(color: JT.faint);
    return Row(
      children: [
        Text('Cari ', style: style),
        Flexible(
          child: ClipRect(
            child: ValueListenableBuilder<int>(
              valueListenable: index,
              builder: (context, i, _) => AnimatedSwitcher(
                duration: JTMotion.of(context, JTMotion.slow),
                switchInCurve: JTMotion.emphasized,
                switchOutCurve: JTMotion.emphasized,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, if (current != null) current],
                ),
                transitionBuilder: (child, a) {
                  // the incoming word rises from below, the outgoing one leaves upwards
                  final incoming = child.key == ValueKey(i);
                  return FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                              begin: Offset(0, incoming ? 0.9 : -0.9),
                              end: Offset.zero)
                          .animate(a),
                      child: child,
                    ),
                  );
                },
                child: Text('“${hints[i]}”…',
                    key: ValueKey(i),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pinned strip under the header (the category rail); gains a hairline once the list
/// scrolls under it.
class SearchRailDelegate extends SliverPersistentHeaderDelegate {
  SearchRailDelegate({required this.child, required this.scrolled});

  static const height = 56.0;

  final Widget child;
  final ValueListenable<bool> scrolled;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ValueListenableBuilder<bool>(
        valueListenable: scrolled,
        builder: (context, under, child) => AnimatedContainer(
          duration: JTMotion.base,
          decoration: BoxDecoration(
            color: JT.cream,
            border: Border(
                bottom:
                    BorderSide(color: under ? JT.line : JT.cream, width: 1)),
          ),
          alignment: Alignment.center,
          child: child,
        ),
        child: child,
      );

  @override
  bool shouldRebuild(SearchRailDelegate old) =>
      old.child != child || old.scrolled != scrolled;
}
