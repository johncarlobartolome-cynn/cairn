import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/shared/widgets/meta_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_widget.dart';

void main() {
  testWidgets('separates facts with a dot', (tester) async {
    await pumpCairn(
      tester,
      const MetaRow(['2,922 m', 'Hard', '8 h']),
      width: 320,
    );

    expect(find.text('2,922 m'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('8 h'), findsOneWidget);
    // Three facts, two separators.
    expect(find.text(CairnGlyph.metaSeparator), findsNWidgets(2));
  });

  testWidgets('drops nulls and blanks instead of printing empty gaps', (
    tester,
  ) async {
    await pumpCairn(
      tester,
      const MetaRow(['2,922 m', null, '   ', 'Hard']),
      width: 320,
    );

    expect(find.text(CairnGlyph.metaSeparator), findsOneWidget);
  });

  testWidgets('collapses when everything is missing', (tester) async {
    await pumpCairn(tester, const MetaRow([null, '']), width: 320);

    expect(find.byType(Text), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('wraps rather than overflowing at a narrow width', (
    tester,
  ) async {
    await pumpCairn(
      tester,
      const MetaRow(['2,954 m', 'Very hard', '2 days', 'Davao del Sur']),
      width: 110,
    );

    expect(tester.takeException(), isNull);
    // Wrapping means more than one run, which is the point of using Wrap here.
    expect(tester.getSize(find.byType(Wrap)).height, greaterThan(20));
  });

  testWidgets('honours an override style', (tester) async {
    await pumpCairn(
      tester,
      const MetaRow(['Benguet'], style: TextStyle(fontSize: 20)),
      width: 320,
    );

    expect(tester.widget<Text>(find.text('Benguet')).style?.fontSize, 20);
  });
}
