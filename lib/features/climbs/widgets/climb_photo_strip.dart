import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import 'climb_photo.dart';

/// The photos of one climb, one card wide, scrolled sideways.
///
/// Sideways rather than stacked down the page, and that is the decision worth
/// writing down. A climb can carry any number of photos, and a vertical stack
/// would push the day, the companions and the notes below them off the screen,
/// so how far you have to scroll to read your own note would depend on how many
/// pictures you took. Across, the block is the same height whether there is one
/// photo or nine, and nothing below it moves.
///
/// A single photo fills the width and reads as a hero. **Two or more give up
/// [_peek] of it, so the edge of the next one is on screen.**
///
/// That was this widget's stated intent from the day it was written and the code
/// did not do it: every card was exactly as wide as the strip, so a climb
/// carrying nine photographs looked the same as a climb carrying one. Nothing
/// said there was more to see, and a strip that scrolls with no sign that it
/// scrolls is a strip nobody swipes. Found in T26 by photographing a nine-photo
/// climb, which is a state nobody had put on a screen before.
///
/// A slice of the next photograph rather than a counter or a row of dots. It is
/// the quieter signal and the clearer one: the edge of a different picture is
/// unambiguous at a glance, and this app does not decorate.
class ClimbPhotoStrip extends StatelessWidget {
  const ClimbPhotoStrip({required this.filenames, super.key});

  /// Bare filenames, in the order they were picked. Never empty: the caller
  /// leaves the whole block out for a climb with no photos, because an empty
  /// frame reads as a photo that failed rather than as a climb with none.
  final List<String> filenames;

  /// How much of the strip the front card gives up when it has company.
  ///
  /// 32 leaves about 20dp of the next photograph showing once the 12dp gap
  /// between them is taken out of it, which reads as another picture rather than
  /// as a stripe.
  static const double _peek = CairnSpace.x32;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool alone = filenames.length == 1;
        final double cardWidth = alone
            ? constraints.maxWidth
            : constraints.maxWidth - _peek;

        return SizedBox(
          // Its own token, not the peak card's. They were the same 4:3 until
          // the peaks grid needed a shallower card to fit six on a screen, and
          // this strip has no such fight: a photo of a climb is as tall as it
          // deserves to be.
          //
          // Off the card rather than off the strip, so a photo keeps its shape
          // when it gives room to the one behind it.
          height: cardWidth / CairnSize.climbPhotoAspect,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filenames.length,
            // No scrolling at all when there is one photo, so a single card
            // does not wobble under a thumb.
            physics: alone ? const NeverScrollableScrollPhysics() : null,
            separatorBuilder: (_, _) =>
                const SizedBox(width: CairnSpace.cardGap),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: ClimbPhoto(filename: filenames[index]),
            ),
          ),
        );
      },
    );
  }
}
