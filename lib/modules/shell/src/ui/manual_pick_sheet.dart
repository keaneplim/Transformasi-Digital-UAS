import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../state/guide_controller.dart';
import '../state/places.dart';
import 'widgets.dart';

/// UC-A02-3 / F01 AC4 "Pilih manual": the visitor tells the guide where they are when the GPS
/// can't (inside a cave, location not allowed). Nearest first while a position is known,
/// otherwise A–Z. Resolves to the chosen place (already recorded as a manual visit through
/// [GuideController.manualPick]) or null when dismissed; the caller opens POI Detail.
Future<Place?> showManualPick(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ManualPickSheet(),
    );

class _ManualPickSheet extends ConsumerWidget {
  const _ManualPickSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(guideProvider);
    final list = guide.manualPickList;
    final near = !guide.noPosition;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
        decoration: BoxDecoration(
            color: JT.surface, borderRadius: BorderRadius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: JT.line, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            Text('Anda sedang di mana?', style: JTText.h3),
            const SizedBox(height: 4),
            Text(
              near
                  ? 'Pilih tempat Anda berada. Yang terdekat ada di atas.'
                  : 'Pilih tempat Anda berada untuk membuka ceritanya.',
              style: JTText.caption,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = list[i];
                  return Pressable(
                    onTap: () {
                      guide.manualPick(p);
                      Navigator.of(context).pop(p);
                    },
                    scale: 0.98,
                    semanticLabel: p.name,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: JT.cream,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: 52,
                            child:
                                PlacePhoto(place: p, radius: 12, hero: false),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CategoryLabel(
                                    place: p,
                                    text: near && i == 0 ? 'Terdekat' : null),
                                const SizedBox(height: 2),
                                Text(p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: JTText.label),
                              ],
                            ),
                          ),
                          if (guide.visited.contains(p.id))
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: VisitedTick(),
                            )
                          else
                            const Icon(Icons.chevron_right_rounded,
                                color: JT.muted),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
