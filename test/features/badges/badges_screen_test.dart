import 'package:cairn/app/router.dart';
import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/shared/widgets/badge_disc.dart';
import 'package:cairn/shared/widgets/badge_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// The badges screen against the app's own database.
///
/// `badge_board_test.dart` proves the reconciliation; `badge_tile_test.dart`
/// proves the three treatments draw. This proves the screen hands the tile the
/// truth, and that a locked tile says what is left to do rather than sitting
/// there as an anonymous grey disc.
void main() {
  /// First two peaks alphabetically, so both are in the first row of the grid.
  const climbedName = 'Mt. Batulao';
  const unclimbedName = 'Mt. Daraitan';

  late AppDatabase db;
  late MountainDao mountains;
  late ClimbDao climbs;

  setUp(() {
    db = createTestDatabase();
    mountains = MountainDao(db);
    climbs = ClimbDao(db);
  });

  tearDown(() => db.close());

  Future<int> idOf(String name) async =>
      (await mountains.getAll()).firstWhere((peak) => peak.name == name).id;

  Finder tileFor(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(BadgeTile));

  BadgeTileState stateOf(WidgetTester tester, String label) =>
      tester.widget<BadgeTile>(tileFor(label)).state;

  BadgeKind kindOf(WidgetTester tester, String label) =>
      tester.widget<BadgeTile>(tileFor(label)).kind;

  /// The disc's decoration, which carries both of the things a reader sees: the
  /// fill, and the outline the fill is poured into.
  ShapeDecoration discOf(WidgetTester tester, String label) =>
      tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: find.descendant(
                    of: tileFor(label),
                    matching: find.byType(BadgeDisc),
                  ),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration
          as ShapeDecoration;

  /// Opens `/badges` with one climb already logged, which unlocks that peak's
  /// badge and the first-climb milestone and leaves everything else locked.
  Future<void> pumpAfterOneClimb(WidgetTester tester) async {
    await climbs.logClimb(
      mountainId: await idOf(climbedName),
      date: DateTime.utc(2026, 8, 15),
    );
    await pumpApp(tester, db, location: CairnRoute.badges);
  }

  testWidgets('a locked badge reads differently from an unlocked one', (
    tester,
  ) async {
    await pumpAfterOneClimb(tester);

    expect(stateOf(tester, climbedName), BadgeTileState.unlocked);
    expect(stateOf(tester, unclimbedName), BadgeTileState.locked);

    // Not just a different enum: a filled disc against an empty one.
    expect(discOf(tester, climbedName).color, CairnPalette.light.brand);
    expect(discOf(tester, unclimbedName).color, Colors.transparent);

    await disposeApp(tester);
  });

  testWidgets('a locked badge says how to earn it', (tester) async {
    await pumpAfterOneClimb(tester);

    expect(
      find.descendant(
        of: tileFor(unclimbedName),
        matching: find.text('Climb it.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tileFor('Three peaks'),
        matching: find.text('Climb three different peaks.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tileFor('All peaks'),
        matching: find.text('Climb every peak in your library.'),
      ),
      findsOneWidget,
    );

    // Every locked tile, not only the three checked by name.
    final locked = tester
        .widgetList<BadgeTile>(find.byType(BadgeTile))
        .where((tile) => tile.state == BadgeTileState.locked);
    expect(locked, isNotEmpty);
    for (final tile in locked) {
      expect(tile.caption?.trim(), isNotEmpty, reason: tile.label);
    }

    await disposeApp(tester);
  });

  testWidgets('an unlocked badge shows the day it was earned, not the rule', (
    tester,
  ) async {
    await pumpAfterOneClimb(tester);

    final earned = tester.widget<BadgeTile>(tileFor(climbedName));
    expect(earned.caption, isNot('Climb it.'));
    expect(earned.caption, contains('2026'));

    await disposeApp(tester);
  });

  testWidgets('a milestone takes a different shape, not just a different fill', (
    tester,
  ) async {
    await pumpAfterOneClimb(tester);

    // Colour still separates them, and after T22 it is no longer doing it
    // alone: the milestone's disc is a seal and the peak's is a circle, which
    // is the half of the distinction that survives being read in greyscale.
    // `test/a11y/badge_greyscale_test.dart` is where that gets measured.
    expect(kindOf(tester, 'First climb'), BadgeKind.milestone);
    expect(stateOf(tester, 'First climb'), BadgeTileState.unlocked);
    expect(discOf(tester, 'First climb').color, CairnPalette.light.gold);
    expect(discOf(tester, 'First climb').shape, isA<BadgeSealBorder>());

    expect(kindOf(tester, climbedName), BadgeKind.peak);
    expect(stateOf(tester, climbedName), BadgeTileState.unlocked);
    expect(discOf(tester, climbedName).color, CairnPalette.light.brand);
    expect(discOf(tester, climbedName).shape, isA<CircleBorder>());

    await disposeApp(tester);
  });

  testWidgets('a locked milestone keeps the seal a locked peak badge lacks', (
    tester,
  ) async {
    await pumpApp(tester, db, location: CairnRoute.badges);

    // The case the old three-value state enum could not say. Both are locked,
    // both draw an outline in the same muted ink, and the shape is the only
    // thing left telling a reader which is which.
    expect(stateOf(tester, 'Three peaks'), BadgeTileState.locked);
    expect(discOf(tester, 'Three peaks').shape, isA<BadgeSealBorder>());

    expect(stateOf(tester, unclimbedName), BadgeTileState.locked);
    expect(discOf(tester, unclimbedName).shape, isA<CircleBorder>());

    await disposeApp(tester);
  });

  testWidgets(
    'the grid is the library plus the milestones, never a fixed six',
    (tester) async {
      await mountains.add(MountainsCompanion.insert(name: 'Mt. Halcon'));
      final library = await mountains.getAll();
      expect(library, hasLength(7));

      await pumpApp(tester, db, location: CairnRoute.badges);

      // Seven peaks and three milestones, counted off the library rather than
      // typed in, so a seed change moves this number with it.
      expect(find.byType(BadgeTile), findsNWidgets(library.length + 3));
      for (final peak in library) {
        expect(tileFor(peak.name), findsOneWidget, reason: peak.name);
      }

      await disposeApp(tester);
    },
  );

  testWidgets('the counts match the tiles on screen', (tester) async {
    await pumpAfterOneClimb(tester);

    // Six peaks and three milestones, two of them earned.
    expect(find.text('2 of 9'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('a peak climbed before any badge existed reads as locked', (
    tester,
  ) async {
    // The emulator carries exactly this: climbs logged during E3, before T18
    // wrote the unlock. A save is what unlocks, and nothing backfills.
    await climbs.add(
      ClimbsCompanion.insert(
        mountainId: await idOf(climbedName),
        date: DateTime.utc(2026, 8, 1),
      ),
    );

    await pumpApp(tester, db, location: CairnRoute.badges);

    expect(stateOf(tester, climbedName), BadgeTileState.locked);
    expect(find.text('0 of 9'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('nothing on the screen is clipped', (tester) async {
    await pumpAfterOneClimb(tester);

    // A tile can carry a peak name of any length and a full sentence under it,
    // so the grid measures rather than guesses. Anything that overflowed its
    // row would land here.
    expect(tester.takeException(), isNull);
    for (final text in tester.widgetList<Text>(
      find.descendant(of: find.byType(BadgeTile), matching: find.byType(Text)),
    )) {
      expect(text.overflow, isNot(TextOverflow.ellipsis), reason: text.data);
      expect(text.maxLines, isNull, reason: text.data);
    }

    await disposeApp(tester);
  });
}
