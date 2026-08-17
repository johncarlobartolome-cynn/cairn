// Runs on a device through `flutter drive`, never under `flutter test`:
//
//   CAIRN_SCREENSHOT_DIR=<dir> flutter drive --device-id emulator-5554 \
//     --keep-app-running --driver test_driver/integration_test.dart \
//     --target integration_test/t26_edge_case_screenshot_test.dart
//
// The states nobody had tried. `tool/screenshots.sh` photographs the app as it
// ships, six seeded peaks and whatever is logged on the device; this
// photographs the shapes the library can take once somebody adds a peak of
// their own. A name longer than any of the six. A peak climbed fourteen times.
// A climb carrying nine photographs. A library of one, and a library of
// twenty-one. A peak with nothing but a name.
//
// It also photographs the acknowledgement, because a sentence that names a badge
// has to be read on the device somebody will read it on.
//
// **Every shot builds its own library, once per theme.** Nothing is shared: the
// two acknowledgement shots each need a peak nobody has climbed, and a database
// carried from the light pass into the dark one would have the badge already
// unlocked and nothing left to say. It is all in memory, so the emulator's own
// `cairn.sqlite` is neither read nor written. See t26_fixture.dart.

import 'package:cairn/app/app.dart';
import 'package:cairn/app/router.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/database/tables/mountains.dart' show Difficulty;
import 'package:cairn/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'painted_photo_picker.dart';
import 't26_fixture.dart';

/// A name longer than any of the six, in the shape a real one takes: a peak
/// named by its traverse rather than by its summit.
const String longName =
    'Mt. Guiting-Guiting Traverse from Magdiwang to San Fernando';

/// A library and the route to open it on.
typedef Fixture = ({AppDatabase db, String location});

/// How long a route gets to leave its loading spinner behind.
const Duration _renderBudget = Duration(seconds: 20);
const Duration _pumpStep = Duration(milliseconds: 100);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the edge cases, in both themes', (tester) async {
    // Android draws Flutter into a surface the framework cannot read back. This
    // swaps it for an image view for the rest of the test, and it asserts if
    // called twice, so every shot shares one test.
    await binding.convertFlutterSurfaceToImage();

    /// Builds [fixture], opens the app on it and photographs it, once per theme,
    /// with [prepare] run after the route has settled.
    Future<void> shoot(
      String name, {
      required Future<Fixture> Function() fixture,
      Future<void> Function(WidgetTester tester)? prepare,
    }) async {
      for (final MapEntry<String, ThemeMode> theme in const <String, ThemeMode>{
        'light': ThemeMode.light,
        'dark': ThemeMode.dark,
      }.entries) {
        final Fixture built = await fixture();
        final container = ProviderContainer(
          overrides: <Override>[databaseProvider.overrideWithValue(built.db)],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            // A fresh key per shot: CairnApp builds its router once, so reusing
            // one would keep the first location for every shot after it.
            child: CairnApp(
              key: ValueKey<String>('$name-${theme.key}'),
              initialLocation: built.location,
              themeMode: theme.value,
            ),
          ),
        );

        await _waitUntilRendered(tester, '$name-${theme.key}', built.location);
        await prepare?.call(tester);
        await binding.takeScreenshot('t26-$name-${theme.key}');

        // Both go with the shot rather than with the run, so nothing one shot
        // did can reach the next one.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(_pumpStep);
        container.dispose();
        await built.db.close();
      }
    }

    /// Taps through the sheet and saves, leaving the acknowledgement on screen.
    Future<void> saveAClimb(WidgetTester tester) async {
      await tester.tap(find.text('Mark climbed'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save climb'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save climb'));
      await tester.pumpAndSettle();
    }

    // ---- The acknowledgement, on the device it will be read on ----
    //
    // A first climb, so two badges fire and the sentence names both. Driven
    // through the sheet rather than written into the file, because the shot is of
    // what the app says after a save and only a save can say it.
    await shoot(
      'earned-badges',
      fixture: () async {
        final AppDatabase db = fixtureDatabase();
        final int first = (await MountainDao(db).getAll()).first.id;
        return (db: db, location: CairnRoute.mountain(first));
      },
      prepare: (tester) async {
        await saveAClimb(tester);
        expect(find.textContaining('two badges'), findsOneWidget);
      },
    );

    // ---- A name longer than any of the six ----
    Future<Fixture> longNamed(String Function(int id) route) => (() async {
      final AppDatabase db = fixtureDatabase();
      final int id = await addPeak(
        db,
        name: longName,
        region: 'Romblon',
        elevationM: 2058,
        difficulty: Difficulty.hard,
        jumpOffPoint:
            'Brgy. Magdiwang, Sibuyan Island. Register at the DENR office '
            'before the climb.',
        estimatedHours: 9,
      );
      await ClimbDao(db).logClimb(
        mountainId: id,
        date: DateTime.utc(2026, 8, 12),
        companions: 'Mara and Enzo',
      );
      return (db: db, location: route(id));
    })();

    await shoot(
      'long-name-list',
      fixture: () => longNamed((_) => CairnRoute.peaks),
    );
    await shoot(
      'long-name-detail',
      fixture: () => longNamed(CairnRoute.mountain),
    );
    await shoot(
      'long-name-badges',
      fixture: () => longNamed((_) => CairnRoute.badges),
      // A badge tile is the narrowest container a peak's name ever lands in, and
      // the long one is the last tile in the grid, so the shot has to scroll to
      // it. Photographing the top of this screen would prove nothing.
      prepare: (tester) async {
        await tester.dragUntilVisible(
          find.text(longName),
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
      },
    );

    // ---- A peak with a long history ----
    await shoot(
      'many-climbs',
      fixture: () async {
        final AppDatabase db = fixtureDatabase();
        final int peak = (await MountainDao(db).getAll()).first.id;
        for (var day = 1; day <= 14; day++) {
          await ClimbDao(db).logClimb(
            mountainId: peak,
            date: DateTime.utc(2026, 7, day),
            companions: day.isEven ? 'Mara, Enzo, Kim, Paolo and Bea' : null,
            notes: day.isOdd ? 'Sea of clouds at sunrise.' : null,
          );
        }
        return (db: db, location: CairnRoute.mountain(peak));
      },
    );

    // ---- A climb carrying nine photographs ----
    //
    // Real files, copied in through the app's own store, so the strip draws what
    // climb detail would draw off a real pick. Copied once and reused by both
    // themes: the files outlive each fixture, only the rows are rebuilt.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final PhotoStore store = container.read(photoStoreProvider);
    final List<String> stored = <String>[
      for (final String path in await PaintedPhotoPicker(9).pick())
        await store.copyIn(path),
    ];
    addTearDown(() => store.removeAll(stored));

    await shoot(
      'many-photos',
      // Nine files to read and decode. The spinner rule the other shots wait on
      // does not cover this: a photo still resolving draws a plain surfaceAlt
      // fill by design, which on cream is invisible, so a shot taken too early
      // looks like a strip that failed rather than one that had not arrived.
      prepare: (tester) async {
        for (var frame = 0; frame < 25; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
      fixture: () async {
        final AppDatabase db = fixtureDatabase();
        final int peak = (await MountainDao(db).getAll()).first.id;
        final int climb = (await ClimbDao(db).logClimb(
          mountainId: peak,
          date: DateTime.utc(2026, 8, 9),
          companions: 'Mara and Enzo',
          notes: 'Nine photographs, because the light kept changing.',
          photoFilenames: stored,
        )).id;
        return (db: db, location: CairnRoute.climb(climb));
      },
    );

    // ---- A library of one ----
    Future<({AppDatabase db, int peak})> onePeak() async {
      final AppDatabase db = fixtureDatabase();
      await clearLibrary(db);
      final int only = await addPeak(
        db,
        name: 'Mt. Talamitam',
        region: 'Batangas',
        elevationM: 630,
        difficulty: Difficulty.easy,
        jumpOffPoint: 'Brgy. Bayudbud, Nasugbu.',
        estimatedHours: 2,
      );
      return (db: db, peak: only);
    }

    await shoot(
      'one-peak',
      fixture: () async {
        final built = await onePeak();
        return (db: built.db, location: CairnRoute.peaks);
      },
    );
    await shoot(
      'one-peak-badges',
      fixture: () async {
        final built = await onePeak();
        return (db: built.db, location: CairnRoute.badges);
      },
    );

    // A first climb of a one-peak library earns three badges at once, which is
    // the loudest the acknowledgement ever gets.
    await shoot(
      'one-peak-earned',
      fixture: () async {
        final built = await onePeak();
        return (db: built.db, location: CairnRoute.mountain(built.peak));
      },
      prepare: (tester) async {
        await saveAClimb(tester);
        expect(find.textContaining('three badges'), findsOneWidget);
      },
    );

    // ---- A library of twenty-one ----
    Future<AppDatabase> crowded() async {
      final AppDatabase db = fixtureDatabase();
      for (var i = 1; i <= 15; i++) {
        await addPeak(
          db,
          name: 'Mt. Added $i',
          elevationM: 400 + i * 37,
          difficulty: Difficulty.values[i % Difficulty.values.length],
        );
      }
      for (final Mountain peak in (await MountainDao(db).getAll()).take(7)) {
        await ClimbDao(db).logClimb(
          mountainId: peak.id,
          date: DateTime.utc(2026, 6, 1 + peak.id % 27),
        );
      }
      return db;
    }

    await shoot(
      'many-peaks',
      fixture: () async => (db: await crowded(), location: CairnRoute.peaks),
    );
    await shoot(
      'many-peaks-badges',
      fixture: () async => (db: await crowded(), location: CairnRoute.badges),
    );

    // ---- A peak with nothing but a name ----
    Future<({AppDatabase db, int peak})> nameOnly() async {
      final AppDatabase db = fixtureDatabase();
      final int bare = await addPeak(db, name: 'Mt. Nameless');
      return (db: db, peak: bare);
    }

    await shoot(
      'bare-peak',
      fixture: () async {
        final built = await nameOnly();
        return (db: built.db, location: CairnRoute.mountain(built.peak));
      },
    );
    await shoot(
      'bare-peak-list',
      fixture: () async {
        final built = await nameOnly();
        return (db: built.db, location: CairnRoute.peaks);
      },
    );
  });
}

/// Pumps until the route is done loading, or fails saying which shot hung.
Future<void> _waitUntilRendered(
  WidgetTester tester,
  String name,
  String location,
) async {
  final Finder spinner = find.byType(CircularProgressIndicator);
  final Stopwatch clock = Stopwatch()..start();

  while (clock.elapsed < _renderBudget) {
    await tester.pump(_pumpStep);

    final Object? error = tester.takeException();
    if (error != null) {
      throw StateError('$location threw while building $name: $error');
    }

    if (spinner.evaluate().isEmpty) {
      // Two more frames, so the image is of a settled screen.
      await tester.pump(_pumpStep);
      await tester.pump(_pumpStep);
      return;
    }
  }

  throw StateError(
    '$location was still loading after ${_renderBudget.inSeconds}s, '
    'so $name.png would have been a spinner.',
  );
}
