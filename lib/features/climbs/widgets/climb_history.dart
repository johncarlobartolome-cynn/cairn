import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../data/providers.dart';
import '../../../shared/extensions/theme_context.dart';
import '../../../shared/widgets/meta_row.dart';
import '../../../shared/widgets/section_label.dart';
import '../climb_facts.dart';

/// Said on a row that has a note against it.
///
/// A marker, not a preview, and that is a decision rather than a shortcut. The
/// design bans truncation outright, because an ellipsis hides exactly the part
/// the reader wanted. Notes are prose and can run to any length, so the three
/// ways out are shorten the data, wrap it, or move it out of the container.
/// Shortening prose is the ellipsis under another name. Wrapping it in full
/// turns an index of climbs into the climbs themselves, where one long entry
/// buries every row under it. So the prose moves out: it sits on climb detail,
/// one tap away, whole.
const String _noteMark = 'Note written';

/// Every climb logged against one peak, newest first, one tappable row each.
///
/// This is the other half of what a climb changes. The card in the list turns
/// from desaturated to full colour, and here the peak starts carrying the days
/// you were on it.
///
/// A row shows the day, who came along, and whether anything was written down.
/// That is enough to tell two climbs of the same peak apart, and the row opens
/// `/climb/:id` for the rest of it.
///
/// Only built when the peak has at least one climb. The caller owns that check,
/// because the spacing above the section goes with it: a label over nothing
/// reads as a bug rather than as a blank.
class ClimbHistory extends StatelessWidget {
  const ClimbHistory({required this.climbs, super.key});

  /// Newest first, which is the order the query already reads them in. Nothing
  /// re-sorts here, so the screen and the log cannot disagree.
  final List<Climb> climbs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Climbs'),
        const SizedBox(height: CairnSpace.x12),
        for (var index = 0; index < climbs.length; index++) ...[
          if (index > 0) const SizedBox(height: CairnSpace.cardGap),
          _ClimbEntry(climb: climbs[index]),
        ],
      ],
    );
  }
}

/// One climb as a row: the day, then who and whether a note is waiting.
class _ClimbEntry extends StatelessWidget {
  const _ClimbEntry({required this.climb});

  final Climb climb;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    final text = context.cairnText;

    final companions = climb.companions?.trim();
    final notes = climb.notes?.trim();
    final meta = <String?>[
      companions,
      notes == null || notes.isEmpty ? null : _noteMark,
    ];
    final hasMeta = meta.any((e) => e != null && e.isNotEmpty);

    return Material(
      color: colors.surfaceAlt,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: CairnRadius.dataCardAll,
        side: BorderSide(color: colors.hairline, width: CairnSize.hairline),
      ),
      child: InkWell(
        onTap: () => context.push(CairnRoute.climb(climb.id)),
        child: Padding(
          padding: const EdgeInsets.all(CairnSpace.x16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.hiking_rounded,
                size: CairnSize.icon,
                color: colors.accent,
              ),
              const SizedBox(width: CairnSpace.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The day in full, and never shortened: the row is as wide
                    // as the screen and the longest month in the year fits it.
                    Text(climb.dayLabel, style: text.body),
                    if (hasMeta) ...[
                      const SizedBox(height: CairnSpace.x4),
                      // Companions is free text, so it wraps here rather than
                      // being cut. A row growing a line costs nothing; a name
                      // ending in an ellipsis is the bug the design names.
                      MetaRow(meta),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: CairnSpace.x12),
              Icon(
                Icons.chevron_right_rounded,
                size: CairnSize.icon,
                color: colors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
