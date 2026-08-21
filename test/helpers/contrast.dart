// The contrast maths and the bars it is measured against.
//
// This lived in `test/a11y/contrast_test.dart` until T40, which added a second
// suite that has to measure the same way against the same numbers. A bar that
// is written down twice is a bar that will disagree with itself.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// What a pair has to reach, and why that is the number.
enum ContrastRule {
  /// 1.4.3. Anything under 18pt, or under 14pt bold, which is every text role
  /// in the app except the 32pt greeting.
  bodyText(4.5),

  /// 1.4.3. 18pt and up. Only the greeting qualifies.
  largeText(3),

  /// 1.4.11. A shape or a glyph a reader has to make out to understand the
  /// screen: a badge silhouette, an icon, the filled part of a progress bar.
  meaningfulGraphic(3),

  /// No bar, and the pair has to say why. Decoration, or information that is
  /// also written out in words within a glance of it.
  decorative(null);

  const ContrastRule(this.minimum);

  final double? minimum;
}

/// The WCAG 2.1 contrast ratio between two opaque colours.
///
/// Composite anything translucent with [Color.alphaBlend] before it gets here.
/// A ratio against a colour that is partly see-through is a ratio against a
/// background that was never named.
double contrastRatio(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}
