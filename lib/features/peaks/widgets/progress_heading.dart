import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/extensions/theme_context.dart';
import '../../../shared/widgets/section_label.dart';

/// The greeting, plus how far up the library the climber is: a tiny count
/// beside the greeting and one thin bar under both.
///
/// The design's screen inventory calls this the progress strip. It is a heading
/// here because the count rides the greeting's own line instead of taking one
/// of its own, and naming a widget after half of what it draws is how the next
/// reader gets caught out.
///
/// **It is deliberately the quietest thing on the screen.** The design gives
/// the grid the job of showing progress, a set of six where the climbed ones
/// are in colour and the rest are washed out, and calls the counter
/// confirmation rather than the mechanism. So the count is an 11pt label riding
/// alongside the greeting, and the bar is 6dp. Anything with a big number in it
/// would compete with the grid and win, which would be the wrong screen.
///
/// The count sits beside the greeting rather than on a line of its own, and
/// that is a grid decision as much as a layout one. Every row added above the
/// grid comes out of the cards, which is how T13 cost the list its third row,
/// so the strip borrows the empty half of a line that was already being drawn.
/// It reads as one sentence too: "your peaks, two of six climbed".
///
/// [total] is the library, never a constant. Six peaks ship in the seed and the
/// feature set lets a climber add their own, so the strip says "3 of 7" the day
/// a seventh arrives with nothing here to change.
class ProgressHeading extends StatelessWidget {
  const ProgressHeading({
    required this.climbed,
    required this.total,
    super.key,
  });

  /// How many peaks in the library have a climb against them.
  final int climbed;

  /// How many peaks are in the library.
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    final text = context.cairnText;
    // An empty library never draws this, but a division is not the place to
    // rely on that.
    final fraction = total <= 0 ? 0.0 : (climbed / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A [Wrap] rather than a [Row], and that is the no-truncation rule
        // showing up in a layout. Side by side the label is 11pt against two
        // short words and there is room to spare, but a small phone at a large
        // text scale can run out of it, and every way a [Row] can answer that
        // is a bug: an ellipsis in the label, or the greeting breaking "peaks"
        // across two lines. A [Wrap] drops the label onto its own line instead,
        // which costs 20dp on the phones that need it and nothing on the ones
        // that do not.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          // The label rides the bottom of the greeting, so it sits with the
          // heavier second line rather than floating beside the lighter first.
          crossAxisAlignment: WrapCrossAlignment.end,
          runSpacing: CairnSpace.x8,
          children: [
            // Two lines, two weights, per the design's headline rule.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your', style: text.displayLine1),
                Text('peaks', style: text.displayLine2),
              ],
            ),
            // Reads aloud as a sentence: "two of six climbed".
            Padding(
              // Optical, not structural: it lifts the label off the descender
              // line of the greeting rather than sitting on it.
              padding: const EdgeInsets.only(bottom: CairnSpace.x8),
              child: SectionLabel('$climbed of $total climbed'),
            ),
          ],
        ),
        const SizedBox(height: CairnSpace.x12),
        ClipRRect(
          borderRadius: CairnRadius.pillAll,
          child: SizedBox(
            height: CairnSize.progressTrack,
            child: Stack(
              children: [
                // The track. accentSoft is the token the spec names for exactly
                // this, and it is the one place a wash that low-contrast works:
                // it is a background, not a state.
                Positioned.fill(child: ColoredBox(color: colors.accentSoft)),
                // The filled part. Aligned left rather than centred, or a
                // half-full bar would float in the middle of its track.
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fraction,
                    child: ColoredBox(color: colors.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
