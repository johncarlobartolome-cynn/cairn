import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/shared/widgets/cairn_mark.dart';
import 'package:cairn/shared/widgets/peak_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_widget.dart';

/// The climbed / unclimbed split is the app's whole point, so it is asserted
/// rather than eyeballed. Three signals carry it: the saturation filter, the
/// name's colour, and the mark.
void main() {
  Color? nameColour(WidgetTester tester, String name) =>
      tester.widget<Text>(find.text(name)).style?.color;

  group('PeakCard climbed state', () {
    testWidgets('renders at full colour with the climbed mark', (tester) async {
      await pumpCairn(
        tester,
        const PeakCard(
          name: 'Mt. Pulag',
          climbed: true,
          meta: ['2,922 m', 'Hard', 'Climbed 12 Jul'],
        ),
        width: 360,
      );

      expect(find.text('Mt. Pulag'), findsOneWidget);
      expect(find.byType(CairnMark), findsOneWidget);
      // No filter wrapper at all, so a real photo comes through untouched.
      expect(find.byType(ColorFiltered), findsNothing);
      expect(nameColour(tester, 'Mt. Pulag'), CairnPalette.light.ink);
      expect(find.text('Climbed 12 Jul'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('placeholder takes the accent fill', (tester) async {
      await pumpCairn(
        tester,
        const PeakCard(name: 'Mt. Pulag', climbed: true),
        width: 360,
      );

      final fills = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => b.color)
          .toList();
      expect(fills, contains(CairnPalette.light.peakPlaceholderClimbed));
    });
  });

  group('PeakCard unclimbed state', () {
    testWidgets('desaturates, washes, and drops the mark', (tester) async {
      await pumpCairn(
        tester,
        const PeakCard(
          name: 'Mt. Apo',
          climbed: false,
          meta: ['2,954 m', 'Hard'],
        ),
        width: 360,
      );

      expect(find.text('Mt. Apo'), findsOneWidget);
      expect(find.byType(CairnMark), findsNothing);
      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(nameColour(tester, 'Mt. Apo'), CairnPalette.light.inkMuted);

      final fills = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => b.color)
          .toList();
      // Grey-green placeholder underneath, cream wash on top of it.
      expect(fills, contains(CairnPalette.light.peakPlaceholderUnclimbed));
      expect(fills, contains(CairnPalette.light.unclimbedWash));
      expect(tester.takeException(), isNull);
    });

    testWidgets('placeholder fill differs from the climbed one', (
      tester,
    ) async {
      expect(
        CairnPalette.light.peakPlaceholderUnclimbed,
        isNot(CairnPalette.light.peakPlaceholderClimbed),
      );
      expect(
        CairnPalette.dark.peakPlaceholderUnclimbed,
        isNot(CairnPalette.dark.peakPlaceholderClimbed),
      );
    });
  });

  testWidgets('holds its layout at a narrow width', (tester) async {
    await pumpCairn(
      tester,
      const PeakCard(
        name: 'Mt. Guiting-Guiting',
        climbed: true,
        meta: ['2,058 m', 'Very hard', '3 d', 'Climbed 12 Jul'],
      ),
      width: 240,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a third fact makes the card taller', (tester) async {
    // The reason the peaks list stops at two facts. Region as a third one sent
    // the footer onto another line on every card, and three rows of that pushed
    // the last row off the screen, which is the thing the grid exists to
    // prevent.
    //
    // Both cards render at the same half-screen width, so the extra item is the
    // only difference between them.
    //
    // Measured as intrinsic height rather than laid-out height, because that is
    // the number the grid actually uses: a row of cards goes through
    // IntrinsicHeight, and the tallest card in it sets the row.
    const half = 170.0;

    Future<double> heightOf(List<String?> meta) async {
      await pumpCairn(
        tester,
        PeakCard(name: 'Mt. Batulao', climbed: false, meta: meta),
        width: half,
      );
      return tester
          .renderObject<RenderBox>(find.byType(PeakCard))
          .getMaxIntrinsicHeight(half);
    }

    final twoFacts = await heightOf(['811 m', 'Moderate']);
    final threeFacts = await heightOf(['Batangas', '811 m', 'Moderate']);

    expect(
      threeFacts,
      greaterThan(twoFacts),
      reason:
          'the card grew from ${twoFacts}dp to ${threeFacts}dp on one extra '
          'fact, and the grid pays that three rows over',
    );
  });

  testWidgets('a name longer than any of the six is never cut', (tester) async {
    // The card held its name to two lines and an ellipsis until T26, which was
    // fine for the six seeded peaks and wrong for the app: it lets somebody add
    // a peak of their own, and a `…` hides exactly the part that tells two
    // traverses of the same mountain apart.
    //
    // The fake test font is about twice Manrope's width, so a name that fits
    // here fits on the phone with room to spare, and a name that is cut here
    // would be cut anywhere.
    const long = 'Mt. Guiting-Guiting Traverse from Magdiwang to San Fernando';

    await pumpCairn(
      tester,
      const PeakCard(name: long, climbed: false, meta: ['2,058 m', 'Hard']),
      // Half of a 360dp phone, which is the width the grid gives a card.
      width: 170,
    );

    final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.text.toPlainText(), long);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long name makes the card taller rather than shorter text', (
    tester,
  ) async {
    // Where the wrapped name goes. A row of cards is measured by
    // IntrinsicHeight, so the card growing is what the grid absorbs, and this is
    // the number it absorbs.
    const short = 'Mt. Ulap';
    const long = 'Mt. Guiting-Guiting Traverse from Magdiwang to San Fernando';

    Future<double> heightOf(String name) async {
      await pumpCairn(
        tester,
        PeakCard(name: name, climbed: false, meta: const ['2,058 m', 'Hard']),
        width: 170,
      );
      return tester
          .renderObject<RenderBox>(find.byType(PeakCard))
          .getMaxIntrinsicHeight(170);
    }

    expect(await heightOf(long), greaterThan(await heightOf(short)));
  });

  testWidgets('reports taps', (tester) async {
    var taps = 0;
    await pumpCairn(
      tester,
      PeakCard(name: 'Mt. Apo', climbed: false, onTap: () => taps++),
      width: 360,
    );

    await tester.tap(find.text('Mt. Apo'));
    expect(taps, 1);
  });

  testWidgets('carries the treatment into the dark palette', (tester) async {
    await pumpCairn(
      tester,
      const PeakCard(name: 'Mt. Apo', climbed: false),
      width: 360,
      brightness: Brightness.dark,
    );

    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(nameColour(tester, 'Mt. Apo'), CairnPalette.dark.inkMuted);
  });
}
