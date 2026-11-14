import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import 'tab_stage.dart';

/// The search tab's sun band, the same motif as Home, that folds away as the list scrolls:
/// the headline fades, the band shrinks to a strip and the field keeps straddling its
/// scalloped edge.
///
/// Pako watches the field from the right edge of the screen, never fully in view. Open
/// band: large, leaning in over the canopy. Folded band: he ducks behind the canopy and a
/// small Pako leans in beside the field, which makes room for him. Either way his eyes
/// follow the text and he reacts to every keystroke.
class SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  SearchHeaderDelegate({
    required this.topPadding,
    required this.field,
    this.typed = 0,
    this.reaction = 0,
    this.hidePako = false,
    this.bare = false,
  });

  /// Heights below the status bar.
  static const expanded = 232.0;
  static const collapsed = 84.0;

  /// Scroll distance between the two.
  static const range = expanded - collapsed;

  static const _fieldHeight = 58.0;
  static const _fieldBottom = 10.0;

  // Sized so the sprout stays clear of the status bar, even while he reacts.
  static const _bigPako = 176.0;
  static const _smallPako = 84.0;

  /// How far the folded field pulls back from the right edge for the small Pako.
  static const _fieldInset = 38.0;

  /// Bottom of the sun band for a scroll offset: the field only dips its top into the
  /// band, so the canopy shows above it.
  static double bandBottom(double topPadding, double shrink) =>
      topPadding +
      expanded -
      shrink.clamp(0.0, range) -
      _fieldBottom -
      _fieldHeight +
      20;

  /// Height of the canopy edge, open (0) to folded (1).
  static double edgeAt(double t) => lerpDouble(56, 30, t.clamp(0.0, 1.0))!;

  final double topPadding;
  final Widget field;

  /// How far the text has grown, 0…1: Pako's eyes follow it.
  final double typed;

  /// Changes with every keystroke (see [Pako.reaction]).
  final int reaction;

  /// Pako leaves (the empty state has its own).
  final bool hidePako;

  /// The tab transition is drawing the band: only the content is built.
  final bool bare;

  @override
  double get maxExtent => topPadding + expanded;
  @override
  double get minExtent => topPadding + collapsed;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    final band = bandBottom(topPadding, shrinkOffset);
    final slow = JTMotion.of(context, JTMotion.slow);
    // 0 → 1 over the last stretch of the fold: the small Pako leans in
    final folded = ((t - 0.55) / 0.45).clamp(0.0, 1.0);

    // Large Pako, behind the canopy: his feet stay hidden, his right side is off screen.
    final big = Positioned(
      right: -_bigPako * 0.36,
      top: band - _bigPako * 0.9 - 24 + 70 * t,
      child: Opacity(
        opacity: (1 - t * 2.2).clamp(0.0, 1.0),
        child: AnimatedSlide(
          offset: hidePako ? const Offset(0.5, 0.7) : Offset.zero,
          duration: slow,
          curve: JTMotion.emphasized,
          child: Staged(
            // he belongs behind the page's own canopy, so he waits for it to land
            at: TabStage.settled,
            span: 0.6,
            from: const Offset(84, 36),
            curve: JTMotion.pop,
            exit: 1,
            child: ExcludeSemantics(
              child: Pako(
                pose: PakoPose.peek,
                size: _bigPako,
                shadow: false,
                look: Offset(-0.95 + 0.5 * typed, 0.85),
                reaction: reaction,
              ),
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        if (!bare) const Positioned.fill(child: ColoredBox(color: JT.cream)),
        if (!bare)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: band,
            child: SunBand(
              seed: TabStage.seed,
              edgeHeight: edgeAt(t),
              behindEdge: big,
            ),
          ),
        Positioned(
          left: JT.gutter,
          right: 126,
          top: topPadding + 14 - 18 * t,
          child: IgnorePointer(
            child: Opacity(
              opacity: (1 - t * 1.9).clamp(0.0, 1.0),
              child: Staged(
                from: const Offset(0, 12),
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
        ),
        // Small Pako, beside the folded field.
        Positioned(
          right: -28,
          bottom: 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: folded,
              child: Transform.translate(
                offset: Offset(40 * (1 - folded), 0),
                child: AnimatedSlide(
                  offset: hidePako ? const Offset(1, 0) : Offset.zero,
                  duration: slow,
                  curve: JTMotion.emphasized,
                  child: Staged(
                    at: 0.2,
                    span: 0.6,
                    from: const Offset(64, 0),
                    curve: JTMotion.pop,
                    exit: 1,
                    child: ExcludeSemantics(
                      child: Pako(
                        pose: PakoPose.peek,
                        size: _smallPako,
                        look: Offset(-1 + 0.55 * typed, 0.2),
                        reaction: reaction,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: JT.gutter,
          right: JT.gutter + _fieldInset * t,
          bottom: _fieldBottom,
          height: _fieldHeight,
          child: Staged(
            at: 0.08,
            from: const Offset(0, 14),
            scaleFrom: 0.96,
            child: field,
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(SearchHeaderDelegate old) =>
      old.topPadding != topPadding ||
      old.field != field ||
      old.typed != typed ||
      old.reaction != reaction ||
      old.hidePako != hidePako ||
      old.bare != bare;
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
  SearchRailDelegate({
    required this.child,
    required this.scrolled,
    this.bare = false,
  });

  static const height = 56.0;

  final Widget child;
  final ValueListenable<bool> scrolled;

  /// The tab transition is drawing the page behind: no background of its own.
  final bool bare;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      bare
          ? Center(child: child)
          : ValueListenableBuilder<bool>(
              valueListenable: scrolled,
              builder: (context, under, child) => AnimatedContainer(
                duration: JTMotion.base,
                decoration: BoxDecoration(
                  color: JT.cream,
                  border: Border(
                      bottom: BorderSide(
                          color: under ? JT.line : JT.cream, width: 1)),
                ),
                alignment: Alignment.center,
                child: child,
              ),
              child: child,
            );

  @override
  bool shouldRebuild(SearchRailDelegate old) =>
      old.child != child || old.scrolled != scrolled || old.bare != bare;
}
