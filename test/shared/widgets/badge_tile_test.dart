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

  testWidgets('a long name and a long condition are shown in full', (
    tester,
  ) async {
    // Squeezed to the narrowest cell the app could ever give it, with the
    // longest strings it carries: a peak name somebody typed, and the sentence
    // that says how to earn the badge.
    const name = 'Guiting-Guiting Traverse';
    const condition = 'Climb every peak in your library.';

    await pumpCairn(
      tester,
      const BadgeTile(
        label: name,
        icon: Icons.terrain_rounded,
        state: BadgeTileState.locked,
        caption: condition,
      ),
      width: 98,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(name), findsOneWidget);
    expect(find.text(condition), findsOneWidget);

    // An ellipsis on a locked tile hides the half a reader opened it for, so
    // neither line may cap itself. The tile grows instead, and the grid that
    // holds it measures rather than guessing an aspect ratio.
    for (final label in const <String>[name, condition]) {
      final line = tester.widget<Text>(find.text(label));
      expect(line.maxLines, isNull, reason: label);
      expect(line.overflow, isNot(TextOverflow.ellipsis), reason: label);
    }
  });

  testWidgets('it takes its height from its own content', (tester) async {
    Future<double> heightWith(String caption) async {
      await pumpCairn(
        tester,
        BadgeTile(
          label: 'Mt. Pulag',
          icon: Icons.terrain_rounded,
          state: BadgeTileState.locked,
          caption: caption,
        ),
        width: 154,
      );
      return tester.getSize(find.byType(BadgeTile)).height;
    }

    final short = await heightWith('Climb it.');
    final long = await heightWith('Climb every peak in your library.');

    // A caption that wraps makes the tile taller rather than cutting itself
    // down to a fixed one. This is why the grid rows go through IntrinsicHeight.
    expect(long, greaterThan(short));
  });
}
