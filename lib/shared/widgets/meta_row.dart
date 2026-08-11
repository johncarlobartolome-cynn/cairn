import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/theme_context.dart';

/// A dot-separated run of small muted facts, e.g. `2,922 m · Hard · 8 h`.
///
/// Built on [Wrap] rather than [Row]: a peak card at 320dp with four facts on
/// it has to fold onto a second line instead of overflowing, and the data model
/// makes most fields nullable, so the item count is never fixed.
///
/// A separator is glued to the item that follows it, and the pair travels as a
/// single [Wrap] child. A line break therefore carries the separator down with
/// its item instead of stranding it as the last glyph on a line. No caller has
/// to think about it.
class MetaRow extends StatelessWidget {
  const MetaRow(this.items, {this.style, super.key});

  /// Nulls and blanks are dropped, so a caller can pass optional fields
  /// straight through without filtering first.
  final List<String?> items;

  /// Overrides the default meta style. Colour is taken from here too.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final parts = items
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!.trim())
        .toList(growable: false);

    if (parts.isEmpty) return const SizedBox.shrink();

    final effective = style ?? context.cairnText.meta;
    final separator = effective.copyWith(
      color: (effective.color ?? context.cairnColors.inkMuted).withValues(
        alpha: 0.6,
      ),
    );

    final children = <Widget>[
      Text(parts.first, style: effective),
      for (final part in parts.skip(1))
        // One child, so the break happens before the separator, never after it.
        // Wrap hands each child its own maxWidth, which keeps the Flexible
        // legal and lets a long fact still wrap inside the pair.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(CairnGlyph.metaSeparator, style: separator),
            const SizedBox(width: CairnSpace.x8),
            Flexible(child: Text(part, style: effective)),
          ],
        ),
    ];

    return Wrap(
      spacing: CairnSpace.x8,
      runSpacing: CairnSpace.x4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
