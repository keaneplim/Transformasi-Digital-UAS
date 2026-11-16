import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../state/guide_controller.dart';
import '../state/places.dart';
import '../state/search.dart';
import 'main_shell.dart';
import 'search_header.dart';
import 'search_sections.dart';
import 'tab_stage.dart';
import 'widgets.dart';

/// UI09 Search + facility finder (F05, A04).
///
/// A sun band like Home's that folds into a strip as the list scrolls (and as soon as the
/// field is focused), with the field straddling its edge. Below it: category chips with
/// live counts, then either the browsing page (recent searches, quick finds, the nearest
/// place worth a visit, every place) or the results (best match as a feature card, the rest
/// as rows with the match highlighted). Matching is name/synonym/typo-tolerant
/// (`state/search.dart`); the order is the visitor's choice (best match, nearest, A–Z).
///
/// Every piece is [Staged], so the page can clear out and come back in order when the tab
/// changes (see [TabStage]).
class SearchTab extends ConsumerStatefulWidget {
  const SearchTab({super.key});

  @override
  ConsumerState<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<SearchTab> {
  static const _range = SearchHeaderDelegate.range;
  static const _suggestions = [
    'gua',
    'toilet',
    'musala',
    'saung',
    'rusa',
    'pinus'
  ];

  final _text = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _underRail = ValueNotifier<bool>(false);
  String _query = '';
  String? _group;

  /// The visitor's explicit choice; null = the default for the situation.
  SearchSort? _sort;
  bool _snapping = false;

  /// Counts keystrokes: Pako reacts to each one.
  int _beat = 0;
  TabStage? _stage;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) _collapse();
    });
    _scroll.addListener(() => _underRail.value = _scroll.offset > _range + 2);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stage = TabStageScope.maybeOf(context);
    if (stage != _stage) {
      _stage?.detach(TabStage.search, _geometry);
      _stage?.bare.removeListener(_onBare);
      _stage = stage
        ?..attach(TabStage.search, _geometry)
        ..bare.addListener(_onBare);
    }
  }

  void _onBare() => setState(() {});

  /// Where the band is right now: open, folded, or in between.
  BandGeometry _geometry() {
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    return BandGeometry(
      shift: 0,
      bottom: SearchHeaderDelegate.bandBottom(
          MediaQuery.paddingOf(context).top, offset),
      edge: SearchHeaderDelegate.edgeAt(offset / _range),
    );
  }

  /// Opened to type (the map's search bar): the band is already folded when the page
  /// arrives, and the field takes focus as soon as it has.
  void _openTyping() {
    if (_scroll.hasClients) {
      final folded = math.min(_range, _scroll.position.maxScrollExtent);
      if (_scroll.offset < folded) _scroll.jumpTo(folded);
    }
    void focus() {
      if (mounted) _focus.requestFocus();
    }

    final stage = _stage;
    stage == null ? focus() : stage.afterArrival(focus);
  }

  @override
  void dispose() {
    _stage?.detach(TabStage.search, _geometry);
    _stage?.bare.removeListener(_onBare);
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    _underRail.dispose();
    super.dispose();
  }

  // ---- header choreography --------------------------------------------------------------

  /// Folds the sun band away so the results get the room (typing, keyboard up).
  void _collapse() {
    if (!_scroll.hasClients) return;
    final target = math.min(_range, _scroll.position.maxScrollExtent);
    if (_scroll.offset >= target) return;
    _scroll.animateTo(target,
        duration: JTMotion.of(context, JTMotion.slow),
        curve: JTMotion.emphasized);
  }

  /// A new query or filter starts at the top of its list, band state untouched.
  void _toListTop() {
    if (_scroll.hasClients && _scroll.offset > _range) _scroll.jumpTo(_range);
  }

  /// The band is never left half folded: it settles open or closed.
  bool _onScrollEnd(ScrollEndNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical || _snapping) {
      return false;
    }
    final px = n.metrics.pixels;
    if (px <= 0 || px >= _range) return false;
    final target = px < _range / 2 ? 0.0 : _range;
    _snapping = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && _scroll.hasClients) {
        await _scroll.animateTo(target,
            duration: JTMotion.of(context, JTMotion.base), curve: JTMotion.out);
      }
      _snapping = false;
    });
    return false;
  }

  // ---- query, filter, sort --------------------------------------------------------------

  void _onChanged(String q) {
    setState(() {
      _query = q;
      _beat++;
    });
    _toListTop();
  }

  void _setQuery(String q) {
    _text.value = TextEditingValue(
        text: q, selection: TextSelection.collapsed(offset: q.length));
    _onChanged(q);
  }

  void _setGroup(String? g) {
    setState(() => _group = g);
    _toListTop();
  }

  void _remember() => ref.read(recentSearchesProvider).add(_query);

  Future<void> _pickSort(SearchSort current, bool searching) async {
    _focus.unfocus();
    final picked = await showSearchSortSheet(context,
        current: current, searching: searching);
    if (picked != null && mounted) {
      setState(() => _sort = picked);
      _toListTop();
    }
  }

  // ---- what a place does ----------------------------------------------------------------

  void _open(Place p, {String hero = '-search'}) {
    _focus.unfocus();
    _remember();
    if (p.isPoi) {
      context.push('/poi/${p.id}?hero=$hero');
    } else {
      openOnMap(ref, p.id);
    }
  }

  void _navigate(Place p) {
    _focus.unfocus();
    _remember();
    if (ref.read(guideProvider).startNavigation(p)) context.push('/navigate');
  }

  Future<void> _peek(Place p) async {
    _focus.unfocus();
    unawaited(HapticFeedback.mediumImpact());
    final action = await showPlacePeek(context, p);
    if (action == null || !mounted) return;
    switch (action) {
      case PeekAction.navigate:
        _navigate(p);
      case PeekAction.map:
        _remember();
        openOnMap(ref, p.id);
      case PeekAction.detail:
        _remember();
        // no shared-element flight from a sheet that has just closed
        unawaited(context.push('/poi/${p.id}?hero=-peek'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(guideProvider);
    ref.listen(searchFocusProvider, (_, __) => _openTyping());
    final bare = _stage?.bare.value ?? false;
    // Arrival order: header and field ride in while the canopy settles, the rest follows
    // once it has landed.
    const body = TabStage.settled;
    final recents = ref.watch(recentSearchesProvider).items;
    final pad = MediaQuery.paddingOf(context);

    final q = _query.trim();
    final searching = q.isNotEmpty;
    final browsing = !searching && _group == null;

    final metres = <String, double>{};
    double distanceOf(Place p) => metres[p.id] ??= demo.walkingM(p);

    final all = searchPlaces(demo.places, q);
    final counts = <String, int>{};
    for (final h in all) {
      counts.update(h.place.group, (v) => v + 1, ifAbsent: () => 1);
    }
    final hits = [
      for (final h in all)
        if (_group == null || h.place.group == _group) h,
    ];
    final sort = searching
        ? (_sort ?? SearchSort.relevance)
        : (_sort == null || _sort == SearchSort.relevance
            ? SearchSort.nearest
            : _sort!);
    sortHits(hits, sort, distanceOf);

    final corrected = searching ? didYouMean(hits) : null;
    final highlight = corrected ?? q;

    // Best match up front, only while the list is in best-match order.
    final top = searching && sort == SearchSort.relevance && hits.isNotEmpty
        ? hits.first
        : null;
    final tied = hits.length > 1 && hits[0].score == hits[1].score;
    final rows = top == null ? hits : hits.sublist(1);

    // Browsing: the nearest sight not seen yet (and not the one underfoot).
    final spotlight = browsing
        ? demo
            .nearest(poisOnly: true)
            .where((p) =>
                !p.isGate &&
                !demo.visited.contains(p.id) &&
                distanceOf(p) >= 30)
            .firstOrNull
        : null;

    String? noteFor(SearchHit h) =>
        h.via == null ? null : 'Cocok dengan “${h.via}”';

    return GestureDetector(
      onTap: _focus.unfocus,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: _onScrollEnd,
        child: CustomScrollView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: SearchHeaderDelegate(
                topPadding: pad.top,
                hidePako: hits.isEmpty,
                bare: bare,
                // Pako's eyes follow the text as it grows, and he reacts to each letter
                typed: math.min(_query.length, 14) / 14,
                reaction: _beat,
                field: SearchField(
                  controller: _text,
                  focus: _focus,
                  onChanged: _onChanged,
                  onClear: () => _setQuery(''),
                  onSubmitted: (_) => _remember(),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: SearchRailDelegate(
                scrolled: _underRail,
                bare: bare,
                child: Staged(
                  at: body,
                  from: const Offset(28, 0),
                  child: SearchCategoryRail(
                    selected: _group,
                    counts: counts,
                    total: all.length,
                    onSelect: _setGroup,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            if (browsing && recents.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Staged(
                  at: body + 0.04,
                  child: SectionHeader(
                    title: 'Terakhir dicari',
                    action: 'Hapus semua',
                    onAction: ref.read(recentSearchesProvider).clear,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Staged(
                  at: body + 0.06,
                  child: SearchRecents(
                    items: recents,
                    onPick: _setQuery,
                    onRemove: ref.read(recentSearchesProvider).remove,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],
            if (browsing) ...[
              const SliverToBoxAdapter(
                  child: Staged(
                      at: body + 0.06,
                      child: SectionHeader(title: 'Cepat temukan'))),
              SliverToBoxAdapter(
                  child: Staged(
                      at: body + 0.09,
                      from: const Offset(28, 0),
                      child: SearchQuickFinds(onPick: _setQuery))),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],
            if (spotlight != null) ...[
              SliverToBoxAdapter(
                child: Staged(
                  at: body + 0.12,
                  child: SectionHeader(
                    title: 'Terdekat dari Anda',
                    action: 'Lihat peta',
                    onAction: () => openOnMap(ref, spotlight.id),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
                sliver: SliverToBoxAdapter(
                  child: Staged(
                    at: body + 0.14,
                    from: const Offset(0, 22),
                    child: Entrance(
                      delay: const Duration(milliseconds: 120),
                      child: SearchFeatureCard(
                        place: spotlight,
                        badge: 'Belum dikunjungi',
                        badgeIcon: Icons.near_me_rounded,
                        onTap: () => _open(spotlight, hero: '-spot'),
                        onNavigate: () => _navigate(spotlight),
                        onLongPress: () => _peek(spotlight),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
            ],
            if (!browsing) const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (corrected != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(JT.gutter, 0, JT.gutter, 16),
                sliver: SliverToBoxAdapter(
                  child: Staged(
                    at: body + 0.04,
                    child: Entrance(
                      key: ValueKey('fix-$corrected'),
                      child: SearchCorrection(corrected: corrected),
                    ),
                  ),
                ),
              ),
            if (hits.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
                sliver: SliverToBoxAdapter(
                  child: Staged(
                    at: body + 0.06,
                    scaleFrom: 0.96,
                    child: Entrance(
                      key: const ValueKey('empty'),
                      scaleFrom: 0.96,
                      child: SearchEmpty(
                        query: q,
                        group: _group,
                        elsewhere: all.length,
                        onAllCategories: () => _setGroup(null),
                        suggestions: _suggestions,
                        onSuggestion: (s) {
                          setState(() => _group = null);
                          _setQuery(s);
                        },
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Staged(
                  at: body + 0.06,
                  child: SearchResultsHeader(
                    count: hits.length,
                    query: corrected ?? q,
                    group: _group,
                    sort: sort,
                    onSort: () => _pickSort(sort, searching),
                  ),
                ),
              ),
            if (top != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(JT.gutter, 0, JT.gutter, 10),
                sliver: SliverToBoxAdapter(
                  child: Staged(
                    at: body + 0.09,
                    from: const Offset(0, 22),
                    child: Entrance(
                      key: ValueKey('top-${top.place.id}'),
                      child: SearchFeatureCard(
                        place: top.place,
                        badge: tied ? 'Terdekat' : 'Paling cocok',
                        badgeIcon: tied
                            ? Icons.near_me_rounded
                            : Icons.auto_awesome_rounded,
                        highlight: highlight,
                        note: noteFor(top),
                        heroSuffix: '-top',
                        onTap: () => _open(top.place, hero: '-top'),
                        onNavigate: () => _navigate(top.place),
                        onLongPress: () => _peek(top.place),
                      ),
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
              sliver: SliverList.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final h = rows[i];
                  final p = h.place;
                  return Staged(
                    // keyed by place: rows that stay while typing don't flash again
                    key: ValueKey('row-${p.id}'),
                    at: body + 0.1 + 0.02 * i.clamp(0, 4),
                    from: const Offset(0, 22),
                    child: Entrance(
                      delay: JTMotion.stagger * i.clamp(0, 8),
                      child: PlaceTile(
                        place: p,
                        heroSuffix: '-search',
                        highlight: highlight,
                        note: noteFor(h),
                        eyebrow:
                            i == 0 && browsing && sort == SearchSort.nearest
                                ? 'Terdekat'
                                : null,
                        onTap: () => _open(p),
                        onLongPress: () => _peek(p),
                        trailing: SearchNavButton(
                            place: p, onTap: () => _navigate(p)),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Room for the floating nav, and always enough to fold the band away, however
            // short the list is.
            SliverLayoutBuilder(
              builder: (context, c) => SliverToBoxAdapter(
                child: SizedBox(
                  height: math.max(
                      120 + pad.bottom,
                      c.viewportMainAxisExtent +
                          _range -
                          c.precedingScrollExtent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
