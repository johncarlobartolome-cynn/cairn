import 'package:cairn/app/router.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/features/climbs/climb_detail_screen.dart';
import 'package:cairn/features/climbs/climb_facts.dart';
import 'package:cairn/shared/widgets/section_label.dart';
import 'package:cairn/shared/widgets/stat_tile.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// The longest of the six researched jump-offs, carrying a registration note on
/// top of the address. Held here rather than read out of the seed, so the test
/// keeps proving the layout even if the data changes.
const _longJumpOff =
    'Brgy. Poblacion, Bakun (register at Bakun National High School or the '
    'Municipal Tourism Council)';

/// Longer than any row on the screen, so a section that shortens its prose
/// shows it.
const _longNotes =
    'Left at three in the morning with head torches, hit the ridge just as the '
    'sky turned, and sat at the top for an hour watching the sea of clouds come '
    'apart over the valley.';

void main() {
  late AppDatabase db;
  late MountainDao dao;
  late ClimbDao climbs;

  setUp(() {
    db = createTestDatabase();
    dao = MountainDao(db);
    climbs = ClimbDao(db);
  });

  tearDown(() => db.close());

  /// A peak of its own, so the fixture never collides with a seeded name and the
  /// six shipped rows stay as they are.
  Future<int> addPeak({String? jumpOffPoint}) => dao.add(
    MountainsCompanion.insert(
      name: 'Mt. Tenglawan',
      jumpOffPoint: Value(jumpOffPoint),
    ),
  );

  group('the jump-off section', () {
    testWidgets('renders a long jump-off in full, wrapped, under its label', (
      tester,
    ) async {
      final id = await addPeak(jumpOffPoint: _longJumpOff);

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('JUMP-OFF POINT'), findsOneWidget);
      // The whole string is what the widget was handed, not a shortened one.
      expect(find.text(_longJumpOff), findsOneWidget);

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(_longJumpOff),
      );
      expect(paragraph.didExceedMaxLines, isFalse);

      // The same string laid out at the same width with nothing capping it. If
      // the section were clipping lines, the painted box would be shorter than
      // this one.
      final painter = TextPainter(
        text: TextSpan(
          text: _longJumpOff,
          style: tester.widget<Text>(find.text(_longJumpOff)).style,
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: paragraph.size.width);

      expect(painter.computeLineMetrics().length, greaterThan(1));
      expect(
        paragraph.size.height,
        moreOrLessEquals(painter.height, epsilon: 0.5),
      );

      // Below the 2x2 grid, which is where the design puts it.
      expect(
        tester.getRect(find.text('JUMP-OFF POINT')).top,
        greaterThan(tester.getRect(find.byType(StatTile).last).bottom),
      );
      expect(tester.takeException(), isNull);

      await disposeApp(tester);
    });

    testWidgets('is absent entirely, label included, when the field is null', (
      tester,
    ) async {
      final id = await addPeak();

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('JUMP-OFF POINT'), findsNothing);
      // Only the grid's label is left. An empty labelled section reads as a bug
      // rather than as a blank, so a peak with no jump-off shows nothing.
      expect(find.byType(SectionLabel), findsOneWidget);
      expect(find.text('DETAILS'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('treats a blank jump-off the same as a missing one', (
      tester,
    ) async {
      final id = await addPeak(jumpOffPoint: '   ');

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('JUMP-OFF POINT'), findsNothing);
      expect(find.byType(SectionLabel), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('a short jump-off gets no stat tile of its own', (
      tester,
    ) async {
      final id = await addPeak(
        jumpOffPoint: 'DENR Ambangeg Ranger Station, Bokod',
      );

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('DENR Ambangeg Ranger Station, Bokod'), findsOneWidget);
      // Still the four the design names: elevation, difficulty, hours, region.
      expect(find.byType(StatTile), findsNWidgets(4));

      await disposeApp(tester);
    });
  });

  group('the climbs section', () {
    /// Two climbs of the same peak, logged out of order on purpose so the
    /// screen's ordering cannot come from the insert order by accident.
    Future<int> peakWithTwoClimbs() async {
      final id = await addPeak();
      await climbs.logClimb(
        mountainId: id,
        date: DateTime.utc(2026, 5, 2),
        companions: 'Mara and Enzo',
      );
      await climbs.logClimb(mountainId: id, date: DateTime.utc(2026, 8, 15));
      return id;
    }

    testWidgets('lists a peak\'s climbs, newest first', (tester) async {
      final id = await peakWithTwoClimbs();

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      final newest = climbDayLabel(DateTime.utc(2026, 8, 15));
      final oldest = climbDayLabel(DateTime.utc(2026, 5, 2));

      expect(find.text('CLIMBS'), findsOneWidget);
      expect(find.text(newest), findsOneWidget);
      expect(find.text(oldest), findsOneWidget);
      expect(
        tester.getRect(find.text(newest)).top,
        lessThan(tester.getRect(find.text(oldest)).top),
      );

      // Below the jump-off and above the action, which is the order the design
      // lists the screen in.
      expect(
        tester.getRect(find.text('CLIMBS')).top,
        greaterThan(tester.getRect(find.byType(StatTile).last).bottom),
      );
      expect(
        tester.getRect(find.text('Mark climbed')).top,
        greaterThan(tester.getRect(find.text(oldest)).bottom),
      );

      await disposeApp(tester);
    });

    testWidgets('is absent entirely, label included, on a peak with no climbs', (
      tester,
    ) async {
      final id = await addPeak();

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('CLIMBS'), findsNothing);
      // Only the stat grid's own label is left on the screen.
      expect(find.byType(SectionLabel), findsOneWidget);
      expect(find.text('DETAILS'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('another peak\'s climbs stay on that peak', (tester) async {
      final id = await addPeak();
      final other = await dao.add(
        MountainsCompanion.insert(name: 'Mt. Timbak'),
      );
      await climbs.logClimb(mountainId: other, date: DateTime.utc(2026, 8, 15));

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('CLIMBS'), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('an entry opens that climb', (tester) async {
      final id = await peakWithTwoClimbs();
      final logged = await climbs.getAll();
      final newest = logged.first;

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      await tester.tap(find.text(climbDayLabel(newest.date)));
      await tester.pumpAndSettle();

      expect(find.byType(ClimbDetailScreen), findsOneWidget);
      expect(
        tester.widget<ClimbDetailScreen>(find.byType(ClimbDetailScreen)).climbId,
        newest.id,
      );
      // The real climb, not the not-found branch T5 shipped for an empty log.
      expect(find.text('Climb not found'), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('names companions in full and never cuts them', (tester) async {
      const companions = 'Mara, Enzo, Tito Ben and two guides from the barangay';
      final id = await addPeak();
      await climbs.logClimb(
        mountainId: id,
        date: DateTime.utc(2026, 8, 15),
        companions: companions,
      );

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text(companions), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(companions),
      );
      expect(paragraph.didExceedMaxLines, isFalse);

      await disposeApp(tester);
    });

    testWidgets('marks a note rather than previewing part of it', (
      tester,
    ) async {
      // The never-truncate rule. A prose note has no length a row can promise
      // to fit, so the row says a note is there and climb detail carries the
      // note itself.
      final id = await addPeak();
      await climbs.logClimb(
        mountainId: id,
        date: DateTime.utc(2026, 8, 15),
        notes: _longNotes,
      );

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('Note written'), findsOneWidget);
      expect(find.text(_longNotes), findsNothing);
      // Nothing on the screen is showing a shortened version of it either.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.startsWith('Left at three') ?? false),
        ),
        findsNothing,
      );

      final day = tester.renderObject<RenderParagraph>(
        find.text(climbDayLabel(DateTime.utc(2026, 8, 15))),
      );
      expect(day.didExceedMaxLines, isFalse);

      await disposeApp(tester);
    });

    testWidgets('a climb with nothing written on it is still a row', (
      tester,
    ) async {
      final id = await addPeak();
      await climbs.logClimb(mountainId: id, date: DateTime.utc(2026, 8, 15));

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('CLIMBS'), findsOneWidget);
      expect(find.text('Note written'), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('the section appears as soon as a climb is saved', (
      tester,
    ) async {
      final id = await addPeak();

      await pumpApp(tester, db, location: CairnRoute.mountain(id));
      expect(find.text('CLIMBS'), findsNothing);

      await climbs.logClimb(mountainId: id, date: DateTime.utc(2026, 8, 15));
      await tester.pump();
      await tester.pump();

      expect(find.text('CLIMBS'), findsOneWidget);
      expect(
        find.text(climbDayLabel(DateTime.utc(2026, 8, 15))),
        findsOneWidget,
      );

      await disposeApp(tester);
    });
  });
}
