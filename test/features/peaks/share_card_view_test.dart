import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/features/peaks/share_card.dart';
import 'package:cairn/features/peaks/widgets/share_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_widget.dart';

/// The card as it is painted. Its strings are held by `share_card_test.dart`;
/// this is about the picture drawing all of them, at a fixed size, with nothing
/// cut off.
void main() {
  const ShareCard pulag = ShareCard(
    peakName: 'Mt. Pulag',
    climbedLine: 'Climbed 11 August 2026',
    facts: <String>['2,922 m', 'Easy'],
    tally: 'That makes 3 of 6 peaks.',
    message: 'Mt. Pulag, climbed 11 August 2026. That makes 3 of 6 peaks.',
    filename: 'cairn-mt-pulag.png',
  );

  Size cardSize(WidgetTester tester) =>
      tester.getSize(find.byType(ShareCardView));

  testWidgets('every fact on the card is drawn', (tester) async {
    await pumpCairn(tester, const ShareCardView(card: pulag));

    expect(find.text('Mt. Pulag'), findsOneWidget);
    expect(find.text('Climbed 11 August 2026'), findsOneWidget);
    expect(find.text('2,922 m'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('That makes 3 of 6 peaks.'), findsOneWidget);
    // The app's name, quietly, and nothing else selling it.
    expect(find.text('CAIRN'), findsOneWidget);
  });

  testWidgets('no climb photograph is anywhere near it', (tester) async {
    await pumpCairn(tester, const ShareCardView(card: pulag));

    // A climb's photos can hold a companion's face or a front door. Sending one
    // has to be an act the user chose, not a side effect of a tally, so nothing
    // on this card loads an image at all.
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('the picture is the same width whatever the phone is', (
    tester,
  ) async {
    // Wrapped the way the sheet wraps it. `scaleDown` hands the card unbounded
    // constraints and scales the drawing rather than the layout, so the size
    // the export is taken at does not move with the handset.
    Widget asShared() => const FittedBox(
      fit: BoxFit.scaleDown,
      child: ShareCardView(card: pulag),
    );

    await pumpCairn(tester, asShared(), width: 1000);
    expect(cardSize(tester).width, ShareCardView.width);

    // Narrower than the card itself. The preview shrinks, the card does not.
    await pumpCairn(tester, asShared(), width: 200);
    expect(cardSize(tester).width, ShareCardView.width);
  });

  testWidgets('a peak nobody could shorten wraps instead of being cut', (
    tester,
  ) async {
    const ShareCard long = ShareCard(
      peakName: 'Mount Guiting-Guiting Traverse from Magdiwang',
      climbedLine: 'Climbed 11 August 2026',
      facts: <String>['2,058 m', 'Hard'],
      tally: 'That makes 3 of 6 peaks.',
      message: 'x',
      filename: 'cairn-x.png',
    );

    await pumpCairn(tester, const ShareCardView(card: pulag));
    final double short = cardSize(tester).height;

    await pumpCairn(tester, const ShareCardView(card: long));

    // Taller, because the name took another line. Same width, because that is
    // what the export is measured against.
    expect(cardSize(tester).height, greaterThan(short));
    expect(cardSize(tester).width, ShareCardView.width);

    // And every word of it is still on the card. An ellipsis here would hide
    // exactly the part the reader wanted.
    for (final Text text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.overflow, isNot(TextOverflow.ellipsis), reason: text.data);
      expect(text.data, isNot(contains('…')), reason: text.data);
    }
  });

  testWidgets('a peak with no facts recorded drops the row, not the card', (
    tester,
  ) async {
    const ShareCard bare = ShareCard(
      peakName: 'Mt. Nowhere',
      climbedLine: 'Climbed 11 August 2026',
      facts: <String>[],
      tally: 'That makes 1 of 6 peaks.',
      message: 'x',
      filename: 'cairn-x.png',
    );

    await pumpCairn(tester, const ShareCardView(card: bare));

    expect(find.text('Mt. Nowhere'), findsOneWidget);
    expect(find.text('That makes 1 of 6 peaks.'), findsOneWidget);
    // No lone separator left standing where the facts would have been.
    expect(find.text(CairnGlyph.metaSeparator), findsNothing);
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets('it carries its own ground in $brightness', (tester) async {
      await pumpCairn(
        tester,
        const ShareCardView(card: pulag),
        brightness: brightness,
      );

      // The picture lands on a chat app's own background, so it cannot borrow
      // one. Every pixel of the frame is painted, and the card floats on it.
      final ColoredBox ground = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(ShareCardView),
              matching: find.byType(ColoredBox),
            )
            .first,
      );

      expect(ground.color, paletteFor(brightness).ground);
      expect(ground.color.a, 1);
    });
  }
}
