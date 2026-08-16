import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/shared/widgets/badge_disc.dart';
import 'package:cairn/shared/widgets/badge_tile.dart';
import 'package:cairn/shared/widgets/cairn_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_widget.dart';

void main() {
  /// The glyph disc's decoration, which carries the fill and the silhouette.
  ShapeDecoration discOf(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: find.byType(BadgeDisc),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration
          as ShapeDecoration;

  testWidgets('locked draws an outline with a muted glyph', (tester) async {
    await pumpCairn(
      tester,
      const BadgeTile(
        label: 'Mt. Apo',
        glyph: CairnMark(),
        kind: BadgeKind.peak,
        state: BadgeTileState.locked,
      ),
      width: 120,
    );

    final disc = discOf(tester);
    expect(disc.color, Colors.transparent);
    expect((disc.shape as OutlinedBorder).side.color, CairnPalette.light.inkMuted);
  });

  testWidgets('unlocked takes the brand fill', (tester) async {
    await pumpCairn(
      tester,
      const BadgeTile(
        label: 'Mt. Pulag',
        glyph: CairnMark(),
        kind: BadgeKind.peak,
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
        label: 'All peaks',
        glyph: Icon(Icons.workspace_premium_rounded),
        kind: BadgeKind.milestone,
        state: BadgeTileState.unlocked,
      ),
      width: 120,
    );

    expect(discOf(tester).color, CairnPalette.light.gold);
  });

  testWidgets('the kind picks the silhouette, in both states', (tester) async {
    for (final state in BadgeTileState.values) {
      await pumpCairn(
        tester,
        BadgeTile(
          label: 'Three peaks',
          glyph: const Icon(Icons.filter_hdr_rounded),
          kind: BadgeKind.milestone,
          state: state,
        ),
        width: 120,
      );
      expect(discOf(tester).shape, isA<BadgeSealBorder>(), reason: '$state');

      await pumpCairn(
        tester,
        BadgeTile(
          label: 'Mt. Pulag',
          glyph: const CairnMark(),
          kind: BadgeKind.peak,
          state: state,
        ),
        width: 120,
      );
      expect(discOf(tester).shape, isA<CircleBorder>(), reason: '$state');
    }
  });

  testWidgets('the disc sizes and colours the glyph it is handed', (
    tester,
  ) async {
    // The caller passes a bare Icon with no size and no colour, and the disc
    // publishes both through an IconTheme. This is what lets a peak badge carry
    // a painted mark and a milestone carry a Material icon without either call
    // site knowing how big a badge glyph is.
    await pumpCairn(
      tester,
      const BadgeTile(
        label: 'First climb',
        glyph: Icon(Icons.flag_rounded),
        kind: BadgeKind.milestone,
        state: BadgeTileState.unlocked,
      ),
      width: 120,
    );

    final theme = IconTheme.of(
      tester.element(find.byIcon(Icons.flag_rounded)),
    );
    expect(theme.size, CairnSize.iconBadgeGlyph);
    expect(theme.color, CairnPalette.light.ink);
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
        glyph: CairnMark(),
        kind: BadgeKind.peak,
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
          glyph: const CairnMark(),
          kind: BadgeKind.peak,
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
