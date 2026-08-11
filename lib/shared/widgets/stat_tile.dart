import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/theme_context.dart';

/// One fact on a nested tile: a value with a tiny uppercase caption under it.
///
/// Used in the 2x2 grid on peak detail and in the stat row on badges. It sizes
/// to its parent, so the caller owns the grid.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.value,
    required this.caption,
    this.icon,
    this.emphasised = false,
    super.key,
  });

  /// The number or short phrase, e.g. `2,922 m`. An empty value is the caller's
  /// signal that the field is unknown, and renders as an em-space dash.
  final String value;

  /// Uppercased here, so callers pass normal case.
  final String caption;

  /// Optional leading glyph, sits beside the value.
  final IconData? icon;

  /// Fills with accentSoft instead of surfaceAlt. Reserved for the one tile on
  /// a screen that carries the headline number, e.g. peaks climbed.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    final text = context.cairnText;
    final shown = value.trim().isEmpty ? '–' : value;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasised ? colors.accentSoft : colors.surfaceAlt,
        borderRadius: CairnRadius.dataCardAll,
        border: Border.all(
          color: colors.hairline,
          width: CairnSize.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CairnSpace.x16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: CairnSize.icon, color: colors.accent),
                  const SizedBox(width: CairnSpace.x8),
                ],
                Expanded(
                  child: Text(
                    shown,
                    style: text.statValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CairnSpace.x4),
            Text(
              caption.toUpperCase(),
              style: text.statCaption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}
