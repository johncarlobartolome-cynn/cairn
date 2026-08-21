import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/shared/widgets/badge_disc.dart';
import 'package:cairn/shared/widgets/cairn_mark.dart';
import 'package:cairn/shared/widgets/peak_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contrast.dart';
import '../helpers/pump_widget.dart';

/// The ring around the climbed mark, held by a test that renders it.
///
/// **The contrast suite next door cannot catch this one, and T40 is the ticket
/// that found out.** Its two climbed-mark rows are built out of colour tokens,
/// so `onBrand` against `brand` measures 11 to 1 whether or not a ring is drawn
/// anywhere in the app. Delete the `BorderSide` in [BadgeDisc] and all 594 tests
/// stayed green while Cairn's most important graphic went back to 2.38 to 1 on
/// the card it matters on. That was verified, not assumed.
///
/// So this file measures a pair that occurs. Every colour it feeds to
/// [contrastRatio] is read off a rendered climbed [PeakCard] rather than named
/// from the palette, and the tokens only come in as the answer the render is
/// checked against. A ring that is gone, recoloured, or thinned fails here.
///
/// The disc's `switch` has an arm for every combination of earned and over
/// imagery, and the second group covers the ones that must stay bare. A test
/// that only knew what a ring looks like would pass just as well if every disc
/// in the app grew one, which would put a ring around all nine badges on the
/// badges screen and be a different design.
void main() {
  /// The stroke on the disc's silhouette, which is the ring.
  BorderSide ringOf(WidgetTester tester) {
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(BadgeDisc),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as ShapeDecoration;
    return (decoration.shape as OutlinedBorder).side;
  }

  /// The ring's colour, which is only a colour when there is a ring.
  ///
  /// [BorderSide.none] still carries an opaque black, and measuring that would
  /// have this file reporting a healthy ratio for a mark with no ring at all.
  /// It is not hypothetical: with the ring deleted, black cleared the bar
  /// against both the dark disc and the dark placeholder, and the dark half of
  /// the test below passed until this guard went in.
  Color ringColourOf(WidgetTester tester) {
    final ring = ringOf(tester);
    expect(
      ring.style,
      BorderStyle.solid,
      reason:
          'There is no ring to measure. BorderSide.none reports black, so the '
          'ratios below would be measuring a colour the card never paints.',
    );
    return ring.color;
  }

  /// The disc's fill, which is what the ring's inner edge sits against.
  Color fillOf(WidgetTester tester) =>
      (tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(BadgeDisc),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as ShapeDecoration)
          .color!;

  /// The colour the glyph is actually painting with, taken from the context the
  /// glyph resolves it in rather than from the palette. The ring is specified as
  /// the glyph's own colour, so this is the value it has to match.
  Color glyphColourOf(WidgetTester tester) =>
      IconTheme.of(tester.element(find.byType(CairnMark))).color!;

  /// Every flat fill the card paints, in paint order.
  List<Color> flatFillsOf(WidgetTester tester) => tester
      .widgetList<ColoredBox>(
        find.descendant(
          of: find.byType(PeakCard),
          matching: find.byType(ColoredBox),
        ),
      )
      .map((box) => box.color)
      .toList();

  group('the climbed mark on a peak card', () {
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.dark ? 'dark' : 'light';
      final palette = paletteFor(brightness);

      testWidgets('$theme: takes a ring in the glyph colour', (tester) async {
        await pumpCairn(
          tester,
          const PeakCard(name: 'Mt. Pulag', climbed: true),
          width: 360,
          brightness: brightness,
        );

        final ring = ringOf(tester);

        expect(
          ring.style,
          BorderStyle.solid,
          reason:
              'The climbed mark draws no ring. It is a brand disc on a '
              'photograph, which is the one place in the app with no measurable '
              'background, and the ring is what stops it depending on the '
              'picture. See CairnSize.markRing.',
        );
        expect(
          ring.width,
          CairnSize.markRing,
          reason:
              'The climbed mark ring is not CairnSize.markRing thick. The token '
              'is 2dp rather than a hairline on purpose: at 28dp a hairline is '
              'a hint.',
        );
        expect(
          ring.color,
          glyphColourOf(tester),
          reason:
              'The ring and the glyph have come apart. The ring works because '
              'it is the disc\'s counter colour, so the mark\'s edge is two '
              'colours far apart and a photograph would have to fail against '
              'both to hide it.',
        );
        expect(
          ring.color,
          palette.onBrand,
          reason:
              'The ring is no longer onBrand, which is the token the contrast '
              'suite measures it as in both of its climbed-mark rows.',
        );
      });

      testWidgets('$theme: the ring clears 3 to 1 as rendered', (tester) async {
        await pumpCairn(
          tester,
          const PeakCard(name: 'Mt. Pulag', climbed: true),
          width: 360,
          brightness: brightness,
        );

        final bar = ContrastRule.meaningfulGraphic.minimum!;
        final ring = ringColourOf(tester);
        final fill = fillOf(tester);
        final fills = flatFillsOf(tester);

        // Inner edge: the ring against the disc it encloses.
        expect(
          contrastRatio(ring, fill),
          greaterThanOrEqualTo(bar),
          reason:
              'The ring measures ${contrastRatio(ring, fill).toStringAsFixed(2)}'
              ' to 1 against the disc it is drawn on, and a graphic carrying '
              'information needs $bar to 1.',
        );

        // Outer edge: the ring against what the app puts behind the mark. Until
        // real photography ships that is the climbed placeholder, and it is the
        // only flat colour a climbed card paints, so it is what the mark lands
        // on rather than one candidate among several.
        expect(
          fills,
          [palette.peakPlaceholderClimbed],
          reason:
              'A climbed card no longer paints the climbed placeholder and '
              'nothing else behind the mark, so the background this test '
              'measures the ring against is out of date.',
        );
        final behind = fills.single;
        expect(
          contrastRatio(ring, behind),
          greaterThanOrEqualTo(bar),
          reason:
              'The ring measures '
              '${contrastRatio(ring, behind).toStringAsFixed(2)} to 1 against '
              'what the card draws behind the mark, and it needs $bar to 1.',
        );

        // The whole point of the ring, stated as a number: the disc's own fill
        // does not clear the bar against that background, so without the ring
        // the mark is carried by an edge that is not there.
        expect(
          contrastRatio(fill, behind),
          lessThan(bar),
          reason:
              'The disc fill now clears $bar to 1 against the card behind it, '
              'so the reason this file exists has changed. Re-read '
              'CairnSize.markRing before deciding the ring is spare: it is '
              'there for photographs nobody has taken yet, not for the '
              'placeholder.',
        );
      });
    }
  });

  group('discs that must stay bare', () {
    for (final kind in BadgeKind.values) {
      testWidgets('an earned $kind on a card has no ring', (tester) async {
        await pumpCairn(
          tester,
          BadgeDisc(kind: kind, unlocked: true, glyph: const CairnMark()),
        );

        expect(
          ringOf(tester),
          BorderSide.none,
          reason:
              'A disc that sits on a card measures against a known surface and '
              'is already listed in the contrast suite. Ringing it would put a '
              'ring around every badge on the badges screen.',
        );
      });
    }

    for (final overImagery in <bool>[false, true]) {
      testWidgets('a locked disc takes the hairline, overImagery '
          '$overImagery', (tester) async {
        await pumpCairn(
          tester,
          BadgeDisc(
            kind: BadgeKind.peak,
            unlocked: false,
            overImagery: overImagery,
            glyph: const CairnMark(),
          ),
        );

        final side = ringOf(tester);
        expect(side.width, CairnSize.hairline);
        expect(side.color, CairnPalette.light.inkMuted);
      });
    }
  });

  test('the ring is thicker than a hairline', () {
    // Asserted against the token rather than against 2, so a deliberate change
    // to the number is free. Zero, or a drop to the hairline, is not: that is
    // how a ring gets deleted without anybody writing BorderSide.none.
    expect(
      CairnSize.markRing,
      greaterThan(CairnSize.hairline),
      reason:
          'A ring at hairline width or less is the hint CairnSize.markRing says '
          'it must not be.',
    );
  });
}
