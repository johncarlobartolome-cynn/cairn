import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/shared/widgets/filter_pill_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_widget.dart';

void main() {
  const labels = ['All', 'To climb', 'Climbed'];

  Color? labelColour(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color;

  testWidgets('fills exactly one pill', (tester) async {
    await pumpCairn(
      tester,
      FilterPillRow(
        labels: labels,
        selectedIndex: 1,
        onSelected: (_) {},
      ),
      width: 360,
    );

    const p = CairnPalette.light;
    expect(labelColour(tester, 'To climb'), p.onBrand);
    expect(labelColour(tester, 'All'), p.inkMuted);
    expect(labelColour(tester, 'Climbed'), p.inkMuted);
  });

  testWidgets('reports the tapped index', (tester) async {
    final taps = <int>[];
    await pumpCairn(
      tester,
      FilterPillRow(labels: labels, selectedIndex: 0, onSelected: taps.add),
      width: 360,
    );

    await tester.tap(find.text('Climbed'));
    expect(taps, [2]);
  });

  testWidgets('scrolls instead of overflowing at a narrow width', (
    tester,
  ) async {
    await pumpCairn(
      tester,
      FilterPillRow(labels: labels, selectedIndex: 0, onSelected: (_) {}),
      width: 140,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
