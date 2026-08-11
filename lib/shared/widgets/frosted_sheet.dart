import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/theme_context.dart';

/// The translucent sheet that sits over a photo hero on peak detail.
///
/// It blurs whatever is behind it and lays a partly opaque surface fill on top,
/// so body text stays readable over any photograph. Top corners only, since it
/// is anchored to the bottom of the hero.
///
/// It takes whatever size its parent hands it, so anchor it with
/// `Positioned(left: 0, right: 0, bottom: 0)` inside the hero's `Stack` and
/// give the child a `MainAxisSize.min` column. Aligning it instead lets the
/// child stretch to the full hero height.
class FrostedSheet extends StatelessWidget {
  const FrostedSheet({
    required this.child,
    this.padding = const EdgeInsets.all(CairnSpace.x20),
    this.borderRadius = CairnRadius.sheetTop,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Defaults to top-only rounding. Pass an all-round radius to float it.
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: CairnFrost.blur,
          sigmaY: CairnFrost.blur,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: CairnFrost.surfaceOpacity),
            borderRadius: borderRadius,
            border: Border(
              top: BorderSide(
                color: colors.surface.withValues(alpha: 0.5),
                width: CairnSize.hairline,
              ),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
