import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/shared/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
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
