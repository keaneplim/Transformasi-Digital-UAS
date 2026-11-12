import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../demo/demo_controller.dart';
import '../demo/places.dart';
import '../demo/search.dart';
import 'main_shell.dart';
import 'widgets.dart';

/// UI09 Search + facility finder (F05, A04): name/synonym/typo-tolerant matching,
/// category filter, quick finds (toilet, musala, saung, gua), matches highlighted,
/// sorted by walking distance.
class SearchTab extends ConsumerStatefulWidget {
  const SearchTab({super.key});

  @override
  ConsumerState<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<SearchTab> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  String? _group;

  static const _groups = [
    (null, 'Semua', Icons.apps_rounded),
    ('sejarah', 'Sejarah', Icons.account_balance_rounded),
    ('alam', 'Alam', Icons.forest_rounded),
    ('rekreasi', 'Rekreasi', Icons.park_rounded),
    ('fasilitas', 'Fasilitas', Icons.wc_rounded),
  ];

  static const _suggestions = [
    'gua',
    'toilet',
    'musala',
    'saung',
    'rusa',
    'pinus'
  ];

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setQuery(String q) {
    _text.value = TextEditingValue(
        text: q, selection: TextSelection.collapsed(offset: q.length));
    setState(() => _query = q);
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(demoProvider);
    final pad = MediaQuery.paddingOf(context);
    final results = demo
        .nearest(group: _group)
        .where((p) => matchesQuery(p, _query))
        .toList();
    final browsing = _query.trim().isEmpty && _group == null;

    return GestureDetector(
      onTap: () => _focus.unfocus(),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(JT.gutter, pad.top + 16, 10, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cari & temukan',
                            style: JTText.title.copyWith(color: JT.muted)),
                        const SizedBox(height: 4),
                        HighlightHeadline(
                          before: 'Mau ke ',
                          highlight: 'mana',
                          after: '\nhari ini?',
                          style: JTText.display,
                        ),
                      ],
                    ),
                  ),
                  // Pako peeks down at the field, and thinks when nothing matches.
                  Pako(
                    pose:
                        results.isEmpty ? PakoPose.thinking : PakoPose.curious,
                    size: 92,
                    shadow: false,
                    look: const Offset(-0.5, 0.7),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedSearch(
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(JT.gutter, 12, JT.gutter, 12),
                    child: _Field(
                      controller: _text,
                      focus: _focus,
                      onChanged: (q) => setState(() => _query = q),
                      onClear: () => _setQuery(''),
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: JT.gutter),
                      itemCount: _groups.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final (id, label, icon) = _groups[i];
                        return ChipToggle(
                          label: label,
                          icon: icon,
                          dense: true,
                          tint: id == null ? JT.forest : JT.category(id),
                          selected: _group == id,
                          onTap: () => setState(() => _group = id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (browsing)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(JT.gutter, 18, JT.gutter, 4),
                child: _Shortcuts(onPick: _setQuery),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(JT.gutter, 20, JT.gutter, 10),
              child: AnimatedSwitcher(
                duration: JTMotion.base,
                child: results.isEmpty
                    ? const SizedBox.shrink()
                    : _ResultsHeader(
                        key: ValueKey('${results.length}$_query$_group'),
                        count: results.length,
                        query: _query.trim(),
                        browsing: browsing,
                      ),
              ),
            ),
          ),
          if (results.isEmpty)
            SliverToBoxAdapter(
              child: _Empty(
                  query: _query,
                  onSuggestion: (s) {
                    setState(() => _group = null);
                    _setQuery(s);
                  },
                  suggestions: _suggestions),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
              sliver: SliverList.separated(
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final p = results[i];
                  return Entrance(
                    key: ValueKey('${p.id}$_query$_group'),
                    delay: JTMotion.stagger * i.clamp(0, 8),
                    child: PlaceTile(
                      place: p,
                      heroSuffix: '-search',
                      highlight: _query,
                      eyebrow: i == 0 && browsing ? 'Terdekat' : null,
                      onTap: () => p.isPoi
                          ? context.push('/poi/${p.id}?hero=-search')
                          : openOnMap(ref, p.id),
                      trailing: _NavButton(place: p),
                    ),
                  );
                },
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 120 + pad.bottom)),
        ],
      ),
    );
  }
}

/// "12 tempat · terdekat dulu" or "3 hasil untuk “gua”".
class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader(
      {super.key,
      required this.count,
      required this.query,
      required this.browsing});

  final int count;
  final String query;
  final bool browsing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: browsing ? 'Semua tempat ' : '$count hasil ',
                    style: JTText.h3),
                if (!browsing && query.isNotEmpty)
                  TextSpan(
                      text: 'untuk “$query”',
                      style: JTText.h3.copyWith(color: JT.forestBright)),
                if (browsing)
                  TextSpan(
                      text: '$count',
                      style: JTText.number(15, color: JT.muted)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.swap_vert_rounded, size: 16, color: JT.muted),
          const SizedBox(width: 3),
          Text('Terdekat dulu', style: JTText.caption),
        ],
      );
}

/// Quick finds (A04): toilet, musala, saung, gua, each with the nearest walking distance.
class _Shortcuts extends ConsumerWidget {
  const _Shortcuts({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    double? nearestM(bool Function(Place) test) {
      final list = demo.places.where(test).map(demo.walkingM).toList()..sort();
      return list.isEmpty ? null : list.first;
    }

    final items = [
      (
        'Toilet',
        'toilet',
        Doodle.drop,
        JT.sky,
        nearestM((p) => !p.isPoi && p.kind == 'toilet')
      ),
      (
        'Musala',
        'musala',
        Doodle.sparkle,
        JT.forestBright,
        nearestM((p) => !p.isPoi && p.kind == 'musala')
      ),
      (
        'Saung',
        'saung',
        Doodle.bench,
        JT.doodle,
        nearestM((p) => !p.isPoi && p.kind == 'istirahat')
      ),
      (
        'Gua',
        'gua',
        Doodle.cave,
        JT.sejarah,
        nearestM((p) => p.id == 'P05' || p.id == 'P06')
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cepat temukan', style: JTText.h3),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (i, (label, query, doodle, color, m))
                in items.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Entrance(
                  delay: JTMotion.stagger * i,
                  scaleFrom: 0.9,
                  child: Pressable(
                    onTap: () => onPick(query),
                    scale: 0.94,
                    semanticLabel: 'Cari $label',
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
                      decoration: BoxDecoration(
                        color: JT.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Color.lerp(color, JT.cream, 0.8),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: DoodleIcon(doodle,
                                size: 26, color: color, stroke: 2),
                          ),
                          const SizedBox(height: 8),
                          Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: JTText.label),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(m == null ? '–' : distanceLabel(m),
                                style: JTText.number(12.5, color: JT.muted)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _NavButton extends ConsumerWidget {
  const _NavButton({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    return CircleIconButton(
      icon: Icons.navigation_rounded,
      tooltip: 'Navigasi ke ${place.name}',
      size: 44,
      iconSize: 20,
      background: JT.forest,
      foreground: Colors.white,
      onTap: () {
        if (demo.startNavigation(place)) context.push('/navigate');
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([controller, focus]),
        builder: (context, _) {
          final on = focus.hasFocus;
          return AnimatedContainer(
            duration: JTMotion.base,
            curve: JTMotion.emphasized,
            height: 58,
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
                  child: TextField(
                    controller: controller,
                    focusNode: focus,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    style: JTText.body,
                    cursorColor: JT.forest,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: 'Cari gua, toilet, saung…',
                      hintStyle: JTText.body.copyWith(color: JT.faint),
                    ),
                  ),
                ),
                AnimatedScale(
                  scale: controller.text.isEmpty ? 0 : 1,
                  duration: JTMotion.base,
                  curve: JTMotion.pop,
                  child: CircleIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Hapus',
                    size: 40,
                    iconSize: 18,
                    background: JT.cream,
                    foreground: JT.muted,
                    onTap: onClear,
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _Empty extends StatelessWidget {
  const _Empty(
      {required this.query,
      required this.onSuggestion,
      required this.suggestions});

  final String query;
  final ValueChanged<String> onSuggestion;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(JT.gutter, 4, JT.gutter, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            color: JT.surface,
            borderRadius: BorderRadius.circular(JT.rCard),
          ),
          child: Column(
            children: [
              Text(
                  query.trim().isEmpty
                      ? 'Belum ada tempat di sini'
                      : '“${query.trim()}” belum ketemu',
                  style: JTText.h2,
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('Coba kata lain, atau salah satu ini:',
                  textAlign: TextAlign.center,
                  style: JTText.body.copyWith(color: JT.muted)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in suggestions)
                    ChipToggle(
                        label: s,
                        icon: Icons.search_rounded,
                        selected: false,
                        dense: true,
                        onTap: () => onSuggestion(s)),
                ],
              ),
            ],
          ),
        ),
      );
}

/// Pinned field + chips; gains a hairline once the list scrolls under it.
class _PinnedSearch extends SliverPersistentHeaderDelegate {
  _PinnedSearch({required this.child});

  final Widget child;

  @override
  double get minExtent => 138;
  @override
  double get maxExtent => 138;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final under = overlapsContent || shrinkOffset > 0;
    return AnimatedContainer(
      duration: JTMotion.base,
      decoration: BoxDecoration(
        color: JT.cream,
        border: Border(
            bottom: BorderSide(color: under ? JT.line : JT.cream, width: 1)),
      ),
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_PinnedSearch old) => true;
}
