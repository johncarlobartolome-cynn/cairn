import 'package:cairn/app/router.dart';
import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/shared/widgets/empty_state.dart';
import 'package:cairn/shared/widgets/peak_card.dart';
import 'package:cairn/shared/widgets/pill_nav.dart';
import 'package:cairn/shared/widgets/stat_tile.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

      // The heading counts the rows it was handed, so a six here is six rows out
      // of the database rather than six cards laid out by hand.
      expect(find.text('6 peaks'), findsOneWidget);
      expect(find.byType(PeakCard), findsWidgets);
      expect(find.text(firstPeak.name), findsOneWidget);
      expect(find.byType(PillNav), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('/badges builds and keeps the nav', (tester) async {
      await pumpApp(tester, db, location: CairnRoute.badges);

      expect(find.text('badges'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(PillNav), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('/mountain/:id opens straight from a deep link, no nav', (
      tester,
    ) async {
      await pumpApp(tester, db, location: CairnRoute.mountain(firstPeak.id));

      expect(find.text(firstPeak.name), findsOneWidget);
      // Elevation, difficulty, hours, region.
      expect(find.byType(StatTile), findsNWidgets(4));
      // Every one of those fields is still null, so every tile shows a dash
      // rather than a number nobody recorded.
      expect(find.text('–'), findsNWidgets(4));
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

      expect(find.text('6 peaks'), findsOneWidget);
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
      expect(find.text('No badges yet'), findsOneWidget);
      expect(find.byType(PillNav), findsOneWidget);

      await tester.tap(find.text('Peaks'));
      await tester.pumpAndSettle();
      expect(find.text('6 peaks'), findsOneWidget);
      expect(find.byType(PillNav), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('tapping a peak card pushes its detail over the shell', (
      tester,
    ) async {
      await pumpApp(tester, db);

      await tester.tap(find.byType(PeakCard).first);
      await tester.pumpAndSettle();

      expect(find.byType(StatTile), findsNWidgets(4));
      // The shell is behind the pushed page, so its nav is off screen.
      expect(find.byType(PillNav), findsNothing);

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
