import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../../app/theme/tokens.dart';

/// Short reads for the two Cairn theme extensions.
///
/// Both fall back to the light set if a widget is ever pumped without
/// [CairnTheme] in scope, so a stray widget renders plainly instead of
/// throwing.
extension CairnThemeContext on BuildContext {
  /// The palette for the active brightness.
  CairnPalette get cairnColors =>
      Theme.of(this).extension<CairnColors>()?.palette ?? CairnPalette.light;

  /// The named type roles, colours already bound.
  CairnTextStyles get cairnText =>
      Theme.of(this).extension<CairnTextStyles>() ??
      CairnTextStyles.fromPalette(CairnPalette.light);
}
