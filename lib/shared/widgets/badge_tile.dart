import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/theme_context.dart';
import 'badge_disc.dart';

/// Whether a [BadgeTile] has been earned.
///
/// **Two values, and it used to have three.** `unlockedMilestone` sat here until
/// T22, which made the enum carry two unrelated facts and left one of the four
/// real cases unsayable: a milestone still to earn had no state of its own, so
/// it drew as a plain locked circle and a reader had no way to tell it from a
/// peak still to earn. Kind moved out to [BadgeKind] and this went back to
/// saying the one thing its name says.
enum BadgeTileState {
  /// 1px outline, muted glyph. Nothing earned yet.
  locked,

  /// Filled. Brand for a peak, gold for a milestone, per [BadgeDisc].
  unlocked,
}

/// One cell in the badge grid: a glyph disc with a label under it.
///
/// The disc is a circle for a peak badge and a scalloped seal for a milestone,
/// which is [BadgeDisc]'s job and the reason the two kinds survive being read in
/// greyscale.
///
/// Sizes to its parent in width and to its own content in height, so the badges
/// screen owns the grid. Give it a row that measures itself, an `IntrinsicHeight`
/// over a `Row` of `Expanded`s, rather than a `GridView` with a
/// `childAspectRatio`. An aspect ratio is a guess about how long the strings
/// are, and this tile carries two that a caller cannot bound: a peak name the
/// user typed, and the sentence saying how to earn the badge.
///
/// Neither string is ever truncated. Both were capped with an ellipsis when T9
/// built this, which no caller noticed because the gallery only ever passed it
/// short ones. T19 gave it real content and the cap had to go: an unlock
/// condition that stops mid-sentence is exactly the tile nobody can act on.
class BadgeTile extends StatelessWidget {
  const BadgeTile({
    required this.label,
    required this.glyph,
    required this.kind,
    required this.state,
    this.caption,
    this.onTap,
    super.key,
  });

  final String label;

  /// Sized and coloured by the disc, so callers pass a bare `Icon(...)` or a
  /// bare `CairnMark()`.
  final Widget glyph;

  /// What the badge is for, which decides the disc's silhouette.
  final BadgeKind kind;

  final BadgeTileState state;

  /// Small line under the label: the day it was earned, or, while it is locked,
  /// the one sentence saying how to earn it. Wraps to as many lines as it needs.
  final String? caption;

  final VoidCallback? onTap;

  bool get _isLocked => state == BadgeTileState.locked;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    final text = context.cairnText;

    return Semantics(
      button: onTap != null,
      enabled: !_isLocked,
      label: label,
      child: Material(
        color: colors.surface,
        borderRadius: CairnRadius.dataCardAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: CairnRadius.dataCardAll,
              border: Border.all(
                color: colors.hairline,
                width: CairnSize.hairline,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: CairnSpace.x12,
              vertical: CairnSpace.x12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BadgeDisc(kind: kind, unlocked: !_isLocked, glyph: glyph),
                const SizedBox(height: CairnSpace.x8),
                // No maxLines and no overflow on either of these. The defaults
                // wrap and never ellipsize, and setting anything here would
                // only take that away.
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: text.button.copyWith(
                    color: _isLocked ? colors.inkMuted : colors.ink,
                  ),
                ),
                if (caption != null && caption!.trim().isNotEmpty) ...[
                  const SizedBox(height: CairnSpace.x4),
                  Text(caption!, textAlign: TextAlign.center, style: text.meta),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
