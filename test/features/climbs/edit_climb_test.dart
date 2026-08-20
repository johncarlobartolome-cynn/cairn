import 'dart:async';
import 'dart:io';

import 'package:cairn/app/router.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/providers.dart';
import 'package:cairn/features/climbs/climb_facts.dart';
import 'package:cairn/features/climbs/mark_climbed_sheet.dart';
import 'package:cairn/features/climbs/widgets/climb_photo.dart';
import 'package:cairn/features/climbs/widgets/climb_photo_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/photo_fixtures.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// Finishing a climb later, driven the way a person drives it: open the climb,
/// tap the pencil, add what was missing, save.
///
/// The gap Jeysi found on his own phone. A climb logged on the trail with only a
/// date drew one line and there was nothing on the screen to act on, because
/// `ClimbDao` had no way to write to a row that already existed.
void main() {
  late AppDatabase db;
  late ClimbDao climbs;
  late MountainDao mountains;

  /// Stands in for the app documents directory, so a test can look at what
  /// survived an edit and what did not.
  late Directory documents;

  /// Where the system picker would have left its temporary files.
  late Directory picked;

  late FakePhotoPicker picker;
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

  /// A day well in the past, so the picker's range always holds it.
  final DateTime day = DateTime(2024, 3, 9);

  Future<int> pulagId() async =>
      (await mountains.getAll()).firstWhere((p) => p.name == 'Mt. Pulag').id;

  /// One saved climb, with as much or as little on it as the test needs.
  ///
  /// It goes in through [ClimbDao.logClimb], badges and all, which is what makes
  /// the acknowledgement test worth anything: the peak badge and First climb are
  /// already in the file before the edit starts.
  Future<int> logClimb({
    DateTime? on,
    String? companions,
    String? notes,
    List<String> photoFilenames = const <String>[],
  }) async => (await climbs.logClimb(
    mountainId: await pulagId(),
    date: on ?? day,
    companions: companions,
    notes: notes,
    photoFilenames: photoFilenames,
  )).id;

  Future<Climb> readBack(int id) async =>
      (await climbs.getAll()).firstWhere((c) => c.id == id);

  /// A photo already on disk under a name the column will accept.
  String storedPhoto(String stamp) {
    final String name = 'climb_${stamp}_a1b2c3d4.jpg';
    writePickedFile(documents, name);
    return name;
  }

  /// The stored photos, ignoring the half-written file a copy builds beside the
  /// name it is claiming.
  List<String> photosOnDisk() => <String>[
    for (final FileSystemEntity entity in documents.listSync())
      entity.path.split(Platform.pathSeparator).last,
  ].where((String name) => !name.startsWith('.')).toList()..sort();

  /// Opens `/climb/:id` and taps the pencil in the bar.
  Future<void> openEdit(
    WidgetTester tester,
    int climbId, {
    List<Override> overrides = const <Override>[],
  }) async {
    await pumpApp(
      tester,
      db,
      location: CairnRoute.climb(climbId),
      overrides: <Override>[
        documentsDirectoryOverride(documents),
        photoPickerProvider.overrideWithValue(picker),
        photoStoreOverride(store),
        ...overrides,
      ],
    );
    await pumpRealAsync(tester);

    await tester.tap(find.byTooltip('Edit this climb'));
    await tester.pumpAndSettle();
    await pumpRealAsync(tester);

    expect(find.byType(MarkClimbedSheet), findsOneWidget);
  }

  /// Anything inside the sheet, so a finder cannot pick up the climb detail
  /// screen sitting behind it. Both draw a day and both draw photographs.
  Finder inSheet(Finder matching) =>
      find.descendant(of: find.byType(MarkClimbedSheet), matching: matching);

  Finder sheetPhotos() => inSheet(find.byType(ClimbPhoto));

  Future<void> tapSaveChanges(WidgetTester tester) async {
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
  }

  /// Dismisses the sheet by tapping the barrier above it, which is how somebody
  /// abandons an edit.
  Future<void> cancel(WidgetTester tester) async {
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await pumpRealAsync(tester);
  }

  testWidgets('climb detail carries the way in', (tester) async {
    await pumpApp(
      tester,
      db,
      location: CairnRoute.climb(await logClimb()),
      overrides: <Override>[documentsDirectoryOverride(documents)],
    );

    expect(find.byTooltip('Edit this climb'), findsOneWidget);
    expect(find.byType(MarkClimbedSheet), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('the sheet opens on what the climb already says', (tester) async {
    final String photo = storedPhoto('1755300000000001');
    final int id = await logClimb(
      companions: 'Mara and Enzo',
      notes: 'Sea of clouds at sunrise.',
      photoFilenames: <String>[photo],
    );

    await openEdit(tester, id);

    // Its own words, not the save sheet's. A form that said "Mark climbed" over
    // a climb already in the log would be asking for a second one.
    expect(find.text('Edit climb'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Mark climbed'), findsNothing);

    // The climb's own day, rather than today.
    expect(inSheet(find.text(climbDayLabel(day))), findsOneWidget);
    expect(inSheet(find.text('Mara and Enzo')), findsOneWidget);
    expect(inSheet(find.text('Sea of clouds at sunrise.')), findsOneWidget);
    expect(sheetPhotos(), findsOneWidget);
    expect(tester.widget<ClimbPhoto>(sheetPhotos()).filename, photo);

    await disposeApp(tester);
  });

  testWidgets('an edit writes the companions and the notes', (tester) async {
    final int id = await logClimb();

    await openEdit(tester, id);

    // By position rather than by hint. The hint only shows on an empty field,
    // and the whole point of an edit is that they usually are not.
    await tester.enterText(
      inSheet(find.byType(TextField)).first,
      'Mara and Enzo',
    );
    await tester.enterText(
      inSheet(find.byType(TextField)).at(1),
      'Sea of clouds at sunrise.',
    );
    await tester.pump();

    await tapSaveChanges(tester);

    expect(find.byType(MarkClimbedSheet), findsNothing);
    final Climb after = await readBack(id);
    expect(after.companions, 'Mara and Enzo');
    expect(after.notes, 'Sea of clouds at sunrise.');
    // The day is untouched by an edit that did not go near it.
    expect(after.date, DateTime.utc(day.year, day.month, day.day));

    await disposeApp(tester);
  });

  testWidgets('an edit moves the day the picker was given', (tester) async {
    final int id = await logClimb();

    await openEdit(tester, id);

    await tester.tap(inSheet(find.text(climbDayLabel(day))));
    await tester.pumpAndSettle();
    // The first of the month the climb is already in, which is always on or
    // before today and always inside the picker's range.
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tapSaveChanges(tester);

    expect(
      (await readBack(id)).date,
      DateTime.utc(day.year, day.month),
      reason: 'a climb is a calendar day, and stays one through an edit',
    );

    await disposeApp(tester);
  });

  testWidgets('an edit says it saved and names no badge', (tester) async {
    // The peak badge and First climb were both earned when this climb was
    // logged. An edit cannot earn one, so naming either here would congratulate
    // somebody for last week and make the sentence worthless on the climb that
    // does earn something.
    final int id = await logClimb();

    await openEdit(tester, id);
    await tester.enterText(
      inSheet(find.byType(TextField)).at(1),
      'Filled in at home.',
    );
    await tester.pump();
    await tapSaveChanges(tester);

    expect(find.text(climbUpdated), findsOneWidget);
    expect(find.textContaining('You earned'), findsNothing);
    expect(find.textContaining('Mt. Pulag'), findsNothing);
    expect((await readBack(id)).notes, 'Filled in at home.');

    await disposeApp(tester);
  });

  testWidgets('a photo added during an edit is attached to the climb', (
    tester,
  ) async {
    final String had = storedPhoto('1755300000000001');
    final int id = await logClimb(photoFilenames: <String>[had]);

    await openEdit(tester, id);

    picker.paths = <String>[writePickedFile(picked, 'IMG_0431.jpg').path];
    await tester.tap(find.text(ClimbPhotoField.addLabel));
    await pumpRealAsync(tester);

    expect(sheetPhotos(), findsNWidgets(2));

    await tapSaveChanges(tester);
    await pumpRealAsync(tester);

    final Climb after = await readBack(id);
    expect(after.photoFilenames, hasLength(2));
    expect(after.photoFilenames.first, had);
    // Both files are where the names say they are, and nothing else is left.
    expect(photosOnDisk(), after.photoFilenames.toList()..sort());

    await disposeApp(tester);
  });

  testWidgets('a photo taken off goes only once the edit is saved', (
    tester,
  ) async {
    // The riskiest part of the ticket. T30's cleanup deletes a copy the moment
    // it is taken off the sheet, which is right for a row that does not exist
    // yet and is data loss on a row that does.
    final String first = storedPhoto('1755300000000001');
    final String second = storedPhoto('1755300000000002');
    final int id = await logClimb(photoFilenames: <String>[first, second]);

    await openEdit(tester, id);
    expect(sheetPhotos(), findsNWidgets(2));

    await tester.tap(find.byTooltip('Remove this photo').first);
    await pumpRealAsync(tester);

    expect(sheetPhotos(), findsOneWidget);
    expect(
      photosOnDisk(),
      <String>[first, second],
      reason: 'the climb still names it, so the file cannot go yet',
    );

    await tapSaveChanges(tester);
    await pumpRealUntil(
      tester,
      () => photosOnDisk().length == 1,
      waitingFor: 'the photo the edit dropped to be deleted',
    );

    final Climb after = await readBack(id);
    expect(after.photoFilenames, <String>[second]);
    expect(photosOnDisk(), <String>[second]);

    await disposeApp(tester);
  });

  testWidgets('a cancelled edit leaves the row and every file alone', (
    tester,
  ) async {
    // Two photographs on the climb, and the sheet does something different to
    // each of them, because a cancel has to be harmless in both directions. One
    // is taken off, so the file must survive a deletion that never earned its
    // trigger. One is left alone, so it must survive the cleanup that clears up
    // after an abandoned sheet.
    final String dropped = storedPhoto('1755300000000001');
    final String left = storedPhoto('1755300000000002');
    final int id = await logClimb(
      companions: 'Mara and Enzo',
      notes: 'Sea of clouds at sunrise.',
      photoFilenames: <String>[dropped, left],
    );

    await openEdit(tester, id);

    // Everything changed, and then thrown away: a field retyped, one of the
    // climb's own photographs taken off, and another one picked.
    await tester.enterText(
      inSheet(find.byType(TextField)).first,
      'Nobody, actually',
    );
    await tester.tap(find.byTooltip('Remove this photo').first);
    await pumpRealAsync(tester);

    picker.paths = <String>[writePickedFile(picked, 'IMG_0431.jpg').path];
    await tester.tap(find.text(ClimbPhotoField.addLabel));
    await pumpRealAsync(tester);
    expect(photosOnDisk(), hasLength(3));

    await cancel(tester);

    expect(find.byType(MarkClimbedSheet), findsNothing);
    final Climb after = await readBack(id);
    expect(after.companions, 'Mara and Enzo');
    expect(after.notes, 'Sea of clouds at sunrise.');
    expect(after.photoFilenames, <String>[dropped, left]);
    // Both of the climb's photographs are still there, and the one nobody
    // saved is not.
    expect(photosOnDisk(), <String>[dropped, left]..sort());

    await disposeApp(tester);
  });

  testWidgets('an edit that failed says so and loses nothing', (tester) async {
    final int id = await logClimb(notes: 'Sea of clouds at sunrise.');
    final _ControlledClimbDao writes = _ControlledClimbDao(db)
      ..refuseNextUpdate = true;

    await openEdit(
      tester,
      id,
      overrides: <Override>[climbDaoProvider.overrideWithValue(writes)],
    );

    await tester.enterText(
      inSheet(find.byType(TextField)).at(1),
      'Rewritten at home.',
    );
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await pumpRealAsync(tester);

    // A line that says changes rather than climb: the climb is still in the log
    // exactly as it was, and saying it did not save would read as losing it.
    expect(find.text(MarkClimbedSheet.editFailedMessage), findsOneWidget);
    expect(find.byType(MarkClimbedSheet), findsOneWidget);
    expect((await readBack(id)).notes, 'Sea of clouds at sunrise.');
    // And what was typed is still in the sheet, behind a button that works.
    expect(inSheet(find.text('Rewritten at home.')), findsOneWidget);

    await tester.tap(find.text('Save changes'));
    await pumpRealUntil(
      tester,
      () async => (await readBack(id)).notes == 'Rewritten at home.',
      waitingFor: 'the second attempt to be written',
    );

    expect(writes.updates, 2);

    await tester.pumpAndSettle();
    await disposeApp(tester);
  });

  testWidgets('two taps inside one frame write one update, not two', (
    tester,
  ) async {
    // T31 and T32 on the new save. The button only starts ignoring presses on
    // the frame after the first tap, and the write waits on the photo draft
    // before it goes, so both taps used to be through and past anything that
    // could stop them.
    final int id = await logClimb();
    // Held open, and that is what makes the second tap mean anything. An UPDATE
    // against an in-memory database can finish between two taps with no frame
    // in between, and the sheet is already on its way out by the time the
    // second one is aimed, so it lands on the barrier and proves nothing.
    final _ControlledClimbDao writes = _ControlledClimbDao(db)..holdWrites();
    // Released whatever happens, including on a failed expectation below. A
    // write left parked never answers, and the save waiting on it would resume
    // inside whichever test ran next.
    addTearDown(writes.letEverythingThrough);

    await openEdit(
      tester,
      id,
      overrides: <Override>[climbDaoProvider.overrideWithValue(writes)],
    );

    await tester.enterText(
      inSheet(find.byType(TextField)).at(1),
      'Filled in at home.',
    );
    await tester.pump();

    // No pump between the two, and that gap is the whole test. The tree both of
    // these land on is the idle one.
    await tester.tap(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));

    await pumpRealUntil(
      tester,
      () => writes.parked >= 1,
      waitingFor: 'the write to be parked',
    );
    await pumpRealAsync(tester);

    // Read while the write is held, asserted after it has been let go. An
    // expectation that failed with a write still parked would leave a save
    // waiting on an answer that never comes.
    final int callsWhileSaving = writes.updates;

    writes.letEverythingThrough();
    await pumpRealUntil(
      tester,
      () async => (await readBack(id)).notes == 'Filled in at home.',
      waitingFor: 'the edit to be written',
    );
    // Generous on purpose. A second write runs a moment behind the first, so
    // counting the instant the first one landed would find one either way.
    await pumpRealAsync(tester);

    expect(callsWhileSaving, 1, reason: 'the second tap reached the write');
    expect(writes.updates, 1);

    await tester.pumpAndSettle();
    expect(find.byType(MarkClimbedSheet), findsNothing);

    await disposeApp(tester);
  });
}

/// The edit path with a valve and a switch on it.
///
/// Two things the real DAO will not do on demand: hold a write open, so a test
/// can look at the sheet while one is in flight, and refuse one, so a test can
/// see the line the sheet puts up and tap again afterwards. Anything it neither
/// holds nor refuses goes to the real query underneath.
class _ControlledClimbDao extends ClimbDao {
  _ControlledClimbDao(super.db);

  /// One per write parked at the gate.
  final List<Completer<void>> _gates = <Completer<void>>[];

  bool _holding = false;

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

  /// How many times an edit was asked for, whether it landed or not.
  ///
  /// The sharp assertion about a double tap. Rows can be read a moment too
  /// early, but a call that was never made cannot turn up later.
  int updates = 0;

  /// The next edit throws instead of landing, once.
  bool refuseNextUpdate = false;

  @override
  Future<bool> updateClimb({
    required int id,
    required DateTime date,
    String? companions,
    String? notes,
    List<String> photoFilenames = const <String>[],
  }) async {
    updates++;

    if (_holding) {
      final Completer<void> gate = Completer<void>();
      _gates.add(gate);
      await gate.future;
    }

    if (refuseNextUpdate) {
      refuseNextUpdate = false;
      throw StateError('the write was refused for this test');
    }

    return super.updateClimb(
      id: id,
      date: date,
      companions: companions,
      notes: notes,
      photoFilenames: photoFilenames,
    );
  }
}
