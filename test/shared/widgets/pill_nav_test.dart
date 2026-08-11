import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/shared/widgets/pill_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_widget.dart';

void main() {
  final palette = CairnPalette.light;
  final inactive = palette.onBrand.withValues(alpha: 0.7);

  Color? labelColour(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color;

  testWidgets('has exactly the two destinations', (tester) async {
    await pumpCairn(tester, PillNav(currentIndex: 0, onSelected: (_) {}));

    expect(PillNav.destinations.length, 2);
    expect(find.text('Peaks'), findsOneWidget);
    expect(find.text('Badges'), findsOneWidget);
  });

  testWidgets('marks Peaks active on index 0', (tester) async {
    await pumpCairn(tester, PillNav(currentIndex: 0, onSelected: (_) {}));

    expect(labelColour(tester, 'Peaks'), palette.brand);
    expect(labelColour(tester, 'Badges'), inactive);
  });

  testWidgets('marks Badges active on index 1', (tester) async {
    await pumpCairn(tester, PillNav(currentIndex: 1, onSelected: (_) {}));

    expect(labelColour(tester, 'Badges'), palette.brand);
    expect(labelColour(tester, 'Peaks'), inactive);
  });

  testWidgets('reports the tapped index', (tester) async {
    final taps = <int>[];
    await pumpCairn(tester, PillNav(currentIndex: 0, onSelected: taps.add));

    await tester.tap(find.text('Badges'));
    await tester.tap(find.text('Peaks'));
    expect(taps, [1, 0]);
  });

  const gestureInset = 34.0;

  testWidgets('sits 12 above the gesture bar, never under it', (tester) async {
    await pumpCairn(
      tester,
      PillNav(currentIndex: 0, onSelected: (_) {}),
      alignment: Alignment.bottomCenter,
      safeAreaInset: const EdgeInsets.only(bottom: gestureInset),
    );

    final screenBottom = tester.getSize(find.byType(MaterialApp)).height;
    final barInner = tester.getRect(find.text('Peaks')).bottom;

    // Content stops short of the screen edge by the gesture inset plus the 12
    // the spec asks for.
    expect(screenBottom - barInner, greaterThanOrEqualTo(gestureInset + 12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a 12 gap when already inside a SafeArea', (tester) async {
    // The outer SafeArea has consumed the inset, so the nav must add only its
    // 12 rather than double-counting.
    await pumpCairn(
      tester,
      SafeArea(
        child: PillNav(currentIndex: 0, onSelected: (_) {}),
      ),
      alignment: Alignment.bottomCenter,
      safeAreaInset: const EdgeInsets.only(bottom: gestureInset),
    );

    final screenBottom = tester.getSize(find.byType(MaterialApp)).height;
    final barInner = tester.getRect(find.text('Peaks')).bottom;
    expect(screenBottom - barInner, greaterThanOrEqualTo(gestureInset + 12));
    expect(tester.takeException(), isNull);
  });
}
