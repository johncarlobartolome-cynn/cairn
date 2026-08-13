import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/theme_context.dart';

/// A card that says why there is nothing to show.
///
/// One shape covers every gap in the app: a screen with no rows yet, and a link
/// pointing at an id that is not there. Both are ordinary states rather than
/// errors, so both get a proper card on the ground instead of a bare sentence.
///
/// It fills the width it is given, so drop it into a page's column or centre it
/// on a page and it looks the same either way.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  /// Drawn in the brand-filled disc at the top.
  final IconData icon;

  final String title;

  /// One or two sentences. Says what would put something here.
  final String message;

  /// Optional single control under the message, e.g. a way back.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    final text = context.cairnText;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: CairnRadius.dataCardAll,
        border: Border.all(color: colors.hairline, width: CairnSize.hairline),
        boxShadow: CairnShadow.card(colors.accent),
      ),
      padding: const EdgeInsets.all(CairnSpace.x24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: CairnSize.iconBadge,
            height: CairnSize.iconBadge,
            decoration: BoxDecoration(
              color: colors.brand,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: CairnSize.iconBadgeGlyph,
              color: colors.onBrand,
            ),
          ),
          const SizedBox(height: CairnSpace.x16),
          Text(title, style: text.screenTitle, textAlign: TextAlign.center),
          const SizedBox(height: CairnSpace.x8),
          Text(
            message,
            style: text.body.copyWith(color: colors.inkMuted),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: CairnSpace.x20),
            action!,
          ],
        ],
      ),
    );
  }
}
