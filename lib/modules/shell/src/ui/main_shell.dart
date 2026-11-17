import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import 'home_tab.dart';
import 'map_tab.dart';
import 'search_tab.dart';
import 'tab_stage.dart';

/// Which tab is showing (other screens can switch it, e.g. "Lihat di peta").
final tabProvider = StateProvider<int>((ref) => TabStage.home);

/// Place to focus when the map tab opens (set by Home/Search before switching).
final mapFocusProvider = StateProvider<String?>((ref) => null);

/// Bumped to ask the search tab to open ready to type (field focused, band folded).
final searchFocusProvider = StateProvider<int>((ref) => 0);

void openOnMap(WidgetRef ref, String placeId) {
  ref.read(mapFocusProvider.notifier).state = placeId;
  ref.read(tabProvider.notifier).state = TabStage.map;
}

/// Opens the search tab; with [typing] the field takes focus once the page has arrived.
void openSearch(WidgetRef ref, {bool typing = false}) {
  ref.read(tabProvider.notifier).state = TabStage.search;
  if (typing) ref.read(searchFocusProvider.notifier).state++;
}

/// Home · Peta · Cari, with an Ahead-style floating pill and a round QR button.
///
/// The three pages stay alive side by side; [TabStage] choreographs the move between them
/// (content out, canopy moves, content in) and the map lies under the other two so the
/// canopy can lift off it.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with TickerProviderStateMixin {
  late final TabStage _stage =
      TabStage(vsync: this, initial: ref.read(tabProvider));
  late final AmbientClock _clock = AmbientClock(this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clock.running = !JTMotion.reduced(context);
  }

  @override
  void dispose() {
    _stage.dispose();
    _clock.dispose();
    super.dispose();
  }

  Widget _page(int tab, bool visible, Widget child) => Offstage(
        offstage: !visible,
        child: TickerMode(
          enabled: visible,
          child: StageScope(presence: _stage.presence[tab], child: child),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(tabProvider);
    ref.listen(tabProvider, (_, next) {
      // the keyboard belongs to the page being left
      FocusManager.instance.primaryFocus?.unfocus();
      _stage.go(next, reduced: JTMotion.reduced(context));
    });
    return Scaffold(
      backgroundColor: JT.cream,
      extendBody: true,
      body: TabStageScope(
        stage: _stage,
        child: AmbientScope(
          clock: _clock,
          child: Stack(
            children: [
              Positioned.fill(
                child: ValueListenableBuilder<int>(
                  valueListenable: _stage.layout,
                  builder: (context, _, __) => AbsorbPointer(
                    absorbing: _stage.blocking,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _page(TabStage.map, _stage.mapVisible, const MapTab()),
                        CanopyStage(stage: _stage),
                        _page(TabStage.home, _stage.shown == TabStage.home,
                            const HomeTab()),
                        _page(TabStage.search, _stage.shown == TabStage.search,
                            const SearchTab()),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12 + MediaQuery.paddingOf(context).bottom,
                child: Row(
                  children: [
                    Expanded(
                      child: _NavPill(
                        index: tab,
                        onTap: (i) => ref.read(tabProvider.notifier).state = i,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ScanButton(onTap: () => context.push('/scan')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Beranda'),
    (Icons.map_rounded, Icons.map_outlined, 'Peta'),
    (Icons.search_rounded, Icons.search_rounded, 'Cari'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        height: 68,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: JT.surface.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: JT.line),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / _items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: JTMotion.slow,
                  curve: JTMotion.pop,
                  left: w * index,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: Container(
                    decoration: BoxDecoration(
                      color: JT.mint,
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final (i, (on, off, label)) in _items.indexed)
                      Expanded(
                        child: Semantics(
                          selected: i == index,
                          child: Pressable(
                            onTap: () => onTap(i),
                            scale: 0.9,
                            semanticLabel: label,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedSwitcher(
                                  duration: JTMotion.base,
                                  transitionBuilder: (c, a) =>
                                      ScaleTransition(scale: a, child: c),
                                  child: Icon(i == index ? on : off,
                                      key: ValueKey(i == index),
                                      size: 24,
                                      color: i == index ? JT.forest : JT.muted),
                                ),
                                const SizedBox(height: 2),
                                AnimatedDefaultTextStyle(
                                  duration: JTMotion.base,
                                  style: JTText.caption.copyWith(
                                    color: i == index ? JT.forest : JT.muted,
                                    fontWeight: i == index
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                  child: Text(label),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      );
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Pindai QR',
        child: Pressable(
          onTap: onTap,
          scale: 0.9,
          semanticLabel: 'Pindai QR',
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: JT.forest,
              shape: BoxShape.circle,
              border: Border.all(color: JT.forestBright, width: 3),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
                color: Colors.white, size: 28),
          ),
        ),
      );
}
