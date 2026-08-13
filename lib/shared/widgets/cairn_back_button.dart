import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/nav_context.dart';
import '../extensions/theme_context.dart';

/// The way out of a screen pushed over the nav shell.
///
/// Always drawn. Material's own back arrow appears only when the navigator has
/// something to pop, which leaves a deep-linked screen with an empty bar and no
/// exit, so this one is unconditional and hands the decision to
/// [CairnNavContext.popOrHome].
///
/// Carries its own colour and size instead of leaning on the app bar's icon
/// theme, so it reads the same wherever it is placed. It sits in a bar's
/// `leading` slot today; over a photo hero it would work unchanged.
class CairnBackButton extends StatelessWidget {
  const CairnBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: context.popOrHome,
      icon: const Icon(Icons.arrow_back_rounded),
      color: context.cairnColors.ink,
      iconSize: CairnSize.navIcon,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    );
  }
}
