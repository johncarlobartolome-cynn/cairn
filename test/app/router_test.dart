import 'package:cairn/app/router.dart';
import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/database/tables/mountains.dart' show Difficulty;
import 'package:cairn/shared/widgets/badge_tile.dart';
import 'package:cairn/shared/widgets/cairn_back_button.dart';
import 'package:cairn/shared/widgets/empty_state.dart';
import 'package:cairn/shared/widgets/peak_card.dart';
import 'package:cairn/shared/widgets/pill_nav.dart';
import 'package:cairn/shared/widgets/stat_tile.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late Mountain firstPeak;

  setUp(() async {
    db = createTestDatabase();
    // Opening the database runs the seed, so the first frame already has rows.
    // The peaks come back alphabetical, so the first one is on screen unscrolled.
    firstPeak = (await MountainDao(db).getAll()).first;
  });

  tearDown(() => db.close());

  group('every route builds', () {
    testWidgets('/ lists the peaks from the database under the nav', (
      tester,
    ) async {
      await pumpApp(tester, db);

      // The greeting, lower case, so it cannot match the nav's own 'Peaks'
      // label. The count it used to carry moved to the progress line, and
      // `peaks_screen_test.dart` is where that is held to the rows in the
      // database rather than to a constant.
      expect(find.text('peaks'), findsOneWidget);
      expect(find.byType(PeakCard), findsWidgets);
      expect(find.text(firstPeak.name), findsOneWidget);
      expect(find.byType(PillNav), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('/ puts the peaks two to a row', (tester) async {
      await pumpApp(tester, db);

      // This used to assert all six were built at once and it no longer holds.
      // T20 put a progress line and a row of filter pills above the grid, and
      // that space comes out of the cards: at this view size the third row now
      // starts below the fold, so the list has not built it yet.
      //
      // The claim the grid still owes the design is that the set reads as a
      // set, which is the geometry below plus a third row visible enough to say
      // the list carries on. `peaks_screen_test.dart` holds that one, with the
      // measurements, because it is the rule two tickets have already broken.
      expect(find.byType(PeakCard), findsAtLeastNWidgets(4));

      final cards = find.byType(PeakCard);
      final first = tester.getRect(cards.at(0));
      final second = tester.getRect(cards.at(1));
      final third = tester.getRect(cards.at(2));

      // Two side by side: same top, the second one to the right of the first.
      expect(second.top, first.top);
      expect(second.left, greaterThan(first.right));
      // Half the width each, so the pair spans the page inside its margins.
      expect(second.width, moreOrLessEquals(first.width, epsilon: 0.5));
      // The third card starts the next row, under the first.
      expect(third.top, greaterThan(first.bottom));
      expect(third.left, moreOrLessEquals(first.left, epsilon: 0.5));

      await disposeApp(tester);
    });

    testWidgets('a card carries elevation and difficulty, not region', (
      tester,
    ) async {
      await pumpApp(tester, db);

      expect(tester.takeException(), isNull);
      expect(find.text('811 m'), findsOneWidget);
      expect(find.text('Moderate'), findsWidgets);

      // Region belongs to peak detail. On a card it pushed the footer onto a
      // third line, which grew every card until the last row fell off the
      // screen, and that is the grid losing the one job it has.
      expect(find.text('Batangas'), findsNothing);
      expect(find.textContaining('Benguet'), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('a card is handed exactly two facts', (tester) async {
      await pumpApp(tester, db);

      // Whether all six land on one screen is a question about real glyph
      // widths, and this harness paints a fallback font roughly twice Manrope's
      // width, so it cannot answer that. The device screenshots do. What holds
      // here regardless of font is what the card is given.
      for (final card in tester.widgetList<PeakCard>(find.byType(PeakCard))) {
        expect(card.meta, hasLength(2));
      }

      await disposeApp(tester);
    });

    testWidgets('a taller footer beside a shorter one does not overflow', (
      tester,
    ) async {
      // Two peaks that sort ahead of the seeds, so they share the first row. The
      // long name runs to two lines and carries a meta row, the short one has
      // neither. That is the uneven pair E2 will create for real.
      final dao = MountainDao(db);
      await dao.add(
        MountainsCompanion.insert(name: 'Apo', region: const Value('Davao')),
      );
      await dao.add(
        MountainsCompanion.insert(
          name: 'Bulusan Volcano Natural Park Summit',
          region: const Value('Sorsogon'),
          elevationM: const Value(1565),
          difficulty: const Value(Difficulty.hard),
        ),
      );

      await pumpApp(tester, db);

      // A row that overflowed would report a FlutterError, and it lands here.
      expect(tester.takeException(), isNull);

      final cards = find.byType(PeakCard);
      final short = tester.getRect(cards.at(0));
      final tall = tester.getRect(cards.at(1));

      expect(find.text('Apo'), findsOneWidget);
      expect(find.text('Bulusan Volcano Natural Park Summit'), findsOneWidget);
      // Proof the second card is the fuller one.
      expect(find.text('1,565 m'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      // The row takes its height from the taller card and both match it, so
      // neither footer is clipped and the row still lines up.
      expect(short.height, tall.height);
      expect(short.top, tall.top);

      await disposeApp(tester);
    });

    testWidgets('/badges builds and keeps the nav', (tester) async {
      await pumpApp(tester, db, location: CairnRoute.badges);

      expect(find.text('badges'), findsOneWidget);
      // The six seeded peaks and the three milestones, every one still locked.
      // T19 replaced the empty state that stood here from T5.
      expect(find.byType(BadgeTile), findsNWidgets(9));
      expect(find.byType(PillNav), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('/mountain/:id opens straight from a deep link, no nav', (
      tester,
    ) async {
      await pumpApp(tester, db, location: CairnRoute.mountain(firstPeak.id));

      expect(find.text(firstPeak.name), findsOneWidget);
      // Elevation and difficulty. T23 moved hours and region out of tiles and
      // into the subtitle under the name, so two is the whole grid now.
      expect(find.byType(StatTile), findsNWidgets(2));

      // Batulao is alphabetically first, so it is the peak a deep link to
      // `firstPeak` opens. Its four figures below are the ones the peak-data
      // note verified. All four are still on the screen after T23; two of them
      // stopped being boxes.
      expect(firstPeak.name, 'Mt. Batulao');
      expect(find.text('811 m'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('3 hours to the summit'), findsOneWidget);
      expect(find.text('Batangas'), findsOneWidget);

      // The grid used to draw four dashes, because every column behind it was
      // null. The tiles were always reading these fields and had nothing to
      // read. Nothing in this screen changed to fill them.
      expect(find.text('–'), findsNothing);
      expect(find.byType(PillNav), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('/climb/:id opens straight from a deep link, no nav', (
      tester,
    ) async {
      final climbId = await ClimbDao(db).add(
        ClimbsCompanion.insert(
          mountainId: firstPeak.id,
          date: DateTime.utc(2026, 8, 11),
          companions: const Value('Ana'),
          notes: const Value('Cold at the summit.'),
        ),
      );

      await pumpApp(tester, db, location: CairnRoute.climb(climbId));

      expect(find.text('11 August 2026'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Cold at the summit.'), findsOneWidget);
      expect(find.byType(PillNav), findsNothing);

      await disposeApp(tester);
    });
  });

  group('a miss does not crash', () {
    testWidgets('/mountain/999 shows a themed not-found state', (tester) async {
      await pumpApp(tester, db, location: '/mountain/999');

      expect(tester.takeException(), isNull);
      expect(find.text('Peak not found'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      // Themed, not a red screen: the card is on the palette's surface.
      expect(find.byType(FilledButton), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('/climb/999 shows a themed not-found state', (tester) async {
      await pumpApp(tester, db, location: '/climb/999');

      expect(tester.takeException(), isNull);
      expect(find.text('Climb not found'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('an id that is not a number misses the same way', (
      tester,
    ) async {
      await pumpApp(tester, db, location: '/mountain/not-an-id');

      expect(tester.takeException(), isNull);
      expect(find.text('Peak not found'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('a location that matches nothing shows the router state', (
      tester,
    ) async {
      await pumpApp(tester, db, location: '/somewhere-else');

      expect(tester.takeException(), isNull);
      expect(find.text('Nothing here'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('the not-found state can get back to the peaks list', (
      tester,
    ) async {
      await pumpApp(tester, db, location: '/mountain/999');

      await tester.tap(find.text('Back to peaks'));
      await tester.pumpAndSettle();

      expect(find.text('peaks'), findsOneWidget);
      expect(find.byType(PillNav), findsOneWidget);

      await disposeApp(tester);
    });
  });

  group('navigation', () {
    testWidgets('the nav swaps destinations and stays on screen', (
      tester,
    ) async {
      await pumpApp(tester, db);

      await tester.tap(find.text('Badges'));
      await tester.pumpAndSettle();
      // The badges screen's heading. Lower case, so it cannot match the nav's
      // own 'Badges' label.
      expect(find.text('badges'), findsOneWidget);
      expect(find.byType(PillNav), findsOneWidget);

      await tester.tap(find.text('Peaks'));
      await tester.pumpAndSettle();
      expect(find.text('peaks'), findsOneWidget);
      expect(find.byType(PillNav), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('tapping a peak card pushes its detail over the shell', (
      tester,
    ) async {
      await pumpApp(tester, db);

      await tester.tap(find.byType(PeakCard).first);
      await tester.pumpAndSettle();

      expect(find.byType(StatTile), findsNWidgets(2));
      // The shell is behind the pushed page, so its nav is off screen.
      expect(find.byType(PillNav), findsNothing);

      await disposeApp(tester);
    });
  });

  group('a detail screen always has a way out', () {
    /// Pushes [location] over whatever the shell is showing.
    ///
    /// Tapping a card is the real route into peak detail, but nothing in the UI
    /// links to a climb until E3. Pushing gives that screen the same history a
    /// tap would, and pushing from the badges branch is what tells a pop apart
    /// from the fallback: a pop returns to badges, the fallback always lands on
    /// the peaks list.
    Future<void> pushOverShell(WidgetTester tester, String location) async {
      GoRouter.of(tester.element(find.byType(PillNav))).push(location);
      await tester.pumpAndSettle();
    }

    testWidgets('peak detail reached by a tap pops back to the list', (
      tester,
    ) async {
      await pumpApp(tester, db);
      await tester.tap(find.byType(PeakCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(CairnBackButton), findsOneWidget);

      await tester.tap(find.byType(CairnBackButton));
      await tester.pumpAndSettle();

      expect(find.text('peaks'), findsOneWidget);
      expect(find.byType(PillNav), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('peak detail opened cold goes to the peaks list', (
      tester,
    ) async {
      await pumpApp(tester, db, location: CairnRoute.mountain(firstPeak.id));

      // The defect: with no history the bar drew nothing, so the found branch
      // had no exit at all.
      expect(find.byType(CairnBackButton), findsOneWidget);

      await tester.tap(find.byType(CairnBackButton));
      await tester.pumpAndSettle();

      expect(find.text('peaks'), findsOneWidget);
      expect(find.byType(PillNav), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('climb detail pushed over the shell pops back to badges', (
      tester,
    ) async {
      final climbId = await ClimbDao(db).add(
        ClimbsCompanion.insert(
          mountainId: firstPeak.id,
          date: DateTime.utc(2026, 8, 11),
        ),
      );

      await pumpApp(tester, db, location: CairnRoute.badges);
      await pushOverShell(tester, CairnRoute.climb(climbId));
      expect(find.text('11 August 2026'), findsOneWidget);

      await tester.tap(find.byType(CairnBackButton));
      await tester.pumpAndSettle();

      // Badges, not the peaks list: the control popped rather than reaching for
      // its fallback.
      // The badges screen's heading. Lower case, so it cannot match the nav's
      // own 'Badges' label.
      expect(find.text('badges'), findsOneWidget);
      expect(find.byType(PillNav), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('climb detail opened cold goes to the peaks list', (
      tester,
    ) async {
      final climbId = await ClimbDao(db).add(
        ClimbsCompanion.insert(
          mountainId: firstPeak.id,
          date: DateTime.utc(2026, 8, 11),
        ),
      );

      await pumpApp(tester, db, location: CairnRoute.climb(climbId));
      expect(find.byType(CairnBackButton), findsOneWidget);

      await tester.tap(find.byType(CairnBackButton));
      await tester.pumpAndSettle();

      expect(find.text('peaks'), findsOneWidget);
      expect(find.byType(PillNav), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('a detail that misses carries the control too', (tester) async {
      await pumpApp(tester, db, location: '/mountain/999');
      expect(find.byType(CairnBackButton), findsOneWidget);

      await tester.tap(find.byType(CairnBackButton));
      await tester.pumpAndSettle();

      expect(find.text('peaks'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('peak detail pushed from badges pops back to badges', (
      tester,
    ) async {
      await pumpApp(tester, db, location: CairnRoute.badges);
      await pushOverShell(tester, CairnRoute.mountain(firstPeak.id));
      // The peak's own name as well as the tile count, because badges carries
      // a two-tile row of its own and the count alone stopped telling the two
      // screens apart once T23 took peak detail down to two.
      expect(find.text(firstPeak.name), findsOneWidget);
      expect(find.byType(StatTile), findsNWidgets(2));

      await tester.tap(find.byType(CairnBackButton));
      await tester.pumpAndSettle();

      // The badges screen's heading. Lower case, so it cannot match the nav's
      // own 'Badges' label.
      expect(find.text('badges'), findsOneWidget);

      await disposeApp(tester);
    });
  });

  group('the floating nav gets its clearance', () {
    // The nav's own number, so a change to the bar cannot leave a screen padding
    // a stale guess. The test view has no gesture inset, so the inset term is 0.
    final expected = CairnSpace.x12 + PillNav.barHeight + CairnSpace.x12;

    testWidgets('the peaks list pads its bottom by the nav clearance', (
      tester,
    ) async {
      await pumpApp(tester, db);

      final list = tester.widget<ListView>(find.byType(ListView));
      expect((list.padding! as EdgeInsets).bottom, expected);

      await disposeApp(tester);
    });

    testWidgets('the badges screen pads its bottom by the nav clearance', (
      tester,
    ) async {
      await pumpApp(tester, db, location: CairnRoute.badges);

      final scroller = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect((scroller.padding! as EdgeInsets).bottom, expected);

      await disposeApp(tester);
    });
  });
}
