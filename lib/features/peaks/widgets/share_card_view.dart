import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/extensions/theme_context.dart';
import '../../../shared/widgets/badge_disc.dart';
import '../../../shared/widgets/cairn_mark.dart';
import '../../../shared/widgets/meta_row.dart';
import '../share_card.dart';

/// The picture Cairn shares: one card, drawn from the app's own kit.
///
/// It is painted on screen before it is sent, in the sheet that offers to send
/// it, and the same pixels are what leave the phone. Nothing renders offscreen
/// and nothing is composed twice, so what the user approves is what the
/// receiver opens.
///
/// **Fixed width, free height.** [width] is what the export is measured
/// against, so the file is the same size whatever handset it was built on. The
/// height is whatever the strings need. A peak somebody names in full wraps and
/// makes the card taller, which is the only correct answer here: this is the
/// most public text the app produces and an ellipsis on it would hide the one
/// word the reader wanted.
///
/// **Give it room, never a width.** A caller that hands this a tight width wins
/// the argument, the way any parent does, and the export quietly changes size
/// with the handset. The sheet puts it in a `FittedBox` with `scaleDown`, which
/// hands it unbounded constraints and scales the drawing instead of the layout,
/// so a narrow phone shrinks the preview and the file stays 1080 across.
///
/// **Square corners on the outside.** Every other card in Cairn is rounded, and
/// this one cannot be: rounding a picture means transparent corners, and a chat
/// app paints its own colour through them. So the app's ground fills the frame
/// edge to edge and the rounded card floats inside it, which is the design's
/// own arrangement rather than a compromise around it.
class ShareCardView extends StatelessWidget {
  const ShareCardView({required this.card, super.key});

  final ShareCard card;

  /// Logical width of the exported picture. At the export's 3x this is a
  /// 1080-pixel-wide image, which is a phone screen's worth and plenty for a
  /// chat thread.
  static const double width = 360;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    final text = context.cairnText;

    return SizedBox(
      width: width,
      child: ColoredBox(
        color: colors.ground,
        child: Padding(
          padding: const EdgeInsets.all(CairnSpace.x20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: CairnRadius.photoCardAll,
              boxShadow: CairnShadow.card(colors.accent),
            ),
            child: Padding(
              padding: const EdgeInsets.all(CairnSpace.x24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Signature(),
                  const SizedBox(height: CairnSpace.x24),
                  // No maxLines and no overflow on any string below. The
                  // defaults wrap and never ellipsize; setting anything here
                  // would only take that away.
                  Text(card.peakName, style: text.displayLine2),
                  const SizedBox(height: CairnSpace.x4),
                  Text(
                    card.climbedLine,
                    style: text.body.copyWith(color: colors.inkMuted),
                  ),
                  if (card.facts.isNotEmpty) ...[
                    const SizedBox(height: CairnSpace.x16),
                    MetaRow(card.facts),
                  ],
                  const SizedBox(height: CairnSpace.x24),
                  Container(height: CairnSize.hairline, color: colors.hairline),
                  const SizedBox(height: CairnSpace.x16),
                  Text(card.tally, style: text.body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's mark: the standard icon badge and the app's name beside it.
///
/// Naming the app on something the user chose to send is fair. Selling it is
/// not, so this is a 44 disc and five muted letters at the top of the card,
/// sized like every other section label in the app, and there is no call to
/// action, no link, and no "sent from".
class _Signature extends StatelessWidget {
  const _Signature();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The app's mark on the app's own signature, which is what a stranger
        // reading a shared card sees first.
        const BadgeDisc(
          kind: BadgeKind.peak,
          unlocked: true,
          glyph: CairnMark(),
        ),
        const SizedBox(width: CairnSpace.x12),
        // The section label's type role, drawn here rather than through
        // SectionLabel itself, which caps its text at one line with an
        // ellipsis. Five letters can never reach that cap, and a card whose
        // job is to be un-truncatable should not carry the widget that
        // truncates. The uppercasing still happens in code so the string is
        // not shouted in a literal.
        Text('Cairn'.toUpperCase(), style: context.cairnText.sectionLabel),
      ],
    );
  }
}
