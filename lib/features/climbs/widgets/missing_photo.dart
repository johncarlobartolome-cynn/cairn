import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/extensions/theme_context.dart';

/// What a photo that is no longer on disk looks like.
///
/// A file can go missing for ordinary reasons: storage cleared, a backup that
/// brought the database back without the media, a sync that half finished. The
/// screen keeps working and one frame says so.
///
/// It says it in words when there is room for the sentence and shows the glyph
/// alone when there is not, which is what a thumbnail gets. Nothing is
/// shortened to fit. It is either said in full or not said.
class MissingPhoto extends StatelessWidget {
  const MissingPhoto({super.key});

  /// The line shown at full size. Kept here so a test can assert on the words
  /// rather than on a copy of them.
  static const String message = 'That photo is no longer on this phone.';

  /// Narrower than this and the sentence is dropped rather than wrapped into a
  /// column of single words.
  static const double _roomForWords = 220;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    final text = context.cairnText;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= _roomForWords;

        return ColoredBox(
          color: colors.surfaceAlt,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(CairnSpace.x16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image_not_supported_rounded,
                    size: CairnSize.iconBadgeGlyph,
                    color: colors.inkMuted,
                  ),
                  if (wide) ...[
                    const SizedBox(height: CairnSpace.x8),
                    Text(
                      message,
                      style: text.meta,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
