import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../state/guide_controller.dart';
import '../state/places.dart';
import '../state/search.dart';
import 'widgets.dart';

// Building blocks of the search tab (UI09). The page itself is in search_tab.dart.

/// Category filter (F05): one chip per group with the number of places it would show for
/// the current query, so a visitor sees where the matches are before tapping.
class SearchCategoryRail extends StatelessWidget {
  const SearchCategoryRail({
    super.key,
    required this.selected,
    required this.counts,
    required this.total,
    required this.onSelect,
  });

  static const groups = ['sejarah', 'alam', 'rekreasi', 'fasilitas'];

  /// Null = all categories.
  final String? selected;
  final Map<String, int> counts;
  final int total;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
          children: [
            _CountChip(
              label: 'Semua',
              icon: Icons.apps_rounded,
              tint: JT.forest,
              count: total,
              selected: selected == null,
              onTap: () => onSelect(null),
            ),
            for (final g in groups) ...[
              const SizedBox(width: 8),
              _CountChip(
                label: categoryLabel(g),
                icon: categoryIcon(g),
                tint: JT.category(g),
                count: counts[g] ?? 0,
                selected: selected == g,
                // tapping the active category goes back to all
                onTap: () => onSelect(selected == g ? null : g),
              ),
            ],
          ],
        ),
      );
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.icon,
    required this.tint,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : JT.ink;
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        scale: 0.93,
        semanticLabel: '$label, $count tempat',
        child: AnimatedOpacity(
          duration: JTMotion.base,
          opacity: count == 0 && !selected ? 0.5 : 1,
          child: AnimatedContainer(
            duration: JTMotion.base,
            curve: JTMotion.emphasized,
            padding: const EdgeInsets.only(left: 12, right: 6),
            decoration: BoxDecoration(
              color: selected ? tint : JT.surface,
              borderRadius: BorderRadius.circular(JT.rChip),
              border: Border.all(color: selected ? tint : JT.line, width: 1.4),
            ),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: selected ? Colors.white : tint),
                  const SizedBox(width: 7),
                  Text(label,
                      style: JTText.bodySm
                          .copyWith(color: fg, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: JTMotion.base,
                    constraints:
                        const BoxConstraints(minWidth: 26, minHeight: 26),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : JT.cream,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: AnimatedSwitcher(
                      duration: JTMotion.of(context, JTMotion.base),
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: a, child: c),
                      ),
                      child: Text('$count',
                          key: ValueKey(count),
                          style: JTText.number(12.5,
                              color: selected ? Colors.white : JT.muted)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick finds (A04): the things people ask a ranger for, each with the walk to the
/// nearest one. A tap searches for it.
class SearchQuickFinds extends ConsumerWidget {
  const SearchQuickFinds({super.key, required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    double? nearestM(bool Function(Place) test) {
      final list = demo.places.where(test).map(demo.walkingM).toList()..sort();
      return list.isEmpty ? null : list.first;
    }

    bool facility(Place p, String kind) => !p.isPoi && p.kind == kind;
    final items = [
      (
        'Toilet',
        'toilet',
        Doodle.drop,
        JT.sky,
        (Place p) => facility(p, 'toilet')
      ),
      (
        'Musala',
        'musala',
        Doodle.sparkle,
        JT.forestBright,
        (Place p) => facility(p, 'musala')
      ),
      (
        'Saung',
        'saung',
        Doodle.bench,
        JT.doodle,
        (Place p) => facility(p, 'istirahat')
      ),
      (
        'Gua',
        'gua',
        Doodle.cave,
        JT.sejarah,
        (Place p) => p.id == 'P05' || p.id == 'P06'
      ),
      (
        'Warung',
        'warung',
        Doodle.mushroom,
        JT.rekreasi,
        (Place p) => facility(p, 'warung')
      ),
      (
        'Petugas',
        'petugas',
        Doodle.compass,
        JT.fasilitas,
        (Place p) => facility(p, 'pos_petugas')
      ),
    ];
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (label, query, doodle, color, test) = items[i];
          final m = nearestM(test);
          return Entrance(
            delay: JTMotion.stagger * i,
            offset: const Offset(24, 0),
            child: Pressable(
              onTap: () => onPick(query),
              scale: 0.95,
              semanticLabel: m == null
                  ? 'Cari $label'
                  : 'Cari $label, terdekat ${distanceLabel(m)}',
              child: Container(
                width: 100,
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                decoration: BoxDecoration(
                  color: JT.surface,
                  borderRadius: BorderRadius.circular(JT.rCard),
                ),
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const Spacer(),
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: JTText.title),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.directions_walk_rounded,
                              size: 14, color: JT.forestBright),
                          const SizedBox(width: 2),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(m == null ? '–' : distanceLabel(m),
                                  style: JTText.number(13, color: JT.muted)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Terakhir dicari": the visitor's own recent queries as chips. Tap to search again,
/// the small cross forgets one.
class SearchRecents extends StatelessWidget {
  const SearchRecents({
    super.key,
    required this.items,
    required this.onPick,
    required this.onRemove,
  });

  final List<String> items;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final q = items[i];
            return Container(
              key: ValueKey(q),
              decoration: BoxDecoration(
                color: JT.surface,
                borderRadius: BorderRadius.circular(JT.rChip),
                border: Border.all(color: JT.line, width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Pressable(
                    onTap: () => onPick(q),
                    scale: 0.95,
                    semanticLabel: 'Cari lagi $q',
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history_rounded,
                                size: 17, color: JT.muted),
                            const SizedBox(width: 7),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(q,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: JTText.bodySm
                                      .copyWith(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Pressable(
                    onTap: () => onRemove(q),
                    scale: 0.85,
                    semanticLabel: 'Hapus $q dari riwayat',
                    child: const SizedBox(
                      width: 40,
                      height: 44,
                      child:
                          Icon(Icons.close_rounded, size: 16, color: JT.faint),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
}

/// The one place the page puts forward: a wide polaroid (inset photo, badge, name, walk)
/// with the single forest-green navigate button. Used for the nearest place worth a visit
/// while browsing and for the best match while searching.
class SearchFeatureCard extends ConsumerWidget {
  const SearchFeatureCard({
    super.key,
    required this.place,
    required this.badge,
    required this.badgeIcon,
    required this.onTap,
    required this.onNavigate,
    this.onLongPress,
    this.highlight = '',
    this.note,
    this.heroSuffix = '-spot',
  });

  final Place place;
  final String badge;
  final IconData badgeIcon;
  final VoidCallback onTap;
  final VoidCallback onNavigate;
  final VoidCallback? onLongPress;
  final String highlight;
  final String? note;
  final String heroSuffix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    final visited = demo.visited.contains(place.id);
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: 0.98,
      semanticLabel: '$badge: ${place.name}',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: JT.surface,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlacePhoto(place: place, radius: 19, heroSuffix: heroSuffix),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Pill(
                      label: badge,
                      icon: badgeIcon,
                      color: JT.forest,
                      background: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  if (visited)
                    const Positioned(
                        right: 10, top: 10, child: VisitedTick(size: 28)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CategoryLabel(place: place),
                        const SizedBox(height: 4),
                        MatchText(place.name,
                            highlight: highlight,
                            maxLines: 2,
                            style: JTText.h3),
                        const SizedBox(height: 6),
                        WalkMeta(place: place),
                        if (note != null) ...[
                          const SizedBox(height: 5),
                          MatchNote(note!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleIconButton(
                    icon: Icons.navigation_rounded,
                    tooltip: 'Navigasi ke ${place.name}',
                    size: 52,
                    iconSize: 22,
                    background: JT.forest,
                    foreground: Colors.white,
                    onTap: onNavigate,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet navigate button on a result row (the feature card owns the loud one).
class SearchNavButton extends StatelessWidget {
  const SearchNavButton({super.key, required this.place, required this.onTap});

  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CircleIconButton(
        icon: Icons.navigation_rounded,
        tooltip: 'Navigasi ke ${place.name}',
        size: 48,
        iconSize: 20,
        background: JT.mint,
        foreground: JT.forest,
        onTap: onTap,
      );
}

/// "Semua tempat 21", "Sejarah 4" or "5 hasil untuk “gua”" (the query only while it is
/// short), with the sort control.
class SearchResultsHeader extends StatelessWidget {
  const SearchResultsHeader({
    super.key,
    required this.count,
    required this.query,
    required this.group,
    required this.sort,
    required this.onSort,
  });

  final int count;
  final String query;
  final String? group;
  final SearchSort sort;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    final searching = query.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(JT.gutter, 0, JT.gutter, 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text.rich(
                TextSpan(children: [
                  if (searching) ...[
                    TextSpan(text: '$count hasil'),
                    // the query is in the field right above: repeat it only when short
                    if (query.length <= 8)
                      TextSpan(
                          text: ' untuk “$query”',
                          style: JTText.h2.copyWith(color: JT.forestBright)),
                  ] else ...[
                    TextSpan(
                        text: group == null
                            ? 'Semua tempat '
                            : '${categoryLabel(group!)} '),
                    TextSpan(
                        text: '$count',
                        style: JTText.number(17, color: JT.muted)),
                  ],
                ]),
                style: JTText.h2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Pressable(
            onTap: onSort,
            scale: 0.94,
            semanticLabel: 'Urutkan, sekarang ${sortLabel(sort)}',
            child: Container(
              height: 40,
              padding: const EdgeInsets.only(left: 11, right: 14),
              decoration: BoxDecoration(
                color: JT.surface,
                borderRadius: BorderRadius.circular(JT.rChip),
                border: Border.all(color: JT.line, width: 1.2),
              ),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_vert_rounded,
                        size: 17, color: JT.forest),
                    const SizedBox(width: 5),
                    AnimatedSwitcher(
                      duration: JTMotion.of(context, JTMotion.base),
                      child: Text(sortLabel(sort),
                          key: ValueKey(sort),
                          style: JTText.bodySm
                              .copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String sortLabel(SearchSort s) => switch (s) {
      SearchSort.relevance => 'Paling cocok',
      SearchSort.nearest => 'Terdekat',
      SearchSort.name => 'Nama A–Z',
    };

/// "Menampilkan hasil untuk pinus": shown when the query only matched through typo
/// tolerance, so the visitor knows how it was read.
class SearchCorrection extends StatelessWidget {
  const SearchCorrection({super.key, required this.corrected});

  final String corrected;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: JT.mint,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_fix_high_rounded, size: 18, color: JT.forest),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Menampilkan hasil untuk '),
                  TextSpan(
                      text: '“$corrected”',
                      style: JTText.bodySm.copyWith(
                          color: JT.forest, fontWeight: FontWeight.w800)),
                ]),
                style: JTText.bodySm,
              ),
            ),
          ],
        ),
      );
}

/// Nothing matched: Pako thinks it over on a mint doodle band, then offers a way out
/// (matches in the other categories, or a few things that do exist).
class SearchEmpty extends StatelessWidget {
  const SearchEmpty({
    super.key,
    required this.query,
    required this.group,
    required this.elsewhere,
    required this.onAllCategories,
    required this.suggestions,
    required this.onSuggestion,
  });

  final String query;
  final String? group;

  /// Matches for the same query outside the selected category.
  final int elsewhere;
  final VoidCallback onAllCategories;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final inGroup = group == null ? '' : ' di ${categoryLabel(group!)}';
    return Container(
      decoration: BoxDecoration(
        color: JT.surface,
        borderRadius: BorderRadius.circular(JT.rCard),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 116,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: JT.mint),
                const DoodlePattern(
                    color: JT.mintDeep, seed: 21, cell: 52, iconSize: 24),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: -24,
                  child: Center(
                    child:
                        Pako(pose: PakoPose.thinking, size: 116, shadow: false),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              children: [
                Text(
                    query.isEmpty
                        ? 'Belum ada tempat$inGroup'
                        : '“$query” belum ketemu$inGroup',
                    style: JTText.h2,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                    elsewhere > 0
                        ? 'Tetapi ada $elsewhere tempat yang cocok di kategori lain.'
                        : 'Coba kata lain, atau salah satu ini:',
                    textAlign: TextAlign.center,
                    style: JTText.body.copyWith(color: JT.muted)),
                const SizedBox(height: 16),
                if (elsewhere > 0)
                  SoftButton(
                    label: 'Lihat di semua kategori',
                    icon: Icons.apps_rounded,
                    expand: false,
                    onTap: onAllCategories,
                  )
                else
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
        ],
      ),
    );
  }
}

Widget _sheetCard({required List<Widget> children}) => SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        decoration: BoxDecoration(
            color: JT.surface, borderRadius: BorderRadius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [const Grabber(), ...children],
        ),
      ),
    );

/// Sort sheet: returns the chosen order, or null when dismissed. "Paling cocok" is only
/// offered while there is a query to be relevant to.
Future<SearchSort?> showSearchSortSheet(
  BuildContext context, {
  required SearchSort current,
  required bool searching,
}) =>
    showJTSheet<SearchSort>(
      context,
      background: Colors.transparent,
      builder: (context) {
        Widget option(SearchSort s, IconData icon, String sub) {
          final on = s == current;
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              selected: on,
              child: Pressable(
                onTap: () => Navigator.of(context).pop(s),
                scale: 0.98,
                semanticLabel: '${sortLabel(s)}. $sub',
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: on ? JT.mint : JT.cream,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: on ? JT.forest : Colors.transparent, width: 2),
                  ),
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: on ? JT.forest : JT.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon,
                              size: 21, color: on ? Colors.white : JT.forest),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sortLabel(s), style: JTText.title),
                              const SizedBox(height: 2),
                              Text(sub, style: JTText.caption),
                            ],
                          ),
                        ),
                        if (on)
                          const Icon(Icons.check_circle_rounded,
                              color: JT.forest, size: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return _sheetCard(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
            child: Text('Urutkan', style: JTText.h2),
          ),
          if (searching)
            option(SearchSort.relevance, Icons.auto_awesome_rounded,
                'Nama yang paling sesuai lebih dulu'),
          option(SearchSort.nearest, Icons.near_me_rounded,
              'Jalan kaki terpendek lebih dulu'),
          option(SearchSort.name, Icons.sort_by_alpha_rounded,
              'Urut abjad dari A sampai Z'),
        ]);
      },
    );

/// What the visitor chose in the preview sheet.
enum PeekAction { navigate, map, detail }

/// Long-press preview of a place: photo, a few lines, and the three things one can do
/// with it, without leaving the list. Returns the chosen action.
Future<PeekAction?> showPlacePeek(BuildContext context, Place place) =>
    showJTSheet<PeekAction>(
      context,
      background: Colors.transparent,
      builder: (context) => _PlacePeek(place: place),
    );

class _PlacePeek extends ConsumerWidget {
  const _PlacePeek({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    final visited = demo.visited.contains(place.id);
    final poi = place.poi;
    final blurb = poi == null
        ? null
        : ((poi.draftText ?? '').trim().isNotEmpty ? poi.draftText : poi.text)
            ?.trim();
    void done(PeekAction a) => Navigator.of(context).pop(a);
    return _sheetCard(children: [
      const SizedBox(height: 4),
      SizedBox(
        height: 168,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PlacePhoto(place: place, radius: 20, hero: false),
            Positioned(
              left: 10,
              top: 10,
              child: Pill(
                label: place.groupLabel,
                icon: place.icon,
                color: place.tint,
                background: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            if (visited)
              Positioned(
                right: 10,
                top: 10,
                child: Pill(
                  label: 'Dikunjungi',
                  icon: Icons.check_rounded,
                  color: JT.leaf,
                  background: Colors.white.withValues(alpha: 0.95),
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.name, style: JTText.h2),
            const SizedBox(height: 6),
            Row(
              children: [
                Flexible(child: WalkMeta(place: place)),
                Flexible(
                  child: Text(
                      demo.outsideZone || demo.noPosition
                          ? ' dari gerbang'
                          : ' jalan kaki',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JTText.caption),
                ),
              ],
            ),
            if (blurb != null && blurb.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(blurb,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: JTText.bodySm.copyWith(color: JT.muted)),
            ],
            const SizedBox(height: 16),
            PrimaryPill(
              label: 'Navigasi ke sini',
              icon: Icons.navigation_rounded,
              height: 54,
              onTap: () => done(PeekAction.navigate),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SoftButton(
                    label: 'Lihat di peta',
                    icon: Icons.map_rounded,
                    height: 52,
                    onTap: () => done(PeekAction.map),
                  ),
                ),
                if (place.isPoi) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SoftButton(
                      label: 'Detail',
                      icon: Icons.menu_book_rounded,
                      height: 52,
                      color: JT.cream,
                      onTap: () => done(PeekAction.detail),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ]);
  }
}
