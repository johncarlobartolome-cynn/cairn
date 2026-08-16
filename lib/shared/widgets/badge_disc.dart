import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/theme_context.dart';

/// What a badge is for, which is what decides its silhouette.
///
/// This is a separate axis from whether the badge has been earned. Conflating
/// the two is what T22 had to unpick: the old three-value state enum could say
/// "unlocked milestone" but had no way to say "locked milestone", so a milestone
/// still to earn drew the same outlined circle as a peak still to earn and the
/// only thing between them was a glyph.
enum BadgeKind {
  /// One peak, earned by climbing it. A plain circle, per the design spec.
  peak,

  /// First climb, three peaks, all peaks. A scalloped seal.
  milestone,
}

/// The circular or scalloped disc a badge glyph sits in.
///
/// It resolves its own fill and glyph colour from the palette, so the two places
/// that draw one, a [BadgeTile] on the badges screen and the climbed mark on a
/// peak card, cannot drift apart on what an earned badge looks like.
///
/// The glyph is a widget rather than an [IconData] because one of them is not an
/// icon: a peak badge carries [CairnMark], which is painted. The disc publishes
/// size and colour through an [IconTheme], the way a button does, so a caller
/// passes a bare `Icon(...)` or a bare `CairnMark()` and neither has to be told
/// how big it is or what colour to be.
class BadgeDisc extends StatelessWidget {
  const BadgeDisc({
    required this.kind,
    required this.unlocked,
    required this.glyph,
    this.size = CairnSize.iconBadge,
    this.glyphSize = CairnSize.iconBadgeGlyph,
    this.overImagery = false,
    super.key,
  });

  final BadgeKind kind;

  /// Earned. A locked disc is an outline with a muted glyph; an earned one is
  /// filled.
  final bool unlocked;

  final Widget glyph;

  final double size;
  final double glyphSize;

  /// This disc sits on a photograph rather than on a card, so it takes a ring
  /// in the counter colour and stops depending on what is behind it. See
  /// [CairnSize.markRing]. Only the climbed mark on a peak card sets this.
  final bool overImagery;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;

    final (Color fill, Color ink) = switch ((kind, unlocked)) {
      (_, false) => (Colors.transparent, colors.inkMuted),
      (BadgeKind.peak, true) => (colors.brand, colors.onBrand),
      // Gold is the lighter colour in both themes, so the glyph on it takes the
      // dark side of the palette rather than onBrand, which flips with
      // brightness and would go light on light.
      (BadgeKind.milestone, true) => (
        colors.gold,
        colors.isDark ? colors.ground : colors.ink,
      ),
    };

    final side = switch ((unlocked, overImagery)) {
      (false, _) => BorderSide(
        color: colors.inkMuted,
        width: CairnSize.hairline,
      ),
      (true, true) => BorderSide(color: ink, width: CairnSize.markRing),
      (true, false) => BorderSide.none,
    };

    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: fill,
          shape: switch (kind) {
            BadgeKind.peak => CircleBorder(side: side),
            BadgeKind.milestone => BadgeSealBorder(side: side),
          },
        ),
        child: Center(
          child: IconTheme.merge(
            data: IconThemeData(size: glyphSize, color: ink),
            child: glyph,
          ),
        ),
      ),
    );
  }
}

/// A circle with [CairnBadge.sealLobes] soft bumps around it, like a wax seal.
///
/// The shape a milestone badge takes, and the reason a milestone can be picked
/// out of the grid with the colour thrown away. It lives here rather than in a
/// shapes folder of its own because nothing else in the app is ever going to
/// want it: it exists to be the thing a plain circle is not.
///
/// Each lobe is one quadratic curve between two valleys. The control point is
/// pushed past the outer radius so the curve's midpoint lands on it rather than
/// short of it, which is what keeps the bumps as deep as [CairnBadge.sealDepth]
/// says they are instead of about half that.
@immutable
class BadgeSealBorder extends OutlinedBorder {
  const BadgeSealBorder({super.side});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  BadgeSealBorder copyWith({BorderSide? side}) =>
      BadgeSealBorder(side: side ?? this.side);

  @override
  BadgeSealBorder scale(double t) => BadgeSealBorder(side: side.scale(t));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect, rect.shortestSide / 2);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect, math.max(rect.shortestSide / 2 - side.strokeInset, 0));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      _path(rect, rect.shortestSide / 2 - side.strokeOffset / 2),
      side.toPaint(),
    );
  }

  static Path _path(Rect rect, double outer) {
    final path = Path();
    if (outer <= 0) return path;

    final center = rect.center;
    final inner = outer * (1 - CairnBadge.sealDepth);
    // Half a lobe, in radians.
    final half = math.pi / CairnBadge.sealLobes;
    // A quadratic sits at (start + 2*control + end) / 4 halfway along. Solving
    // that for a midpoint on `outer`, with both ends on `inner` at `half` either
    // side of the lobe, gives the radius the control point has to sit at.
    final control = 2 * outer - inner * math.cos(half);

    Offset at(double angle, double radius) => Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );

    // Starts in a valley, so the first lobe is whole rather than split.
    var angle = -math.pi / 2 - half;
    path.moveTo(at(angle, inner).dx, at(angle, inner).dy);

    for (var lobe = 0; lobe < CairnBadge.sealLobes; lobe++) {
      final peak = at(angle + half, control);
      final valley = at(angle + 2 * half, inner);
      path.quadraticBezierTo(peak.dx, peak.dy, valley.dx, valley.dy);
      angle += 2 * half;
    }

    path.close();
    return path;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BadgeSealBorder &&
          other.runtimeType == runtimeType &&
          other.side == side);

  @override
  int get hashCode => Object.hash(runtimeType, side);
}
