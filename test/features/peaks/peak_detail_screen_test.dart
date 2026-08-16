import 'package:cairn/app/router.dart';
import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/database/seed/mountain_seed.dart';
import 'package:cairn/data/database/tables/mountains.dart' show Difficulty;
import 'package:cairn/features/climbs/climb_detail_screen.dart';
import 'package:cairn/features/climbs/climb_facts.dart';
import 'package:cairn/features/climbs/mark_climbed_sheet.dart';
import 'package:cairn/features/peaks/peak_facts.dart';
import 'package:cairn/features/peaks/peaks_screen.dart';
import 'package:cairn/shared/widgets/cairn_back_button.dart';
import 'package:cairn/shared/widgets/meta_row.dart';
import 'package:cairn/shared/widgets/section_label.dart';
import 'package:cairn/shared/widgets/stat_tile.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
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

  // The real bundled Manrope, so the never-truncate tests below measure the
  // font the app ships rather than the stand-in.
  //
  // `flutter test` substitutes a fixed-width test font for every family, and
  // its glyphs are far wider than Manrope's: "Moderate" at 20pt comes out
  // around 160dp under it against roughly 89 in the real face. A tile that
  // holds a value comfortably on the phone therefore overflows under the
  // substitute, so a truncation test run against it measures the harness
  // instead of the design. T22 settled that contrast is measured rather than
  // eyeballed; this is the same argument about width.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader(CairnType.family);
    for (final weight in const <String>[
      'Light',
      'Regular',
      'Medium',
      'SemiBold',
    ]) {
      loader.addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
    }
    await loader.load();
  });

  setUp(() {
    db = createTestDatabase();
    dao = MountainDao(db);
    climbs = ClimbDao(db);
  });

  tearDown(() => db.close());

  /// A peak of its own, so the fixture never collides with a seeded name and the
  /// six shipped rows stay as they are.
  ///
  /// Every field but the name is optional here because every column but the
  /// name is nullable in the database, and a peak somebody adds themselves may
  /// arrive with nothing else filled in.
  Future<int> addPeak({
    String name = 'Mt. Tenglawan',
    String? region,
    int? elevationM,
    Difficulty? difficulty,
    String? jumpOffPoint,
    double? estimatedHours,
  }) => dao.add(
    MountainsCompanion.insert(
      name: name,
      region: Value(region),
      elevationM: Value(elevationM),
      difficulty: Value(difficulty),
      jumpOffPoint: Value(jumpOffPoint),
      estimatedHours: Value(estimatedHours),
    ),
  );

  /// Every separator on the screen, wherever it sits.
  ///
  /// `textContaining` rather than `text`, so a dot baked into a longer string
  /// counts too. A join written by hand is how a subtitle grows a stray
  /// separator in the first place, and it produces "Benguet · null" as one
  /// [Text] that an exact match would walk straight past.
  ///
  /// The climb history draws meta rows of its own, so the tests that use this
  /// are on peaks with no climbs logged. That leaves the subtitle as the only
  /// meta row on the screen, and any dot found here is one it drew.
  Finder separators() => find.textContaining(CairnGlyph.metaSeparator);

  group('the subtitle under the name', () {
    testWidgets('says the region and the walk up, one dot between them', (
      tester,
    ) async {
      final id = await addPeak(region: 'Benguet', estimatedHours: 4);

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('Benguet'), findsOneWidget);
      expect(find.text('4 hours to the summit'), findsOneWidget);
      expect(separators(), findsOneWidget);

      // Under the name and above the tiles, which is the whole point of moving
      // these two facts out of boxes.
      final name = tester.getRect(find.text('Mt. Tenglawan'));
      final region = tester.getRect(find.text('Benguet'));
      expect(region.top, greaterThan(name.top));
      expect(region.bottom, lessThan(tester.getRect(find.byType(StatTile).first).top));

      await disposeApp(tester);
    });

    testWidgets('drops the separator when only the region is known', (
      tester,
    ) async {
      final id = await addPeak(region: 'Benguet');

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('Benguet'), findsOneWidget);
      // The failure this guards is a subtitle reading "Benguet ·" with nothing
      // after the dot, which is the shape a naive join produces.
      expect(separators(), findsNothing);
      expect(find.byType(MetaRow), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('drops the separator when only the walk up is known', (
      tester,
    ) async {
      final id = await addPeak(estimatedHours: 3);

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('3 hours to the summit'), findsOneWidget);
      // And the other way round: no leading dot before a fact with nothing in
      // front of it.
      expect(separators(), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('is absent entirely when the peak carries neither fact', (
      tester,
    ) async {
      final id = await addPeak();

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.byType(MetaRow), findsNothing);
      expect(separators(), findsNothing);
      // No blank line either: the tiles sit the same distance under the name
      // as they would if the subtitle had never been part of the design.
      final name = tester.getRect(find.text('Mt. Tenglawan'));
      final tiles = tester.getRect(find.byType(StatTile).first);
      expect(tiles.top - name.bottom, CairnSpace.x24);

      await disposeApp(tester);
    });

    testWidgets('says one hour rather than 1 hours', (tester) async {
      final id = await addPeak(estimatedHours: 1);

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('1 hour to the summit'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('keeps a half hour rather than rounding it away', (
      tester,
    ) async {
      final id = await addPeak(estimatedHours: 3.5);

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('3.5 hours to the summit'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('wraps a long region instead of cutting it', (tester) async {
      // Longer than any province in the country, and longer than the tile that
      // used to hold this field could ever have shown. A subtitle has no width
      // to fit inside, so this is the case the old layout could not answer.
      const long =
          'Zamboanga Sibugay and the whole of the Zamboanga Peninsula besides';
      final id = await addPeak(region: long, estimatedHours: 4);

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text(long), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);

      await disposeApp(tester);
    });
  });

  group('the two tiles', () {
    testWidgets('are elevation and difficulty, side by side, in that order', (
      tester,
    ) async {
      final id = await addPeak(
        elevationM: 1789,
        difficulty: Difficulty.moderate,
      );

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.byType(StatTile), findsNWidgets(2));
      expect(find.text('ELEVATION'), findsOneWidget);
      expect(find.text('DIFFICULTY'), findsOneWidget);
      expect(find.text('1,789 m'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);

      // One row: same top, elevation on the left.
      final elevation = tester.getRect(find.byType(StatTile).first);
      final difficulty = tester.getRect(find.byType(StatTile).last);
      expect(elevation.top, difficulty.top);
      expect(elevation.left, lessThan(difficulty.left));

      // Neither value is shortened, and neither caption is.
      for (final value in <String>[
        '1,789 m',
        'Moderate',
        'ELEVATION',
        'DIFFICULTY',
      ]) {
        expect(
          tester.renderObject<RenderParagraph>(find.text(value))
              .didExceedMaxLines,
          isFalse,
          reason: '$value was cut',
        );
      }

      await disposeApp(tester);
    });

    testWidgets('still draw, with a dash each, when neither is recorded', (
      tester,
    ) async {
      // The opposite rule to the subtitle's, and deliberately so. A tile is a
      // labelled slot, so the honest answer on a peak somebody typed in is that
      // the app does not know the elevation. A subtitle has no promised shape,
      // so an absent fact there is simply not said.
      final id = await addPeak();

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.byType(StatTile), findsNWidgets(2));
      expect(find.text('–'), findsNWidgets(2));

      await disposeApp(tester);
    });

    // The claim the whole rebuild rests on: the screen now shows every fact
    // whole, on real data, on the narrowest phone anyone runs Android on.
    // Measured against each of the six shipped peaks by name, so the day
    // somebody seeds a seventh with a longer value, the failure says which.
    //
    // The bound is conservative rather than tight. `flutter test` substitutes a
    // fixed-width test font for Manrope, and every glyph in it is wider than
    // the one it stands in for, so a value that fits here fits on the phone
    // with room left over. That also means this cannot assert a value takes
    // exactly one line: that number is a property of the fake font, not of the
    // screen. What it can assert is that nothing is ever cut, which is the rule
    // the design actually states.
    //
    // One test per peak rather than a loop inside one: `CairnApp` builds its
    // router once in its state, so pumping it a second time in the same test
    // would stay on the first peak and the other five would go unmeasured.
    for (final seeded in seededPeaks) {
      testWidgets('show ${seeded.name} whole at 320dp', (tester) async {
        final peak = (await dao.getAll()).firstWhere(
          (row) => row.name == seeded.name,
        );

        await pumpApp(
          tester,
          db,
          location: CairnRoute.mountain(peak.id),
          // A 320dp-wide handset, where a 20pt value in a half-width tile has
          // the least room it will ever get.
          physicalSize: const Size(960, 2040),
        );

        // The two in tiles, the two in the subtitle, and the prose below them.
        for (final value in <String>[
          peak.elevationLabel!,
          peak.difficultyLabel!,
          peak.region!,
          peak.summitTimeLabel!,
          peak.jumpOffLabel!,
        ]) {
          expect(find.text(value), findsOneWidget, reason: peak.name);
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(value))
                .didExceedMaxLines,
            isFalse,
            reason: '${peak.name}: "$value" was cut',
          );
        }

        // And no ellipsis anywhere on the screen, whoever drew it. The design
        // calls a `…` a bug rather than a fallback, so this looks for the
        // character itself rather than trusting the list above to be complete.
        expect(find.textContaining('…'), findsNothing, reason: peak.name);

        await disposeApp(tester);
      });
    }
  });

  group('the controls all survive the rebuild', () {
    testWidgets('the action sits above the climb history', (tester) async {
      final id = await addPeak(jumpOffPoint: 'Brgy. Ampucao, Itogon.');
      await climbs.logClimb(mountainId: id, date: DateTime.utc(2026, 8, 15));

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(
        tester.getRect(find.text('Mark climbed')).top,
        greaterThan(tester.getRect(find.text('JUMP-OFF POINT')).bottom),
      );
      expect(
        tester.getRect(find.text('Mark climbed')).bottom,
        lessThan(tester.getRect(find.text('CLIMBS')).top),
      );

      await disposeApp(tester);
    });

    testWidgets('the action still opens the mark-climbed sheet', (
      tester,
    ) async {
      final id = await addPeak();

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      await tester.tap(find.text('Mark climbed'));
      await tester.pumpAndSettle();

      expect(find.byType(MarkClimbedSheet), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('the share control is there on a climbed peak and not before', (
      tester,
    ) async {
      final id = await addPeak();

      await pumpApp(tester, db, location: CairnRoute.mountain(id));
      expect(find.byIcon(Icons.share_rounded), findsNothing);

      await climbs.logClimb(mountainId: id, date: DateTime.utc(2026, 8, 15));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.share_rounded), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('the back control still gets out', (tester) async {
      final id = await addPeak();

      await pumpApp(tester, db, location: CairnRoute.mountain(id));
      expect(find.byType(CairnBackButton), findsOneWidget);

      await tester.tap(find.byType(CairnBackButton));
      await tester.pumpAndSettle();

      // A deep link has nothing to pop, so the arrow goes home instead.
      expect(find.byType(PeaksScreen), findsOneWidget);

      await disposeApp(tester);
    });
  });

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

      // Below the tiles, which is where the design puts it.
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
      // Nothing labelled is left on the screen at all. An empty labelled
      // section reads as a bug rather than as a blank, so a peak with no
      // jump-off shows nothing, and T23 removed the DETAILS label that used to
      // sit above the grid: two tiles that each carry their own caption do not
      // need a heading saying they are details.
      expect(find.byType(SectionLabel), findsNothing);
      expect(find.text('DETAILS'), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('treats a blank jump-off the same as a missing one', (
      tester,
    ) async {
      final id = await addPeak(jumpOffPoint: '   ');

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('JUMP-OFF POINT'), findsNothing);
      expect(find.byType(SectionLabel), findsNothing);

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
      // The two T23 kept: elevation and difficulty.
      expect(find.byType(StatTile), findsNWidgets(2));

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

      // Last on the screen, under the action. T23 swapped those two: the log
      // grows a row per climb and the action does not, so an action underneath
      // it walks further off the fold with every trip up the same peak.
      expect(
        tester.getRect(find.text('CLIMBS')).top,
        greaterThan(tester.getRect(find.byType(StatTile).last).bottom),
      );
      expect(
        tester.getRect(find.text('CLIMBS')).top,
        greaterThan(tester.getRect(find.text('Mark climbed')).bottom),
      );

      await disposeApp(tester);
    });

    testWidgets('is absent entirely, label included, on a peak with no climbs', (
      tester,
    ) async {
      final id = await addPeak();

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('CLIMBS'), findsNothing);
      // This peak has no jump-off either, so nothing labelled is left at all.
      expect(find.byType(SectionLabel), findsNothing);

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
