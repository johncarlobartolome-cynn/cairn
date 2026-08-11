import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/theme_context.dart';

/// How a [BadgeTile] draws its glyph disc.
enum BadgeTileState {
  /// 1px outline, muted glyph. Nothing earned yet.
  locked,

  /// Brand fill, onBrand glyph. A per-mountain badge that has been earned.
  unlocked,

  /// Gold fill. Reserved for the three milestones: first climb, five peaks,
  /// all six.
  unlockedMilestone,
}

/// One cell in the badge grid: a circular glyph disc with a label under it.
///
/// Sizes to its parent, so the badges screen owns the grid. With a caption it
/// measures 144dp tall: a 44 disc, a label that may take two lines, and the
/// caption. A grid that hands it less overflows, so on a 360dp phone at 3-up
/// keep `childAspectRatio` at or below 0.68.
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

  /// Small line under the label, e.g. the unlock date.
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
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.button.copyWith(
                    color: _isLocked ? colors.inkMuted : colors.ink,
                  ),
                ),
                if (caption != null && caption!.trim().isNotEmpty) ...[
                  const SizedBox(height: CairnSpace.x4),
                  Text(
                    caption!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.meta,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
