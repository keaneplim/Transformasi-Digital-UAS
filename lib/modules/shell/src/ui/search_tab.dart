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
/// category filter, sorted by walking distance.
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

    return GestureDetector(
      onTap: () => _focus.unfocus(),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  EdgeInsets.fromLTRB(JT.gutter, pad.top + 18, JT.gutter, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: HighlightHeadline(
                      before: 'Mau ke ',
                      highlight: 'mana?',
                      style: JTText.display,
                    ),
                  ),
                  const Pako(pose: PakoPose.curious, size: 64, shadow: false),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedSearch(
              top: pad.top,
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(JT.gutter, 10, JT.gutter, 10),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(JT.gutter, 14, JT.gutter, 8),
              child: AnimatedSwitcher(
                duration: JTMotion.base,
                child: Text(
                  key: ValueKey('${results.length}$_query$_group'),
                  results.isEmpty
                      ? ''
                      : '${results.length} tempat · terdekat dari posisi Anda',
                  style: JTText.caption,
                ),
              ),
            ),
          ),
          if (results.isEmpty)
            SliverToBoxAdapter(
              child: _Empty(
                  query: _query,
                  onSuggestion: _setQuery,
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
                      onTap: () => p.isPoi
                          ? context.push('/poi/${p.id}?hero=-search')
                          : openOnMap(ref, p.id),
                      trailing: _NavTrailing(place: p),
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

class _NavTrailing extends ConsumerWidget {
  const _NavTrailing({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(distanceLabel(demo.walkingM(place)), style: JTText.number(15)),
            const SizedBox(height: 4),
            Text(minutesLabel(demo.walkingTime(place)), style: JTText.caption),
          ],
        ),
        const SizedBox(width: 10),
        CircleIconButton(
          icon: Icons.navigation_rounded,
          tooltip: 'Navigasi ke ${place.name}',
          size: 44,
          iconSize: 20,
          background: JT.forest,
          foreground: Colors.white,
          onTap: () {
            if (demo.startNavigation(place)) context.push('/navigate');
          },
        ),
      ],
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
        builder: (context, _) => AnimatedContainer(
          duration: JTMotion.base,
          height: 54,
          decoration: BoxDecoration(
            color: JT.surface,
            borderRadius: BorderRadius.circular(27),
            border: Border.all(
                color: focus.hasFocus ? JT.forest : JT.line,
                width: focus.hasFocus ? 2 : 1.2),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(Icons.search_rounded,
                  color: focus.hasFocus ? JT.forest : JT.muted),
              const SizedBox(width: 10),
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
                    hintText: 'Coba "gua" atau "toilet"',
                    hintStyle: JTText.body.copyWith(color: JT.faint),
                  ),
                ),
              ),
              AnimatedScale(
                scale: controller.text.isEmpty ? 0 : 1,
                duration: JTMotion.base,
                curve: JTMotion.pop,
                child: IconButton(
                  tooltip: 'Hapus',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, color: JT.muted),
                ),
              ),
            ],
          ),
        ),
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
        padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
        child: Column(
          children: [
            const Pako(pose: PakoPose.thinking, size: 130),
            const SizedBox(height: 10),
            Text('"$query" belum ketemu',
                style: JTText.h2, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Coba kata lain, atau pilih salah satu di bawah.',
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
                      selected: false,
                      dense: true,
                      onTap: () => onSuggestion(s)),
              ],
            ),
          ],
        ),
      );
}

class _PinnedSearch extends SliverPersistentHeaderDelegate {
  _PinnedSearch({required this.top, required this.child});

  final double top;
  final Widget child;

  @override
  double get minExtent => 128;
  @override
  double get maxExtent => 128;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(
        color: JT.cream
            .withValues(alpha: overlapsContent || shrinkOffset > 0 ? 0.97 : 1),
        alignment: Alignment.topCenter,
        child: child,
      );

  @override
  bool shouldRebuild(_PinnedSearch old) => true;
}
