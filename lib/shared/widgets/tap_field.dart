import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/theme_context.dart';

/// A form row you tap rather than type into.
///
/// Shaped like the text fields it sits between, so a sheet mixing typed fields
/// with pickers still reads as one form: same fill, same radius, same height.
/// The chevron is the promise that something opens.
///
/// Built for the mark-climbed sheet's date row in T15 and lifted here in T17
/// when the photo row became its second consumer, which is the rule the
/// architecture note sets for `shared/widgets/`.
class TapField extends StatelessWidget {
  const TapField({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;

  /// Wraps rather than shortens. The row is as wide as the sheet, and an
  /// ellipsis would hide the part someone is reading the row for.
  final String label;

  /// Null blocks the press, for a form that is busy saving.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    final text = context.cairnText;

    return Material(
      color: colors.surfaceAlt,
      borderRadius: CairnRadius.fieldAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CairnSize.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CairnSpace.x16,
              vertical: CairnSpace.x12,
            ),
            child: Row(
              children: [
                Icon(icon, size: CairnSize.icon, color: colors.accent),
                const SizedBox(width: CairnSpace.x12),
                Expanded(child: Text(label, style: text.body)),
                Icon(
                  Icons.chevron_right_rounded,
                  size: CairnSize.icon,
                  color: colors.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
