import 'dart:async';

import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/providers.dart';
import 'package:cairn/shared/widgets/peak_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// The list, driven by the log rather than by a fixture.
///
/// `peak_card_test.dart` proves the treatment renders. This proves the app
/// hands the card the truth: a peak with a climb against it comes out at full
/// colour with its mark, and its neighbour with no climb comes out desaturated
/// and washed.
///
/// Both peaks used here are the first two alphabetically, so they sit in the
/// first row and are built without scrolling.
void main() {
  const climbedName = 'Mt. Batulao';
  const unclimbedName = 'Mt. Daraitan';
  const climbedMark = Icons.terrain_rounded;

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
      (await mountains.getAll()).firstWhere((p) => p.name == name).id;

  Finder cardFor(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(PeakCard));

  bool climbedFlag(WidgetTester tester, String name) =>
      tester.widget<PeakCard>(cardFor(name)).climbed;

  testWidgets('a climbed peak reads differently from an unclimbed one', (
    tester,
  ) async {
    await climbs.logClimb(
      mountainId: await idOf(climbedName),
      date: DateTime.utc(2026, 8, 15),
    );

    await pumpApp(tester, db);

    expect(climbedFlag(tester, climbedName), isTrue);
    expect(climbedFlag(tester, unclimbedName), isFalse);

    // The three signals the design names, read off the cards themselves.
    expect(
      find.descendant(of: cardFor(climbedName), matching: find.byIcon(climbedMark)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: cardFor(climbedName),
        matching: find.byType(ColorFiltered),
      ),
      findsNothing,
      reason: 'a climbed photo is not desaturated',
    );
    expect(
      find.descendant(
        of: cardFor(unclimbedName),
        matching: find.byIcon(climbedMark),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: cardFor(unclimbedName),
        matching: find.byType(ColorFiltered),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.text(climbedName)).style?.color,
      CairnPalette.light.ink,
    );
    expect(
      tester.widget<Text>(find.text(unclimbedName)).style?.color,
      CairnPalette.light.inkMuted,
    );

    // One climb, one climbed card. The other five stay as they were.
    expect(find.byIcon(climbedMark), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('every card is unclimbed while the log is empty', (tester) async {
    await pumpApp(tester, db);

    expect(find.byIcon(climbedMark), findsNothing);
    expect(climbedFlag(tester, climbedName), isFalse);

    await disposeApp(tester);
  });

  testWidgets('a card turns to colour when its climb is logged', (
    tester,
  ) async {
    await pumpApp(tester, db);
    expect(climbedFlag(tester, climbedName), isFalse);

    await climbs.logClimb(
      mountainId: await idOf(climbedName),
      date: DateTime.utc(2026, 8, 15),
    );
    // The list watches the query, so the write is the only trigger it needs.
    await tester.pump();
    await tester.pump();

    expect(climbedFlag(tester, climbedName), isTrue);
    expect(climbedFlag(tester, unclimbedName), isFalse);

    await disposeApp(tester);
  });

  testWidgets('holds every card back until the climbed set answers', (
    tester,
  ) async {
    // Finding N8. The list used to default the climbed set to empty while its
    // query was still running, so the first frame of a cold start drew every
    // peak grey and the next one snapped the climbed ones to colour. This gate
    // stands in for a slow read: nothing may claim a peak is unclimbed before
    // the answer is in.
    final gate = StreamController<Set<int>>();
    addTearDown(gate.close);

    final id = await idOf(climbedName);
    await climbs.logClimb(mountainId: id, date: DateTime.utc(2026, 8, 15));

    await pumpApp(
      tester,
      db,
      overrides: [climbedMountainIdsProvider.overrideWith((ref) => gate.stream)],
    );

    expect(find.byType(PeakCard), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.add(<int>{id});
    await tester.pump();

    expect(find.byType(PeakCard), findsWidgets);
    expect(climbedFlag(tester, climbedName), isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await disposeApp(tester);
  });
}
