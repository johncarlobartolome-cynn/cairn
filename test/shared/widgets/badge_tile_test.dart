import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/shared/widgets/badge_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_widget.dart';

void main() {
  /// The glyph disc is the innermost decorated container, so its fill is what
  /// separates the three states.
  BoxDecoration discOf(WidgetTester tester) {
    final containers = tester.widgetList<Container>(find.byType(Container));
    return containers
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.shape == BoxShape.circle);
  }

  testWidgets('locked draws an outline with a muted glyph', (tester) async {
    await pumpCairn(
      tester,
      const BadgeTile(
        label: 'Mt. Apo',
        icon: Icons.terrain_rounded,
        state: BadgeTileState.locked,
      ),
      width: 120,
    );

    final disc = discOf(tester);
    expect(disc.color, Colors.transparent);
    expect(disc.border, isNotNull);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.terrain_rounded)).color,
      CairnPalette.light.inkMuted,
    );
  });

  testWidgets('unlocked takes the brand fill', (tester) async {
    await pumpCairn(
      tester,
      const BadgeTile(
        label: 'Mt. Pulag',
        icon: Icons.terrain_rounded,
        state: BadgeTileState.unlocked,
        caption: '12 Jul',
      ),
      width: 120,
    );

    expect(discOf(tester).color, CairnPalette.light.brand);
    expect(find.text('12 Jul'), findsOneWidget);
  });

  testWidgets('a milestone takes gold, the one non-green colour', (
    tester,
  ) async {
    await pumpCairn(
      tester,
      const BadgeTile(
        label: 'All six',
        icon: Icons.workspace_premium_rounded,
        state: BadgeTileState.unlockedMilestone,
      ),
      width: 120,
    );

    expect(discOf(tester).color, CairnPalette.light.gold);
  });

  testWidgets('holds its layout in a 3-up grid cell', (tester) async {
    // The size a 3-column grid gives it on a 360dp phone, at the aspect the
    // widget documents. The label wraps to two lines at this width.
    await pumpCairn(
      tester,
      const SizedBox(
        height: 144,
        child: BadgeTile(
          label: 'Guiting-Guiting',
          icon: Icons.terrain_rounded,
          state: BadgeTileState.unlocked,
          caption: '12 Jul 2026',
        ),
      ),
      width: 98,
    );

    expect(tester.takeException(), isNull);
  });
}
