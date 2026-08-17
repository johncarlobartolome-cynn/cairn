import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/shared/widgets/cairn_mark.dart';
import 'package:cairn/shared/widgets/peak_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_widget.dart';

/// The one visual event the app is built around, and whether it can be seen.
///
/// Marking a peak climbed turns its card from grey to colour, and before T26 it
/// turned instantly, on a list two screens behind the sheet doing the marking.
/// So this file is about three things: that a settled card never moves, that a
/// card changing under a reader takes [CairnPeak.reveal] to do it, and that both
/// reduced motion and a route nobody is looking at are respected.
void main() {
  const String peak = 'Mt. Batulao';

  /// The card at one state, pumped into the same element tree every time so a
  /// second call is a change to the reader rather than a fresh card.
  Future<void> show(
    WidgetTester tester, {
    required bool climbed,
    bool disableAnimations = false,
    bool tickers = true,
  }) => pumpCairn(
    tester,
    TickerMode(
      enabled: tickers,
      child: PeakCard(name: peak, climbed: climbed, meta: const ['811 m']),
    ),
    width: 360,
    disableAnimations: disableAnimations,
  );

  Color? nameColour(WidgetTester tester) =>
      tester.widget<Text>(find.text(peak)).style?.color;

  /// The cream wash over an unclimbed photo, or null once it is gone.
  double? washAlpha(WidgetTester tester) {
    for (final ColoredBox box in tester.widgetList<ColoredBox>(
      find.byType(ColoredBox),
    )) {
      // The wash is the only fill drawn from the ground colour.
      if (box.color.r == CairnPalette.light.ground.r &&
          box.color.g == CairnPalette.light.ground.g &&
          box.color.b == CairnPalette.light.ground.b) {
        return box.color.a;
      }
    }
    return null;
  }

  /// True while the card is drawn part way between its two states.
  bool midReveal(WidgetTester tester) {
    final double? wash = washAlpha(tester);
    return wash != null && wash > 0 && wash < CairnPeak.washOpacity;
  }

  testWidgets('a card that is already climbed draws climbed, still', (
    tester,
  ) async {
    // The first paint of a climbed card must not animate. Every launch would
    // otherwise open on a list of peaks colouring themselves in, which is a
    // celebration of nothing having happened.
    await show(tester, climbed: true);

    expect(find.byType(CairnMark), findsOneWidget);
    expect(find.byType(ColorFiltered), findsNothing);
    expect(nameColour(tester), CairnPalette.light.ink);
    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'nothing changed, so nothing should be moving',
    );
  });

  testWidgets('a card marked climbed under the reader takes the reveal to '
      'change', (tester) async {
    await show(tester, climbed: false);
    expect(washAlpha(tester), CairnPeak.washOpacity);

    await show(tester, climbed: true);
    await tester.pump();

    // The reveal opens on a wait, so the colour has not begun to move while the
    // list is still sliding in. See [CairnPeak.reveal] for the 195ms.
    expect(washAlpha(tester), CairnPeak.washOpacity);
    expect(find.byType(CairnMark), findsNothing);
    expect(tester.hasRunningAnimations, isTrue);

    // Half way: the photograph is coming up and the mark is arriving behind it.
    await tester.pump(CairnPeak.reveal * 0.65);
    expect(midReveal(tester), isTrue, reason: 'the change is part way through');
    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(nameColour(tester), isNot(CairnPalette.light.ink));
    expect(nameColour(tester), isNot(CairnPalette.light.inkMuted));

    // And it lands on exactly the tree a climbed card has always drawn.
    await tester.pumpAndSettle();
    expect(washAlpha(tester), isNull);
    expect(find.byType(ColorFiltered), findsNothing);
    expect(find.byType(CairnMark), findsOneWidget);
    expect(nameColour(tester), CairnPalette.light.ink);
    expect(
      find.ancestor(of: find.byType(CairnMark), matching: find.byType(Opacity)),
      findsNothing,
      reason: 'a settled mark carries no fade layer',
    );
  });

  testWidgets('reduced motion gets the end state with nothing moving', (
    tester,
  ) async {
    // An accessibility setting, not a preference: the answer is the end state in
    // this frame rather than the same animation played slowly.
    await show(tester, climbed: false, disableAnimations: true);
    await show(tester, climbed: true, disableAnimations: true);
    await tester.pump();

    expect(find.byType(CairnMark), findsOneWidget);
    expect(find.byType(ColorFiltered), findsNothing);
    expect(washAlpha(tester), isNull);
    expect(nameColour(tester), CairnPalette.light.ink);
    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'reduced motion means there was never an animation to run',
    );
  });

  testWidgets('the change waits for a list nobody is looking at', (
    tester,
  ) async {
    // The mechanism the whole feature rests on. A climb is saved from a sheet
    // over peak detail, so the card is rebuilt climbed while the peaks list sits
    // under an opaque route. TickerMode is off there, so the card holds the
    // state it is drawing and releases it on the frame the list comes back.
    //
    // Muting the animation instead of holding the target back was the obvious
    // move and it is wrong: a ticker stamps its start time when it starts, so
    // the first tick after the route is revealed arrives with the whole visit to
    // peak detail already elapsed and the reveal finishes in that one frame.
    // Which is what this test would catch.
    await show(tester, climbed: false, tickers: false);
    await show(tester, climbed: true, tickers: false);

    // Long enough for several reveals, if it were running at all.
    await tester.pump(CairnPeak.reveal * 4);

    expect(
      washAlpha(tester),
      CairnPeak.washOpacity,
      reason: 'the card should still be grey behind the route over it',
    );
    expect(find.byType(CairnMark), findsNothing);

    // Back to the list, which is when it plays.
    await show(tester, climbed: true);
    await tester.pump();
    await tester.pump(CairnPeak.reveal * 0.65);
    expect(midReveal(tester), isTrue, reason: 'now it is running');

    await tester.pumpAndSettle();
    expect(find.byType(CairnMark), findsOneWidget);
    expect(washAlpha(tester), isNull);
  });

  testWidgets('the reveal carries into the dark palette', (tester) async {
    await pumpCairn(
      tester,
      const PeakCard(name: peak, climbed: false),
      width: 360,
      brightness: Brightness.dark,
    );
    await pumpCairn(
      tester,
      const PeakCard(name: peak, climbed: true),
      width: 360,
      brightness: Brightness.dark,
    );
    await tester.pump();
    await tester.pump(CairnPeak.reveal * 0.65);

    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpAndSettle();
    expect(find.byType(ColorFiltered), findsNothing);
    expect(nameColour(tester), CairnPalette.dark.ink);
  });
}
