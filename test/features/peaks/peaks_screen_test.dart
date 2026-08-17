import 'dart:async';

import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/providers.dart';
import 'package:cairn/shared/widgets/cairn_mark.dart';
import 'package:cairn/shared/widgets/peak_card.dart';
import 'package:cairn/shared/widgets/pill_nav.dart';
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

  Future<void> logClimb(String name) async => climbs.logClimb(
    mountainId: await idOf(name),
    date: DateTime.utc(2026, 8, 15),
  );

  Future<void> climbEverything() async {
    for (final peak in await mountains.getAll()) {
      await climbs.logClimb(
        mountainId: peak.id,
        date: DateTime.utc(2026, 8, 15),
      );
    }
  }

  Finder cardFor(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(PeakCard));

  bool climbedFlag(WidgetTester tester, String name) =>
      tester.widget<PeakCard>(cardFor(name)).climbed;

  /// The progress count, as [SectionLabel] renders it. The widget uppercases so
  /// no caller has to shout in a string literal, and a finder has to follow.
  Finder progressCount(String sentence) => find.text(sentence.toUpperCase());

  Future<void> tapFilter(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump();
  }

  List<String> visibleNames(WidgetTester tester) => tester
      .widgetList<PeakCard>(find.byType(PeakCard))
      .map((card) => card.name)
      .toList(growable: false);

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
      find.descendant(
        of: cardFor(climbedName),
        matching: find.byType(CairnMark),
      ),
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
        matching: find.byType(CairnMark),
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
    expect(find.byType(CairnMark), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('every card is unclimbed while the log is empty', (tester) async {
    await pumpApp(tester, db);

    expect(find.byType(CairnMark), findsNothing);
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
      overrides: [
        climbedMountainIdsProvider.overrideWith((ref) => gate.stream),
      ],
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

  group('the progress count', () {
    testWidgets('counts the library rather than a constant', (tester) async {
      // Six ship in the seed and the feature set lets a climber add their own,
      // so a seventh peak has to move the total. A screen written against six
      // passes every other test in this file and lies the day one is added.
      await mountains.add(MountainsCompanion.insert(name: 'Mt. Zambales'));
      await logClimb(climbedName);

      await pumpApp(tester, db);

      expect(progressCount('1 of 7 climbed'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('moves as peaks are climbed', (tester) async {
      await pumpApp(tester, db);
      expect(progressCount('0 of 6 climbed'), findsOneWidget);

      await logClimb(climbedName);
      // The screen watches the query, so the write is the only trigger needed.
      await tester.pump();
      await tester.pump();

      expect(progressCount('1 of 6 climbed'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('fills the bar by the same fraction', (tester) async {
      await logClimb(climbedName);
      await logClimb(unclimbedName);

      await pumpApp(tester, db);

      expect(progressCount('2 of 6 climbed'), findsOneWidget);
      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(2 / 6, 0.001));

      await disposeApp(tester);
    });
  });

  group('the filters', () {
    // Three peaks rather than six, so every card the filter admits is built and
    // a missing name means the filter dropped it rather than the list not
    // having scrolled that far.
    Future<void> trimToThree() async {
      for (final peak in (await mountains.getAll()).skip(3)) {
        await mountains.removeById(peak.id);
      }
    }

    testWidgets('All shows every peak in the library', (tester) async {
      await trimToThree();
      await logClimb(climbedName);
      await pumpApp(tester, db);

      expect(visibleNames(tester), hasLength(3));
      expect(progressCount('1 of 3 climbed'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('To climb drops the peaks that have a climb', (tester) async {
      await trimToThree();
      await logClimb(climbedName);
      await pumpApp(tester, db);

      await tapFilter(tester, 'To climb');

      expect(visibleNames(tester), isNot(contains(climbedName)));
      expect(visibleNames(tester), hasLength(2));
      // The count is about the library, not about the filter, so it holds.
      expect(progressCount('1 of 3 climbed'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('Climbed keeps only the peaks that have one', (tester) async {
      await trimToThree();
      await logClimb(climbedName);
      await pumpApp(tester, db);

      await tapFilter(tester, 'Climbed');

      expect(visibleNames(tester), <String>[climbedName]);
      expect(climbedFlag(tester, climbedName), isTrue);

      await disposeApp(tester);
    });

    testWidgets('fills the pill that was tapped and no other', (tester) async {
      await pumpApp(tester, db);

      const palette = CairnPalette.light;
      Color? pill(String label) =>
          tester.widget<Text>(find.text(label)).style?.color;

      // All is where a launch starts.
      expect(pill('All'), palette.onBrand);

      await tapFilter(tester, 'To climb');
      expect(pill('To climb'), palette.onBrand);
      expect(pill('All'), palette.inkMuted);
      expect(pill('Climbed'), palette.inkMuted);

      await tapFilter(tester, 'Climbed');
      expect(pill('Climbed'), palette.onBrand);
      expect(pill('To climb'), palette.inkMuted);

      await disposeApp(tester);
    });

    testWidgets('opens on All again after a relaunch', (tester) async {
      // The filter is a question being asked now, not a setting. Coming back to
      // a grid holding one peak of six, because Climbed was still selected a
      // week ago, reads as lost data.
      await pumpApp(tester, db);
      await tapFilter(tester, 'Climbed');
      expect(find.text('Nothing climbed yet'), findsOneWidget);

      await disposeApp(tester);
      await pumpApp(tester, db);

      expect(
        tester.widget<Text>(find.text('All')).style?.color,
        CairnPalette.light.onBrand,
      );
      expect(find.byType(PeakCard), findsWidgets);

      await disposeApp(tester);
    });
  });

  group('a filter that admits nothing', () {
    testWidgets('says what would put something under Climbed', (tester) async {
      await pumpApp(tester, db);

      await tapFilter(tester, 'Climbed');

      expect(find.byType(PeakCard), findsNothing);
      expect(find.text('Nothing climbed yet'), findsOneWidget);
      expect(
        find.text(
          'Open a peak and mark it climbed. It shows up here after that.',
        ),
        findsOneWidget,
      );
      // The pills stay put. A screen that swallows the control that emptied it
      // has no way back.
      expect(find.text('All'), findsOneWidget);
      expect(find.text('To climb'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('reads an empty To climb list as the finish line', (
      tester,
    ) async {
      await climbEverything();
      await pumpApp(tester, db);

      await tapFilter(tester, 'To climb');

      expect(find.byType(PeakCard), findsNothing);
      expect(find.text('You have climbed them all'), findsOneWidget);
      expect(
        find.text('Every peak in your library is done. Nothing left to climb.'),
        findsOneWidget,
      );
      expect(progressCount('6 of 6 climbed'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('an empty library keeps its own message', (tester) async {
      for (final peak in await mountains.getAll()) {
        await mountains.removeById(peak.id);
      }

      await pumpApp(tester, db);

      // No progress to report and nothing to filter, so neither is drawn.
      expect(find.text('No peaks yet'), findsOneWidget);
      expect(find.text('All'), findsNothing);
      expect(progressCount('0 of 0 climbed'), findsNothing);

      await disposeApp(tester);
    });
  });

  testWidgets('all six peaks fit above the nav on a real phone', (
    tester,
  ) async {
    // The one the grid keeps losing. T13 put a third fact on the card and cost
    // the list its third row. T20 put a progress line and a row of pills above
    // the grid and cost it four peaks, until 5:3 and a 12dp footer bought them
    // back.
    //
    // The phone is the emulator this project ships against: 1080 by 2400 at
    // density 420, so 411 by 914 dp, insets top and bottom.
    //
    // The card height is computed rather than read off the tree, and that is
    // the load-bearing part of this test. The test font is a square-glyph
    // stand-in that is far wider than Manrope, so every peak name wraps here
    // and no card is the height a device draws. The photo is exact, the type
    // scale is exact, and a footer is two known lines inside known padding, so
    // the height is assembled from those instead. On the emulator this comes
    // out at 182dp against a measured 182.
    await pumpApp(
      tester,
      db,
      physicalSize: const Size(1080, 2400),
      devicePixelRatio: 2.625,
      padding: const FakeViewPadding(top: 63, bottom: 63),
    );

    final cards = find.byType(PeakCard);
    expect(cards, findsNWidgets(6), reason: 'all six are in the list');

    final navTop = tester.getRect(find.byType(PillNav)).top;
    final firstRowTop = tester.getRect(cards.at(0)).top;
    final photo = tester.getRect(
      find
          .descendant(of: cards.at(0), matching: find.byType(AspectRatio))
          .first,
    );

    expect(
      photo.width / photo.height,
      closeTo(CairnSize.peakPhotoAspect, 0.01),
      reason: 'the photo is the shape the token says it is',
    );
    expect(
      photo.height / photo.width,
      greaterThan(0.5),
      reason: 'a photo shallower than 2:1 has stopped being a photo',
    );

    double lineOf(TextStyle style) => style.fontSize! * style.height!;
    final footer =
        CairnSpace.x12 * 2 +
        lineOf(CairnType.screenTitle) +
        CairnSpace.x4 +
        lineOf(CairnType.meta);
    final card = photo.height + footer;
    final lastRowBottom = firstRowTop + 3 * card + 2 * CairnSpace.cardGap;

    expect(
      lastRowBottom,
      lessThan(navTop),
      reason:
          'the sixth peak has to be readable without scrolling, which is the '
          'whole reason this list is a two-column grid. It is over the nav by '
          '${(lastRowBottom - navTop).toStringAsFixed(1)}dp. Anything added '
          'above the grid, or any height added to the card, comes out of this.',
    );

    await disposeApp(tester);
  });
}
