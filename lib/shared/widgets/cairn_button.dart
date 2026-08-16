import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/theme_context.dart';

/// The app's primary action: a brand-filled stadium button carrying a 15 Medium
/// label.
///
/// Colour and shape come from the tokens rather than from Material's defaults,
/// the same way every other widget in the kit is built, so it renders as Cairn
/// even where the theme is not in scope.
///
/// It fills the width it is given, because every place the app asks for an
/// action is a full-width slot at the foot of a screen or a sheet. Pass
/// `expand: false` for one that shrinks to its label.
class CairnButton extends StatelessWidget {
  const CairnButton({
    required this.label,
    required this.onPressed,
    this.glyph,
    this.busy = false,
    this.expand = true,
    super.key,
  });

  /// Wraps rather than shortens. A label too long for one line is a naming
  /// problem, and hiding half of it behind an ellipsis would not fix it.
  final String label;

  /// Null greys the button out and blocks the press.
  final VoidCallback? onPressed;

  /// Optional leading glyph. A spinner takes this slot while [busy].
  ///
  /// A widget rather than an [IconData], because the app's own mark is painted
  /// rather than looked up in a font. Size and colour arrive through an
  /// [IconTheme], so a caller passes a bare `Icon(...)` or a bare `CairnMark()`.
  final Widget? glyph;

  /// Work is in flight. The button keeps its fill so it still reads as the
  /// primary action, shows a spinner, and ignores taps, so a second press
  /// cannot start a second save.
  final bool busy;

  final bool expand;

  /// How far a disabled fill fades. Material's own disabled state is 0.38 of
  /// the enabled colour, kept here so the button stays inside the palette
  /// instead of falling back to Material's grey.
  static const double _disabledOpacity = 0.38;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;

    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.brand,
        foregroundColor: colors.onBrand,
        disabledBackgroundColor: colors.brand.withValues(
          alpha: _disabledOpacity,
        ),
        disabledForegroundColor: colors.onBrand.withValues(
          alpha: _disabledOpacity,
        ),
        textStyle: CairnType.button,
        elevation: 0,
        minimumSize: const Size(0, CairnSize.control),
        padding: const EdgeInsets.symmetric(horizontal: CairnSpace.x24),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            SizedBox(
              width: CairnSize.icon,
              height: CairnSize.icon,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.onBrand,
              ),
            ),
            const SizedBox(width: CairnSpace.x8),
          ] else if (glyph != null) ...[
            IconTheme.merge(
              data: const IconThemeData(size: CairnSize.icon),
              child: glyph!,
            ),
            const SizedBox(width: CairnSpace.x8),
          ],
          Flexible(child: Text(label)),
        ],
      ),
    );

    return IgnorePointer(
      ignoring: busy,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
