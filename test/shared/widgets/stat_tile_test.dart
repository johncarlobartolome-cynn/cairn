import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/shared/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_widget.dart';

void main() {
  testWidgets('shows the value and shouts the caption', (tester) async {
    await pumpCairn(
      tester,
      const StatTile(value: '2,922 m', caption: 'Elevation'),
      width: 160,
    );

    expect(find.text('2,922 m'), findsOneWidget);
    expect(find.text('ELEVATION'), findsOneWidget);
  });

  testWidgets('stands in a dash for an unknown value', (tester) async {
    // Most mountain fields are nullable, so an empty tile is a normal state.
    await pumpCairn(
      tester,
      const StatTile(value: '', caption: 'Difficulty'),
      width: 160,
    );

    expect(find.text('–'), findsOneWidget);
  });

  testWidgets('lays out without overflow at a narrow width', (tester) async {
    await pumpCairn(
      tester,
      const StatTile(
        value: '2,922 m',
        caption: 'Elevation above sea level',
        icon: Icons.height_rounded,
      ),
      width: 88,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('two tiles survive a narrow 2-up row', (tester) async {
    await pumpCairn(
      tester,
      const Row(
        children: [
          Expanded(child: StatTile(value: 'Very hard', caption: 'Difficulty')),
          SizedBox(width: CairnSpace.x12),
          Expanded(child: StatTile(value: '2,954 m', caption: 'Elevation')),
        ],
      ),
      width: 200,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a long value wraps instead of being cut short', (tester) async {
    // Region is a province and a town for every curated peak, and a peak the
    // user adds can run longer again. The tile used to be one line with
    // wrapping off, so it drew "Batangas (" and an ellipsis. Cutting the value
    // someone opened the tile to read is the wrong answer.
    await pumpCairn(
      tester,
      const StatTile(
        value: 'Batangas (Nasugbu)',
        caption: 'Region',
        icon: Icons.place_outlined,
      ),
      width: 160,
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Batangas (Nasugbu)'),
    );

    expect(tester.takeException(), isNull);

    // Two lines of text, where truncating would have left one line and an
    // ellipsis. This harness paints a fallback font about twice Manrope's
    // width, so how much fits per line here means nothing; that the value takes
    // a second line rather than being cut on the first is the behaviour.
    expect(paragraph.size.height, greaterThan(paragraph.preferredLineHeight));
    expect(tester.widget<Text>(find.text('Batangas (Nasugbu)')).maxLines, 2);
  });

  testWidgets('a wrapped tile and a short one keep a row level', (
    tester,
  ) async {
    // The 2x2 grid on peak detail sets these side by side, so one of them
    // taking a second line must not leave the other short or out of line. The
    // arrangement here is the grid's own: IntrinsicHeight, tiles stretched.
    await pumpCairn(
      tester,
      const IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: StatTile(value: 'Zambales (Cabangan)', caption: 'Region'),
            ),
            SizedBox(width: CairnSpace.x12),
            Expanded(child: StatTile(value: '3 h', caption: 'Hours')),
          ],
        ),
      ),
      width: 360,
    );

    final tiles = find.byType(StatTile);
    final wrapped = tester.getRect(tiles.at(0));
    final short = tester.getRect(tiles.at(1));

    expect(tester.takeException(), isNull);
    expect(short.top, wrapped.top);
    expect(short.height, wrapped.height);
  });

  testWidgets('emphasised tile switches to the soft accent fill', (
    tester,
  ) async {
    await pumpCairn(
      tester,
      const StatTile(value: '3 / 6', caption: 'Climbed', emphasised: true),
      width: 160,
    );

    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, CairnPalette.light.accentSoft);
  });
}
