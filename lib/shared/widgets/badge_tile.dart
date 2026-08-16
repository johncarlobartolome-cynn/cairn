import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/theme_context.dart';

/// How a [BadgeTile] draws its glyph disc.
enum BadgeTileState {
  /// 1px outline, muted glyph. Nothing earned yet.
  locked,

  /// Brand fill, onBrand glyph. A per-mountain badge that has been earned.
  unlocked,

  /// Gold fill. Reserved for the three milestones: first climb, three peaks,
  /// all peaks. T18 respaced the middle tier, and gold is still the one colour
  /// in the app that is not green.
  unlockedMilestone,
}

/// One cell in the badge grid: a circular glyph disc with a label under it.
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
    required this.icon,
    required this.state,
    this.caption,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
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

    final (Color discFill, Color glyph) = switch (state) {
      BadgeTileState.locked => (Colors.transparent, colors.inkMuted),
      BadgeTileState.unlocked => (colors.brand, colors.onBrand),
      // Gold is light in both themes, so the glyph on it takes the dark side of
      // the palette rather than onBrand, which flips with brightness.
      BadgeTileState.unlockedMilestone => (
          colors.gold,
          colors.isDark ? colors.ground : colors.ink,
        ),
    };

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
                Container(
                  width: CairnSize.iconBadge,
                  height: CairnSize.iconBadge,
                  decoration: BoxDecoration(
                    color: discFill,
                    shape: BoxShape.circle,
                    border: _isLocked
                        ? Border.all(
                            color: colors.inkMuted,
                            width: CairnSize.hairline,
                          )
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: CairnSize.iconBadgeGlyph,
                    color: glyph,
                  ),
                ),
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
