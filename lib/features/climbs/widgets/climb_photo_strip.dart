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
/// Each card fills the width it is given, so a single photo reads as a hero and
/// a second one announces itself by being half on screen as you swipe.
class ClimbPhotoStrip extends StatelessWidget {
  const ClimbPhotoStrip({required this.filenames, super.key});

  /// Bare filenames, in the order they were picked. Never empty: the caller
  /// leaves the whole block out for a climb with no photos, because an empty
  /// frame reads as a photo that failed rather than as a climb with none.
  final List<String> filenames;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = constraints.maxWidth;

        return SizedBox(
          height: cardWidth / CairnSize.peakPhotoAspect,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filenames.length,
            // No scrolling at all when there is one photo, so a single card
            // does not wobble under a thumb.
            physics: filenames.length == 1
                ? const NeverScrollableScrollPhysics()
                : null,
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
