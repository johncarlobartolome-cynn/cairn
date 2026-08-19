import 'dart:async';
import 'dart:io';

import 'package:cairn/app/router.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/photos/photo_filename.dart';
import 'package:cairn/data/providers.dart';
import 'package:cairn/features/climbs/climb_facts.dart';
import 'package:cairn/features/climbs/mark_climbed_sheet.dart';
import 'package:cairn/features/climbs/widgets/climb_photo.dart';
import 'package:cairn/features/climbs/widgets/climb_photo_field.dart';
import 'package:cairn/shared/widgets/cairn_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/photo_fixtures.dart';
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

  /// Stands in for the app documents directory, so a test can look at what the
  /// picker actually copied.
  late Directory documents;

  /// Where the system picker would have left its temporary files.
  late Directory picked;

  late FakePhotoPicker picker;

  /// The real store, with a valve on it. Every test gets one; the tests about a
  /// copy in flight are the only ones that close it.
  late HeldPhotoStore store;

  setUp(() {
    db = createTestDatabase();
    climbs = ClimbDao(db);
    mountains = MountainDao(db);
    documents = createTempDirectory('documents');
    picked = createTempDirectory('picked');
    picker = FakePhotoPicker();
    store = HeldPhotoStore(documents);
  });

  tearDown(() => db.close());

  Future<int> pulagId() async =>
      (await mountains.getAll()).firstWhere((p) => p.name == 'Mt. Pulag').id;

  /// A field found by the hint it is showing, which only works while it is
  /// empty. Fill them in the order they are asked for and it holds.
  Finder fieldWithHint(String hint) =>
      find.ancestor(of: find.text(hint), matching: find.byType(TextField));

  /// Opens peak detail and taps its primary action.
  ///
  /// [overrides] go on top of the photo ones every test here needs, for a test
  /// that also has to control when the write lands or whether it lands at all.
  Future<void> openSheet(
    WidgetTester tester,
    int mountainId, {
    List<Override> overrides = const <Override>[],
  }) async {
    await pumpApp(
      tester,
      db,
      location: CairnRoute.mountain(mountainId),
      overrides: <Override>[
        documentsDirectoryOverride(documents),
        photoPickerProvider.overrideWithValue(picker),
        photoStoreOverride(store),
        ...overrides,
      ],
    );
    await tester.tap(find.text('Mark climbed'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkClimbedSheet), findsOneWidget);
  }

  /// Taps Add photos and lets the copy finish.
  ///
  /// Copying is real disk work, which the fake clock a widget test runs on will
  /// not advance. `runAsync` puts the pumps back on the real one.
  Future<void> addPhotos(WidgetTester tester, List<String> names) async {
    picker.paths = <String>[
      for (final String name in names) writePickedFile(picked, name).path,
    ];

    await tester.tap(find.text(ClimbPhotoField.addLabel));
    await pumpRealAsync(tester);
  }

  /// The filenames sitting in the documents directory right now.
  List<String> filesOnDisk() => <String>[
    for (final FileSystemEntity entity in documents.listSync())
      entity.path.split(Platform.pathSeparator).last,
  ]..sort();

  /// The stored photos, ignoring the half-written file a copy builds beside the
  /// name it is claiming. That one starts with a dot and is gone as soon as the
  /// copy is whole, so counting it would make a test pass mid-write.
  List<String> photosOnDisk() =>
      filesOnDisk().where((String name) => !name.startsWith('.')).toList();

  /// The sheet's own save button. Peak detail has one behind it, so the finder
  /// has to say which of the two it means.
  CairnButton saveButton(WidgetTester tester) => tester.widget<CairnButton>(
    find.descendant(
      of: find.byType(MarkClimbedSheet),
      matching: find.byType(CairnButton),
    ),
  );

  /// Picks [names] with the store holding every copy, and returns once the first
  /// one is parked. The test decides when each lands from there.
  Future<void> startHeldPick(WidgetTester tester, List<String> names) async {
    store.holdCopies();
    picker.paths = <String>[
      for (final String name in names) writePickedFile(picked, name).path,
    ];
    await tester.tap(find.text(ClimbPhotoField.addLabel));
    await pumpRealUntil(
      tester,
      () => store.waiting == 1,
      waitingFor: 'the first copy to be parked',
    );
  }

  /// Returns once a climb row has landed in the file.
  Future<void> waitForTheSave(WidgetTester tester) => pumpRealUntil(
    tester,
    () async => (await climbs.getAll()).isNotEmpty,
    waitingFor: 'the climb to be written',
  );

  /// Lets fire-and-forget cleanup reach the disk before a test looks.
  Future<void> letCleanupFinish(WidgetTester tester) => pumpRealAsync(tester);

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

  testWidgets('says which badges the climb just earned', (tester) async {
    // The payoff. A first climb of a peak unlocks two badges and until T26 the
    // app mentioned neither, on the one screen the climber was already looking
    // at. Both are named here, by the names the badges grid uses.
    await openSheet(tester, await pulagId());
    await tapSave(tester);

    expect(
      find.text(
        'Climb saved. You earned two badges: Mt. Pulag and First climb.',
      ),
      findsOneWidget,
    );

    await disposeApp(tester);
  });

  testWidgets('says only that it saved when nothing was earned', (
    tester,
  ) async {
    // The second trip up the same peak. Both badges are already in the file, so
    // there is nothing to name and the acknowledgement goes back to two words.
    final id = await pulagId();

    await openSheet(tester, id);
    await tapSave(tester);
    await tester.pump(const Duration(seconds: 10));

    await tester.tap(find.text('Mark climbed'));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(find.text(climbSaved), findsOneWidget);

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

    expect(
      find.text(climbDayLabel(DateTime(day.year, day.month))),
      findsOneWidget,
    );

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

  testWidgets('asks for photos, and starts with none', (tester) async {
    await openSheet(tester, await pulagId());

    expect(find.text('PHOTOS'), findsOneWidget);
    expect(find.text(ClimbPhotoField.addLabel), findsOneWidget);
    expect(find.byType(ClimbPhoto), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('shows what was picked before anything is saved', (tester) async {
    await openSheet(tester, await pulagId());

    await addPhotos(tester, <String>['IMG_0431.jpg', 'IMG_0432.jpg']);

    expect(picker.openings, 1);
    expect(find.byType(ClimbPhoto), findsNWidgets(2));
    // The thumbnails are drawn from the copies, which is the same resolve path
    // climb detail uses. What you see here is what the app will find later.
    expect(filesOnDisk(), hasLength(2));
    for (final ClimbPhoto photo in tester.widgetList<ClimbPhoto>(
      find.byType(ClimbPhoto),
    )) {
      expect(isBarePhotoFilename(photo.filename), isTrue);
      expect(filesOnDisk(), contains(photo.filename));
    }

    await disposeApp(tester);
    await letCleanupFinish(tester);
  });

  testWidgets('one picked photo can be taken off again before saving', (
    tester,
  ) async {
    await openSheet(tester, await pulagId());
    await addPhotos(tester, <String>['IMG_0431.jpg', 'IMG_0432.jpg']);

    final String dropped = tester
        .widget<ClimbPhoto>(find.byType(ClimbPhoto).first)
        .filename;

    await tester.tap(find.byTooltip('Remove this photo').first);
    await letCleanupFinish(tester);

    expect(find.byType(ClimbPhoto), findsOneWidget);
    expect(
      tester.widget<ClimbPhoto>(find.byType(ClimbPhoto)).filename,
      isNot(dropped),
    );
    // The copy goes with it. Nothing points at it, so leaving it would be
    // litter that grows every time somebody changes their mind.
    expect(filesOnDisk(), isNot(contains(dropped)));
    expect(filesOnDisk(), hasLength(1));

    await disposeApp(tester);
    await letCleanupFinish(tester);
  });

  testWidgets('saves the filenames, and nothing that says where they live', (
    tester,
  ) async {
    final int id = await pulagId();

    await openSheet(tester, id);
    await addPhotos(tester, <String>['IMG_0431.jpg', 'IMG_0432.png']);
    await tapSave(tester);

    final Climb saved = (await climbs.getAll()).single;
    expect(saved.photoFilenames, hasLength(2));
    for (final String name in saved.photoFilenames) {
      expect(isBarePhotoFilename(name), isTrue, reason: name);
      expect(name, isNot(contains(Platform.pathSeparator)));
      expect(name, isNot(contains(documents.path)));
      expect(name, isNot(contains(picked.path)));
    }
    // The files themselves are where the names say they are.
    expect(filesOnDisk(), saved.photoFilenames.toList()..sort());

    await disposeApp(tester);
  });

  testWidgets('a saved climb keeps its photos on disk', (tester) async {
    await openSheet(tester, await pulagId());
    await addPhotos(tester, <String>['IMG_0431.jpg']);
    await tapSave(tester);
    await letCleanupFinish(tester);

    final Climb saved = (await climbs.getAll()).single;
    expect(filesOnDisk(), saved.photoFilenames);

    await disposeApp(tester);
  });

  testWidgets('a sheet closed without saving leaves nothing behind', (
    tester,
  ) async {
    // The cost of copying on the pick rather than on the save. Nothing points
    // at these files, so they go when the sheet does.
    await openSheet(tester, await pulagId());
    await addPhotos(tester, <String>['IMG_0431.jpg', 'IMG_0432.jpg']);
    expect(filesOnDisk(), hasLength(2));

    // The barrier above the sheet, which is how a sheet is dismissed.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await letCleanupFinish(tester);

    expect(find.byType(MarkClimbedSheet), findsNothing);
    expect(await climbs.getAll(), isEmpty);
    expect(filesOnDisk(), isEmpty);

    await disposeApp(tester);
  });

  testWidgets('the second sheet does not carry the first one\'s photos', (
    tester,
  ) async {
    await openSheet(tester, await pulagId());
    await addPhotos(tester, <String>['IMG_0431.jpg']);
    await tapSave(tester);

    await tester.tap(find.text('Mark climbed'));
    await tester.pumpAndSettle();

    expect(find.byType(ClimbPhoto), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('a picker that fails says so and leaves the sheet usable', (
    tester,
  ) async {
    await openSheet(tester, await pulagId());
    picker.failure = const FileSystemException('picker gave up');

    await tester.tap(find.text(ClimbPhotoField.addLabel));
    await letCleanupFinish(tester);

    expect(find.text(ClimbPhotoField.failureMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Save climb'), findsOneWidget);

    // And the climb still saves, with no photos on it.
    await tapSave(tester);
    expect((await climbs.getAll()).single.photoFilenames, isEmpty);

    await disposeApp(tester);
  });

  testWidgets('a save tapped while photos are still copying keeps every one', (
    tester,
  ) async {
    // The T30 bug, and the reason it went unseen: no test ever saved during a
    // pick. The draft published the list from before the pick until the last
    // copy landed, the save read that list, and a climb logged in that window
    // was written with no photos on it and said nothing about it.
    final int id = await pulagId();
    await openSheet(tester, id);

    store.holdCopies();
    picker.paths = <String>[
      for (final String name in <String>['a.jpg', 'b.jpg', 'c.jpg'])
        writePickedFile(picked, name).path,
    ];

    await tester.tap(find.text(ClimbPhotoField.addLabel));
    // No pump between the two taps, and that gap is the whole test. The save
    // button shows busy one frame after a pick starts, so this is the frame a
    // thumb beats it to: the tree this tap lands on is the idle one.
    await tester.tap(find.text('Save climb'));

    await pumpRealUntil(
      tester,
      () => store.waiting == 1,
      waitingFor: 'the first copy to be parked',
    );
    expect(find.byType(ClimbPhoto), findsNothing, reason: 'nothing has copied');

    store.letEverythingThrough();
    await waitForTheSave(tester);

    final Climb saved = (await climbs.getAll()).single;
    expect(saved.photoFilenames, hasLength(3));
    // And nothing was copied that the saved row does not name.
    expect(filesOnDisk(), saved.photoFilenames.toList()..sort());

    await tester.pumpAndSettle();
    await disposeApp(tester);
  });

  testWidgets('the photo row says it is working while copies land', (
    tester,
  ) async {
    // What the sheet was missing. The add row greys out during a pick and the
    // remove discs go dead, and nothing anywhere said why, so the app looked
    // idle while it was copying and Save was the natural next tap.
    await openSheet(tester, await pulagId());

    await startHeldPick(tester, <String>['a.jpg']);

    expect(find.text(ClimbPhotoField.workingMessage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ClimbPhotoField),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    store.letEverythingThrough();
    await pumpRealUntil(
      tester,
      () => find.byType(ClimbPhoto).evaluate().length == 1,
      waitingFor: 'the copy to land',
    );

    expect(find.text(ClimbPhotoField.workingMessage), findsNothing);

    await disposeApp(tester);
    await letCleanupFinish(tester);
  });

  testWidgets('a thumbnail arrives with each copy, not all at the end', (
    tester,
  ) async {
    await openSheet(tester, await pulagId());

    await startHeldPick(tester, <String>['a.jpg', 'b.jpg', 'c.jpg']);
    expect(find.byType(ClimbPhoto), findsNothing);

    // Two thumbnails while a third copy is still parked. Publishing one batch at
    // the end leaves the row empty for the whole pick, which is what this
    // catches.
    for (final int landed in <int>[1, 2]) {
      store.letOneThrough();
      await pumpRealUntil(
        tester,
        () => store.waiting == 1,
        waitingFor: 'copy ${landed + 1} to be parked',
      );
      expect(
        find.byType(ClimbPhoto),
        findsNWidgets(landed),
        reason: '$landed of three copies have landed',
      );
      expect(find.text(ClimbPhotoField.workingMessage), findsOneWidget);
    }

    store.letOneThrough();
    await pumpRealUntil(
      tester,
      () => find.text(ClimbPhotoField.workingMessage).evaluate().isEmpty,
      waitingFor: 'the last copy to land',
    );
    expect(find.byType(ClimbPhoto), findsNWidgets(3));

    await disposeApp(tester);
    await letCleanupFinish(tester);
  });

  testWidgets('the save button shows busy while photos are still copying', (
    tester,
  ) async {
    // So the tap the save now waits out is not wanted in the first place.
    await openSheet(tester, await pulagId());
    expect(saveButton(tester).busy, isFalse);

    await startHeldPick(tester, <String>['a.jpg']);
    expect(saveButton(tester).busy, isTrue);

    store.letEverythingThrough();
    await pumpRealUntil(
      tester,
      () => find.byType(ClimbPhoto).evaluate().length == 1,
      waitingFor: 'the copy to land',
    );
    expect(saveButton(tester).busy, isFalse);

    await disposeApp(tester);
    await letCleanupFinish(tester);
  });

  testWidgets('a pick that starts as the save does leaves nothing behind', (
    tester,
  ) async {
    // The other side of waiting. The photo row greys out one frame after the
    // save starts, so a pick can still get in, and its copy lands after the row
    // has been written with the photos that were there. Nothing can ever point
    // at that file, so it goes when the sheet does.
    await openSheet(tester, await pulagId());
    await addPhotos(tester, <String>['a.jpg']);

    store.holdCopies();
    picker.paths = <String>[writePickedFile(picked, 'late.jpg').path];

    await tester.tap(find.text('Save climb'));
    await tester.tap(find.text(ClimbPhotoField.addLabel));

    await waitForTheSave(tester);
    final Climb saved = (await climbs.getAll()).single;
    expect(
      saved.photoFilenames,
      hasLength(1),
      reason: 'the row holds what was attached when the save started',
    );

    // The sheet leaves with that second copy still parked.
    await tester.pumpAndSettle();
    expect(find.byType(MarkClimbedSheet), findsNothing);

    // So it lands with the sheet gone, the row written, and nothing anywhere
    // able to point at it. It clears up after itself.
    store.letEverythingThrough();
    await pumpRealUntil(
      tester,
      () => store.landed == 2,
      waitingFor: 'the late copy to land',
    );
    await pumpRealUntil(
      tester,
      () => photosOnDisk().length == 1,
      waitingFor: 'the late copy to be cleared up',
    );
    expect(photosOnDisk(), saved.photoFilenames);

    await disposeApp(tester);
  });

  testWidgets('two taps inside one frame log one climb, not two', (
    tester,
  ) async {
    // The T31 bug. The button only starts ignoring presses on the frame after
    // the first tap, and the save waits on the photo draft before it writes, so
    // both taps were through and past anything that could stop them.
    final int id = await pulagId();
    await openSheet(tester, id);

    // No pump between the two, and that gap is the whole test. The tree both of
    // these land on is the idle one.
    await tester.tap(find.text('Save climb'));
    await tester.tap(find.text('Save climb'));

    await waitForTheSave(tester);
    // Generous on purpose. A second row runs a moment behind the first, so
    // counting the instant the first one landed would find one row either way.
    await pumpRealAsync(tester);

    final List<Climb> rows = await climbs.getAll();
    expect(rows, hasLength(1));
    expect(rows.single.mountainId, id);

    // And one tap's worth of sheet was dismissed, on the save that landed.
    await tester.pumpAndSettle();
    expect(find.byType(MarkClimbedSheet), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('the tap that was refused says nothing about a failure', (
    tester,
  ) async {
    // Why the guard is not in the controller. Refusing there means answering the
    // second call with null, and null is what a failed write already returns, so
    // the sheet would put its failure line up over a climb that is saving fine.
    // The write is held open here, so the frame that would carry that lie is a
    // frame this test can look at.
    final _ControlledClimbDao writes = _ControlledClimbDao(db)..holdWrites();
    // Released whatever happens, including on a failed expectation below. A
    // write left parked never answers, and the save waiting on it would resume
    // inside whichever test ran next.
    addTearDown(writes.letEverythingThrough);

    await openSheet(
      tester,
      await pulagId(),
      overrides: <Override>[climbDaoProvider.overrideWithValue(writes)],
    );

    await tester.tap(find.text('Save climb'));
    await tester.tap(find.text('Save climb'));

    await pumpRealUntil(
      tester,
      () => writes.parked >= 1,
      waitingFor: 'the write to be parked',
    );
    await pumpRealAsync(tester);

    // Read while the write is held, asserted after it has been let go. An
    // expectation that failed with a write still parked would leave a save
    // waiting on an answer that never comes, and it resumes inside whichever
    // test runs next.
    final int callsWhileSaving = writes.calls;
    final bool sheetOpen = find.byType(MarkClimbedSheet).evaluate().isNotEmpty;
    final bool blamedTheSave = find
        .text(MarkClimbedSheet.saveFailedMessage)
        .evaluate()
        .isNotEmpty;

    // And the save the first tap started still lands.
    writes.letEverythingThrough();
    await waitForTheSave(tester);

    expect(callsWhileSaving, 1, reason: 'the second tap reached the write');
    expect(sheetOpen, isTrue);
    expect(
      blamedTheSave,
      isFalse,
      reason: 'the refused tap put a failure line over a save in flight',
    );
    expect(await climbs.getAll(), hasLength(1));

    await tester.pumpAndSettle();
    await disposeApp(tester);
  });

  testWidgets('a save that genuinely failed can be tapped again and lands', (
    tester,
  ) async {
    // The other half of a guard: it has to let go. One that latched would pass
    // every duplicate test above and leave the sheet holding what was typed
    // behind a button that does nothing.
    final int id = await pulagId();
    final _ControlledClimbDao writes = _ControlledClimbDao(db)
      ..refuseNextWrite = true;

    await openSheet(
      tester,
      id,
      overrides: <Override>[climbDaoProvider.overrideWithValue(writes)],
    );

    await tester.tap(find.text('Save climb'));
    await pumpRealAsync(tester);

    expect(find.text(MarkClimbedSheet.saveFailedMessage), findsOneWidget);
    expect(find.byType(MarkClimbedSheet), findsOneWidget);
    expect(await climbs.getAll(), isEmpty);

    // The same button, tapped again, with everything still in the sheet.
    await tester.tap(find.text('Save climb'));
    await pumpRealUntil(
      tester,
      () async => (await climbs.getAll()).isNotEmpty,
      waitingFor: 'the second attempt to be written',
    );

    expect(writes.calls, 2);
    expect((await climbs.getAll()).single.mountainId, id);

    await tester.pumpAndSettle();
    expect(find.byType(MarkClimbedSheet), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('two taps while photos are copying log one climb with every one', (
    tester,
  ) async {
    // T30 and T31 in the frame a real thumb hits: the pick is copying, neither
    // the photo row nor the button has been rebuilt busy yet, and the tap lands
    // twice. One row, and it holds all three photos.
    await openSheet(tester, await pulagId());

    store.holdCopies();
    picker.paths = <String>[
      for (final String name in <String>['a.jpg', 'b.jpg', 'c.jpg'])
        writePickedFile(picked, name).path,
    ];

    await tester.tap(find.text(ClimbPhotoField.addLabel));
    await tester.tap(find.text('Save climb'));
    await tester.tap(find.text('Save climb'));

    await pumpRealUntil(
      tester,
      () => store.waiting == 1,
      waitingFor: 'the first copy to be parked',
    );
    expect(find.byType(ClimbPhoto), findsNothing, reason: 'nothing has copied');

    store.letEverythingThrough();
    await waitForTheSave(tester);
    await pumpRealAsync(tester);

    final List<Climb> rows = await climbs.getAll();
    expect(rows, hasLength(1));
    expect(rows.single.photoFilenames, hasLength(3));
    // And nothing was copied that the one saved row does not name.
    expect(filesOnDisk(), rows.single.photoFilenames.toList()..sort());

    await tester.pumpAndSettle();
    await disposeApp(tester);
  });
}

/// The write path with a valve and a switch on it.
///
/// Two things the real DAO will not do on demand: hold a write open, so a test
/// can look at the sheet while one is in flight, and refuse one, so a test can
/// tap again afterwards. Anything it neither holds nor refuses goes to the real
/// query underneath.
class _ControlledClimbDao extends ClimbDao {
  _ControlledClimbDao(super.db);

  /// One per write parked at the gate.
  final List<Completer<void>> _gates = <Completer<void>>[];

  bool _holding = false;

  /// The next write throws instead of landing, once.
  bool refuseNextWrite = false;

  /// How many times a write was asked for, whether it landed or not.
  ///
  /// The sharp assertion about a double tap. Rows can be counted a moment too
  /// early, but a call that was never made cannot turn up later.
  int calls = 0;

  /// How many writes are parked right now.
  int get parked => _gates.length;

  /// Writes wait from here on, rather than going to the file.
  void holdWrites() => _holding = true;

  /// Lets every write land: the ones parked now and the ones still to come.
  void letEverythingThrough() {
    _holding = false;
    final List<Completer<void>> waiting = List<Completer<void>>.of(_gates);
    _gates.clear();
    for (final Completer<void> gate in waiting) {
      if (!gate.isCompleted) gate.complete();
    }
  }

  @override
  Future<ClimbLogged> logClimb({
    required int mountainId,
    required DateTime date,
    String? companions,
    String? notes,
    List<String> photoFilenames = const <String>[],
    DateTime? unlockedAt,
  }) async {
    calls++;

    if (_holding) {
      final Completer<void> gate = Completer<void>();
      _gates.add(gate);
      await gate.future;
    }

    if (refuseNextWrite) {
      refuseNextWrite = false;
      throw const _WriteRefused();
    }

    return super.logClimb(
      mountainId: mountainId,
      date: date,
      companions: companions,
      notes: notes,
      photoFilenames: photoFilenames,
      unlockedAt: unlockedAt,
    );
  }
}

/// Thrown by [_ControlledClimbDao] in place of a write, so a refusal a test
/// asked for reads differently from one it did not.
class _WriteRefused implements Exception {
  const _WriteRefused();

  @override
  String toString() => 'the test refused this write';
}
