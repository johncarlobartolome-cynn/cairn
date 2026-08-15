import 'package:cairn/app/router.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/features/climbs/climb_facts.dart';
import 'package:cairn/features/climbs/mark_climbed_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// The sheet, driven the way a person drives it: open peak detail, tap the
/// action, type, save, then look in the file.
///
/// The suite runs under more than one `TZ`, so every assertion about the stored
/// day is also an assertion that the day did not move. See climb_date_test.dart
/// for the column's side of the same rule.
void main() {
  late AppDatabase db;
  late ClimbDao climbs;
  late MountainDao mountains;

  setUp(() {
    db = createTestDatabase();
    climbs = ClimbDao(db);
    mountains = MountainDao(db);
  });

  tearDown(() => db.close());

  Future<int> pulagId() async =>
      (await mountains.getAll()).firstWhere((p) => p.name == 'Mt. Pulag').id;

  /// A field found by the hint it is showing, which only works while it is
  /// empty. Fill them in the order they are asked for and it holds.
  Finder fieldWithHint(String hint) =>
      find.ancestor(of: find.text(hint), matching: find.byType(TextField));

  /// Opens peak detail and taps its primary action.
  Future<void> openSheet(WidgetTester tester, int mountainId) async {
    await pumpApp(tester, db, location: CairnRoute.mountain(mountainId));
    await tester.tap(find.text('Mark climbed'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkClimbedSheet), findsOneWidget);
  }

  /// Taps Save and lets the write and the sheet's exit animation finish. The
  /// snack bar is still on screen when this returns.
  ///
  /// Read what landed with [ClimbDao.getAll] rather than with `watchAll().first`:
  /// opening and cancelling a Drift stream inside a widget test leaves the
  /// cleanup work the fake clock cannot get past, and every later pump hangs.
  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text('Save climb'));
    await tester.pumpAndSettle();
  }

  /// Today as the sheet reads it: the local calendar day, clock time dropped.
  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  testWidgets('peak detail carries the action', (tester) async {
    await pumpApp(tester, db, location: CairnRoute.mountain(await pulagId()));

    expect(find.text('Mark climbed'), findsOneWidget);
    expect(find.byType(MarkClimbedSheet), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('saves what was typed, dated today', (tester) async {
    final id = await pulagId();
    final day = today();

    await openSheet(tester, id);

    await tester.enterText(
      fieldWithHint('Who you climbed with'),
      'Mara and Enzo',
    );
    await tester.enterText(
      fieldWithHint('How the climb went'),
      'Sea of clouds at sunrise.',
    );
    await tester.pump();

    await tapSave(tester);

    expect(find.byType(MarkClimbedSheet), findsNothing);

    final saved = (await climbs.getAll()).single;
    expect(saved.mountainId, id);
    expect(saved.companions, 'Mara and Enzo');
    expect(saved.notes, 'Sea of clouds at sunrise.');
    // The local day the tap happened on, whatever zone the run is in.
    expect(saved.date, DateTime.utc(day.year, day.month, day.day));

    await disposeApp(tester);
  });

  testWidgets('says so once the climb is in', (tester) async {
    await openSheet(tester, await pulagId());
    await tapSave(tester);

    expect(find.text('Climb saved'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('saves with both optional fields left empty', (tester) async {
    final id = await pulagId();

    await openSheet(tester, id);
    await tapSave(tester);

    final saved = (await climbs.getAll()).single;
    expect(saved.mountainId, id);
    expect(saved.companions, isNull);
    expect(saved.notes, isNull);

    await disposeApp(tester);
  });

  testWidgets('opens on today, spelled out in full', (tester) async {
    await openSheet(tester, await pulagId());

    expect(find.text('DATE'), findsOneWidget);
    expect(find.text(climbDayLabel(today())), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('saves the day picked instead of today', (tester) async {
    // The whole point of the field being pickable: a climb logged days later
    // still carries the day you were on the mountain.
    final id = await pulagId();
    final day = today();

    await openSheet(tester, id);

    await tester.tap(find.text(climbDayLabel(day)));
    await tester.pumpAndSettle();

    // The first of this month, which is always on or before today and always
    // inside the picker's range.
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text(climbDayLabel(DateTime(day.year, day.month))), findsOneWidget);

    await tapSave(tester);

    expect(
      (await climbs.getAll()).single.date,
      DateTime.utc(day.year, day.month),
    );

    await disposeApp(tester);
  });

  testWidgets('a second climb of the same peak is saved, not refused', (
    tester,
  ) async {
    final id = await pulagId();

    await openSheet(tester, id);
    await tapSave(tester);

    await tester.tap(find.text('Mark climbed'));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(await climbs.getAll(), hasLength(2));

    await disposeApp(tester);
  });

  testWidgets('wraps in a SafeArea, like every other screen', (tester) async {
    await openSheet(tester, await pulagId());

    expect(
      find.descendant(
        of: find.byType(MarkClimbedSheet),
        matching: find.byType(SafeArea),
      ),
      findsWidgets,
    );

    await disposeApp(tester);
  });

  testWidgets('names a long peak in full rather than cutting it', (
    tester,
  ) async {
    const long = 'Mt. Guiting-Guiting Traverse from Magdiwang';
    final id = await mountains.add(MountainsCompanion.insert(name: long));

    await openSheet(tester, id);

    // The name as the sheet draws it. Peak detail is showing the same string
    // behind it, so the finder has to say which of the two it means.
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(MarkClimbedSheet),
        matching: find.text(long),
      ),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);

    await disposeApp(tester);
  });
}
