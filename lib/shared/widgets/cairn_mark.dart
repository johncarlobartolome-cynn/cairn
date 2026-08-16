import 'package:flutter/material.dart';

/// The app's own mark: three stones stacked the way a walker leaves them.
///
/// **Drawn rather than shipped.** It is a vector in code, not a font and not an
/// image asset, which suits an offline app that already refuses a runtime font
/// fetch: nothing to bundle, nothing to load, and it stays crisp at any size.
///
/// It stands in for `Icons.terrain_rounded`, which had carried a TODO since T9.
/// A mountain was the wrong mark twice over. It does not say the app's name, and
/// at 44dp it was near enough to the mountain-range glyph on the "Three peaks"
/// milestone that the two badges were told apart by colour alone. A stack of
/// stones is a different silhouette: two horizontal gaps split it into bands, so
/// it survives being reduced to greyscale, which a pair of greens does not.
///
/// **It behaves like an [Icon].** Give it nothing and it takes its size and
/// colour from the enclosing [IconTheme], which is what lets it sit inside a
/// button or a badge disc beside real Material icons and match them. Both can be
/// overridden for a caller that has neither.
class CairnMark extends StatelessWidget {
  const CairnMark({this.size, this.color, super.key});

  /// Side of the square the mark is drawn in. Defaults to the enclosing
  /// [IconTheme]'s size, then to Material's own 24.
  final double? size;

  /// Defaults to the enclosing [IconTheme]'s colour, then to the theme's
  /// `onSurface`, the same fallback an unstyled [Icon] would land on.
  final Color? color;

  /// Material's icon size when no [IconTheme] says otherwise.
  static const double _fallbackSize = 24;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final side = size ?? iconTheme.size ?? _fallbackSize;
    final paint =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    final opacity = iconTheme.opacity ?? 1.0;

    return SizedBox.square(
      dimension: side,
      child: CustomPaint(
        painter: _CairnMarkPainter(
          opacity == 1.0 ? paint : paint.withValues(alpha: paint.a * opacity),
        ),
      ),
    );
  }
}

/// Paints the three stones.
///
/// The stones are laid out on a 24 by 24 grid, the grid Material draws its own
/// icons on, so the mark carries the same optical weight as the icons it sits
/// beside and scales to any size by one factor.
///
/// They are not a neat pyramid. The middle stone sits a little right of centre
/// and the top one a little left, which is both what a hand-stacked cairn looks
/// like and what stops the outline collapsing back into the triangle the
/// mountain glyph already was.
class _CairnMarkPainter extends CustomPainter {
  const _CairnMarkPainter(this.color);

  final Color color;

  /// The design grid the stones are measured on.
  static const double _grid = 24;

  /// Bottom, middle, top. Each gap between them is 1.6 grid units, which holds
  /// at 16dp, the smallest the app draws this: the gaps stay near a full pixel
  /// even before the device's own pixel ratio multiplies them.
  static const List<Rect> _stones = <Rect>[
    Rect.fromLTRB(2.8, 15.6, 21.2, 21.0),
    Rect.fromLTRB(6.0, 9.0, 19.0, 14.0),
    Rect.fromLTRB(8.0, 3.0, 15.2, 7.4),
  ];

  /// Corner radius per stone, so each one reads as rounded rather than as a bar.
  static const List<double> _radii = <double>[2.2, 2.1, 2.0];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _grid;
    final brush = Paint()
      ..color = color
      ..isAntiAlias = true;

    canvas.save();
    canvas.translate(
      (size.width - _grid * scale) / 2,
      (size.height - _grid * scale) / 2,
    );
    canvas.scale(scale);

    for (var i = 0; i < _stones.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(_stones[i], Radius.circular(_radii[i])),
        brush,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CairnMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
