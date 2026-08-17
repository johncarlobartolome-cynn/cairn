import 'dart:io';

import 'package:cairn/app/router.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/features/climbs/climb_facts.dart';
import 'package:cairn/features/climbs/widgets/climb_photo.dart';
import 'package:cairn/features/climbs/widgets/climb_photo_strip.dart';
import 'package:cairn/features/climbs/widgets/missing_photo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/photo_fixtures.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// Climb detail with photographs on it.
///
/// The screen had a found branch from T5 and rows from T15. This is the pass
/// that puts pictures on it, and the assertion that matters most is the one
/// about a photo that is no longer there: a missing file must cost one frame,
/// not the whole screen.
void main() {
  late AppDatabase db;
  late ClimbDao climbs;
  late MountainDao mountains;
  late Directory documents;

  setUp(() {
    db = createTestDatabase();
    climbs = ClimbDao(db);
    mountains = MountainDao(db);
    documents = createTempDirectory('documents');
  });

  tearDown(() => db.close());

  final DateTime day = DateTime(2026, 8, 11);

  Future<int> pulagId() async =>
      (await mountains.getAll()).firstWhere((p) => p.name == 'Mt. Pulag').id;

  /// One climb with [photoFilenames] against it. The files themselves are
  /// written separately, so a test can log a climb whose photos are missing.
  Future<int> logClimb({
    List<String> photoFilenames = const <String>[],
    String? companions,
    String? notes,
  }) async => (await climbs.logClimb(
    mountainId: await pulagId(),
    date: day,
    companions: companions,
    notes: notes,
    photoFilenames: photoFilenames,
  )).id;

  /// Opens `/climb/:id` against a documents directory the test controls, and
  /// gives the image loader the real clock it needs to reach a file.
  Future<void> openClimb(WidgetTester tester, int id) async {
    await pumpApp(
      tester,
      db,
      location: CairnRoute.climb(id),
      overrides: <Override>[documentsDirectoryOverride(documents)],
    );
    await pumpRealAsync(tester);
  }

  testWidgets('shows one photo per stored filename', (tester) async {
    const names = <String>[
      'climb_1755300000000001_a1b2c3d4.jpg',
      'climb_1755300000000002_e5f6a7b8.jpg',
      'climb_1755300000000003_c9d0e1f2.jpg',
    ];
    for (final String name in names) {
      writePickedFile(documents, name);
    }

    await openClimb(tester, await logClimb(photoFilenames: names));

    expect(
      tester.widget<ClimbPhotoStrip>(find.byType(ClimbPhotoStrip)).filenames,
      names,
    );
    // One card at a time, first one first. The rest are a swipe away rather
    // than built off screen, which is the list doing its job.
    expect(
      tester.widget<ClimbPhoto>(find.byType(ClimbPhoto).first).filename,
      names.first,
    );

    await tester.drag(find.byType(ClimbPhotoStrip), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(
      tester.widget<ClimbPhoto>(find.byType(ClimbPhoto).first).filename,
      isNot(names.first),
    );

    await disposeApp(tester);
  });

  testWidgets('a climb with no photos shows no photo block at all', (
    tester,
  ) async {
    // An empty frame reads as a photo that failed. A climb with no photos has
    // nothing to say about photos.
    await openClimb(tester, await logClimb());

    expect(find.byType(ClimbPhotoStrip), findsNothing);
    expect(find.byType(ClimbPhoto), findsNothing);
    expect(find.text(climbDayLabel(day)), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('the photos open the screen, above the day', (tester) async {
    const name = 'climb_1755300000000001_a1b2c3d4.jpg';
    writePickedFile(documents, name);

    await openClimb(
      tester,
      await logClimb(photoFilenames: const <String>[name]),
    );

    expect(
      tester.getTopLeft(find.byType(ClimbPhotoStrip)).dy,
      lessThan(tester.getTopLeft(find.text(climbDayLabel(day))).dy),
    );

    await disposeApp(tester);
  });

  testWidgets('a photo deleted behind the app still opens the climb', (
    tester,
  ) async {
    // The failure this ticket is really about, staged: the row names a file
    // that is not on disk. The screen has to stay open, with everything else
    // on it, and say what happened in the one frame the photo was in.
    const names = <String>[
      'climb_1755300000000001_a1b2c3d4.jpg',
      'climb_1755300000000002_e5f6a7b8.jpg',
    ];
    writePickedFile(documents, names.last);

    await openClimb(
      tester,
      await logClimb(
        photoFilenames: names,
        companions: 'Mara and Enzo',
        notes: 'Sea of clouds at sunrise.',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(MissingPhoto), findsWidgets);
    // The rest of the climb is untouched by the missing file.
    expect(find.text(climbDayLabel(day)), findsOneWidget);
    expect(find.text('Mara and Enzo'), findsOneWidget);
    expect(find.text('Sea of clouds at sunrise.'), findsOneWidget);
    expect(find.text('Climb not found'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('every photo missing is still a climb you can read', (
    tester,
  ) async {
    await openClimb(
      tester,
      await logClimb(
        photoFilenames: const <String>[
          'climb_1755300000000001_a1b2c3d4.jpg',
          'climb_1755300000000002_e5f6a7b8.jpg',
        ],
        notes: 'Sea of clouds at sunrise.',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(climbDayLabel(day)), findsOneWidget);
    expect(find.text('Sea of clouds at sunrise.'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('the photo block is the same height however many there are', (
    tester,
  ) async {
    // Sideways rather than stacked, so the day and the notes sit in the same
    // place whether the climb carries one photo or nine.
    writePickedFile(documents, 'climb_1755300000000001_a1b2c3d4.jpg');
    final int one = await logClimb(
      photoFilenames: const <String>['climb_1755300000000001_a1b2c3d4.jpg'],
    );

    await openClimb(tester, one);
    final double singleDay = tester
        .getTopLeft(find.text(climbDayLabel(day)))
        .dy;
    await disposeApp(tester);

    final int many = (await climbs.logClimb(
      mountainId: await pulagId(),
      date: day,
      photoFilenames: const <String>[
        'climb_1755300000000001_a1b2c3d4.jpg',
        'climb_1755300000000002_e5f6a7b8.jpg',
        'climb_1755300000000003_c9d0e1f2.jpg',
      ],
    )).id;

    await openClimb(tester, many);
    expect(tester.getTopLeft(find.text(climbDayLabel(day))).dy, singleDay);

    await disposeApp(tester);
  });
}
