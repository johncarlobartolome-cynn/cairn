import 'dart:async';
import 'dart:io';

import 'package:cairn/app/router.dart';
import 'package:cairn/data/database/daos/achievement_dao.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/providers.dart';
import 'package:cairn/features/climbs/climb_detail_screen.dart';
import 'package:cairn/features/climbs/widgets/delete_climb_action.dart';
import 'package:cairn/features/climbs/widgets/delete_climb_dialog.dart';
import 'package:cairn/features/peaks/peak_detail_screen.dart';
import 'package:cairn/shared/widgets/peak_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/photo_fixtures.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// Getting rid of a climb, driven the way a person drives it: open the climb,
/// scroll to the foot of it, tap delete, read the question, answer it.
///
/// The gap: nothing in the app deleted anything, so a climb logged against the
/// wrong peak was permanent.
void main() {
  const String peakName = 'Mt. Pulag';

  /// A second peak, so a test can prove a delete stayed where it was aimed.
  const String otherPeakName = 'Mt. Batulao';

  late AppDatabase db;
  late ClimbDao climbs;
  late MountainDao mountains;
  late AchievementDao achievements;

  /// Stands in for the app documents directory, so a test can look at which
  /// photographs survived a delete.
  late Directory documents;

  setUp(() {
    db = createTestDatabase();
    climbs = ClimbDao(db);
    mountains = MountainDao(db);
    achievements = AchievementDao(db);
    documents = createTempDirectory('documents');
  });

  tearDown(() => db.close());

  /// A day well in the past, so nothing here depends on today.
  final DateTime day = DateTime(2024, 3, 9);

  Future<int> idOf(String name) async =>
      (await mountains.getAll()).firstWhere((p) => p.name == name).id;

  Future<int> logClimb({
    String peak = peakName,
    DateTime? on,
    String? companions,
    String? notes,
    List<String> photoFilenames = const <String>[],
  }) async => (await climbs.logClimb(
    mountainId: await idOf(peak),
    date: on ?? day,
    companions: companions,
    notes: notes,
    photoFilenames: photoFilenames,
  )).id;

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

  Future<List<int>> climbIds() async =>
      (await climbs.getAll()).map((c) => c.id).toList();

  Future<Set<AchievementType>> unlockedTypes() async =>
      (await achievements.getAll()).map((a) => a.type).toSet();

  /// The peaks that hold a badge of their own.
  Future<Set<int>> badgedPeaks() async => <int>{
    for (final Achievement badge in await achievements.getAll())
      if (badge.type == AchievementType.perMountain) badge.mountainId!,
  };

  Future<void> openClimb(
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
        ...overrides,
      ],
    );
    await pumpRealAsync(tester);
  }

  Finder deleteControl() => find.text(DeleteClimbAction.label);

  /// Anything inside the confirmation, so a finder cannot pick up the climb
  /// detail screen sitting behind it. The invitation on an empty climb already
  /// says the word "photos", which is exactly the kind of accidental match that
  /// makes a "says nothing about photographs" assertion pass on nothing.
  Finder inDialog(Finder matching) =>
      find.descendant(of: find.byType(DeleteClimbDialog), matching: matching);

  /// Reaches the control the way a thumb does: it is the last thing on the
  /// screen, so on a climb with photographs it starts below the fold.
  Future<void> tapDelete(WidgetTester tester) async {
    await tester.ensureVisible(deleteControl());
    await tester.pumpAndSettle();
    await tester.tap(deleteControl());
    await tester.pumpAndSettle();
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(find.text(DeleteClimbDialog.confirmLabel));
    await tester.pumpAndSettle();
    await pumpRealAsync(tester);
  }

  /// The button behind [label], so a test can reach its handler.
  Finder buttonSaying(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextButton));

  /// Two taps inside one frame, which is the only thing the guards are for.
  ///
  /// **`tester.tap` twice with no pump between them is not this**, and finding
  /// that out is what made these two tests worth writing. Enough runs inside the
  /// second `tap` call for the dialog the first tap opened to already be over the
  /// control, so the second tap lands on the modal barrier. That version stayed
  /// green with the guard taken out, which is a test proving nothing.
  ///
  /// Calling the handler twice with nothing in between is what two pointer-up
  /// events in one input batch do on a phone, and it is the window a thumb can
  /// actually hit.
  void tapTwiceInOneFrame(WidgetTester tester, Finder button) {
    final VoidCallback press = tester.widget<TextButton>(button).onPressed!;
    press();
    press();
  }

  Future<void> cancelDelete(WidgetTester tester) async {
    await tester.tap(find.text(DeleteClimbDialog.cancelLabel));
    await tester.pumpAndSettle();
    await pumpRealAsync(tester);
  }

  testWidgets('climb detail carries the way out, under everything else', (
    tester,
  ) async {
    final int id = await logClimb(notes: 'Sea of clouds at sunrise.');

    await openClimb(tester, id);

    expect(deleteControl(), findsOneWidget);
    // Below the notes rather than beside the pencil, which is the whole of the
    // placement decision. A mistap on the everyday control cannot reach it.
    expect(
      tester.getCenter(deleteControl()).dy,
      greaterThan(tester.getCenter(find.text('Sea of clouds at sunrise.')).dy),
    );
    expect(find.byType(DeleteClimbDialog), findsNothing);

    await disposeApp(tester);
  });

  group('the confirmation', () {
    testWidgets('names the photographs that go with the climb', (tester) async {
      final int id = await logClimb(
        photoFilenames: <String>[
          storedPhoto('1755300000000001'),
          storedPhoto('1755300000000002'),
        ],
      );

      await openClimb(tester, id);
      await tapDelete(tester);

      expect(inDialog(find.text(DeleteClimbDialog.title)), findsOneWidget);
      expect(
        inDialog(
          find.text(
            DeleteClimbDialog.message(photoCount: 2, onlyClimbOfPeak: true),
          ),
        ),
        findsOneWidget,
      );
      // The words themselves, so a rewrite that drops the photographs from the
      // sentence fails here rather than passing on its own new string.
      expect(
        inDialog(find.textContaining('The 2 photos on it are deleted')),
        findsOne,
      );
      expect(
        inDialog(find.textContaining('Nothing here can be brought back')),
        findsOne,
      );

      await cancelDelete(tester);
      await disposeApp(tester);
    });

    testWidgets('one photograph is one photo, not one photos', (tester) async {
      final int id = await logClimb(
        photoFilenames: <String>[storedPhoto('1755300000000001')],
      );

      await openClimb(tester, id);
      await tapDelete(tester);

      expect(
        inDialog(
          find.textContaining('The photo on it is deleted from your phone'),
        ),
        findsOne,
      );

      await cancelDelete(tester);
      await disposeApp(tester);
    });

    testWidgets('says nothing about photographs on a climb with none', (
      tester,
    ) async {
      final int id = await logClimb();

      await openClimb(tester, id);
      await tapDelete(tester);

      expect(inDialog(find.textContaining('photo')), findsNothing);

      await cancelDelete(tester);
      await disposeApp(tester);
    });

    testWidgets("names the peak's badge when this is its only climb", (
      tester,
    ) async {
      final int id = await logClimb();

      await openClimb(tester, id);
      await tapDelete(tester);

      expect(
        inDialog(find.textContaining("the peak's badge goes too")),
        findsOne,
      );

      await cancelDelete(tester);
      await disposeApp(tester);
    });

    testWidgets('says nothing about the badge when the peak keeps it', (
      tester,
    ) async {
      // Two climbs of the same peak. The badge survives this delete, so warning
      // about it would be the app warning about something that is not going to
      // happen.
      final int id = await logClimb();
      await logClimb(on: DateTime(2024, 3, 10));

      await openClimb(tester, id);
      await tapDelete(tester);

      expect(inDialog(find.textContaining('badge')), findsNothing);

      await cancelDelete(tester);
      await disposeApp(tester);
    });

    testWidgets('holds nothing the design bans', (tester) async {
      final int id = await logClimb(
        photoFilenames: <String>[storedPhoto('1755300000000001')],
      );

      await openClimb(tester, id);
      await tapDelete(tester);

      for (final String said in <String>[
        DeleteClimbDialog.title,
        DeleteClimbDialog.message(photoCount: 1, onlyClimbOfPeak: true),
        DeleteClimbDialog.cancelLabel,
        DeleteClimbDialog.confirmLabel,
        DeleteClimbAction.label,
        deleteFailedMessage,
        climbDeleted,
      ]) {
        expect(said, isNot(contains('…')), reason: 'no ellipsis, ever');
        expect(said, isNot(contains('...')), reason: 'no ellipsis, ever');
        expect(said, isNot(contains('—')), reason: 'no em dashes');
        expect(said, isNot(contains('(')), reason: 'no parentheses');
      }

      await cancelDelete(tester);
      await disposeApp(tester);
    });
  });

  testWidgets('the row goes, and so do its photo files', (tester) async {
    final String mine = storedPhoto('1755300000000001');
    final String alsoMine = storedPhoto('1755300000000002');
    // A photograph on another climb, so the delete has something it must not
    // touch. Every filename is its own climb's, and this is where that is worth
    // something.
    final String theirs = storedPhoto('1755300000000003');
    final int id = await logClimb(photoFilenames: <String>[mine, alsoMine]);
    final int survivor = await logClimb(
      peak: otherPeakName,
      photoFilenames: <String>[theirs],
    );

    expect(photosOnDisk(), <String>[mine, alsoMine, theirs]..sort());

    await openClimb(tester, id);
    await tapDelete(tester);
    await confirmDelete(tester);

    await pumpRealUntil(
      tester,
      () async => (await climbIds()).length == 1,
      waitingFor: 'the climb to leave the log',
    );

    expect(await climbIds(), <int>[survivor]);
    expect(photosOnDisk(), <String>[
      theirs,
    ], reason: "both of its photographs go, and nobody else's does");

    await disposeApp(tester);
  });

  testWidgets('climb detail does not sit on the row it just deleted', (
    tester,
  ) async {
    final int id = await logClimb(notes: 'Sea of clouds at sunrise.');

    await openClimb(tester, id);
    await tapDelete(tester);
    await confirmDelete(tester);

    // Not on climb detail, and not on the not-found screen either. Parking
    // somebody on "Climb not found" for a climb they deleted on purpose is the
    // failure this asserts against.
    expect(find.byType(ClimbDetailScreen), findsNothing);
    expect(find.text('Climb not found'), findsNothing);
    expect(find.text('Sea of clouds at sunrise.'), findsNothing);

    // The peak the climb was on, which is the screen the delete is visible on.
    expect(find.byType(PeakDetailScreen), findsOneWidget);
    expect(find.text(peakName), findsOneWidget);
    expect(find.text(climbDeleted), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('lands on the peak even after losing the row underneath it', (
    tester,
  ) async {
    // The window the navigation has to survive, and the reason it is not gated
    // on `mounted`. The row goes before the photographs do, so the query behind
    // climb detail can publish null and rebuild the screen into "Climb not
    // found" while the delete is still finishing its file work. That takes the
    // delete control with it, and a navigation that checked `mounted` would give
    // up right there and park somebody on a not-found screen for a climb they
    // deleted on purpose.
    //
    // The store holds its deletions still so the window can be looked at. It is
    // a real window on a phone: deleting a dozen photographs is real disk work
    // and frames keep running through it.
    final String photo = storedPhoto('1755300000000001');
    final int id = await logClimb(photoFilenames: <String>[photo]);
    final _HeldPhotoDeletion store = _HeldPhotoDeletion(documents);
    // Released whatever happens, including on a failed expectation below. A
    // deletion left parked never answers, and the delete waiting on it would
    // resume inside whichever test ran next.
    addTearDown(store.letEverythingThrough);

    await openClimb(
      tester,
      id,
      overrides: <Override>[photoStoreOverride(store)],
    );
    await tapDelete(tester);
    await tester.tap(find.text(DeleteClimbDialog.confirmLabel));

    await pumpRealUntil(
      tester,
      () => find.text('Climb not found').evaluate().isNotEmpty,
      waitingFor: 'the screen to notice its row is gone',
    );
    expect(
      store.parked,
      1,
      reason: 'the delete is still running, which is what makes this a window',
    );
    expect(await climbIds(), isEmpty);

    store.letEverythingThrough();
    await pumpRealUntil(
      tester,
      () => find.byType(PeakDetailScreen).evaluate().isNotEmpty,
      waitingFor: 'the peak to arrive',
    );
    // The old route is still on screen while it slides out, so the not-found
    // screen is genuinely gone only once the transition has.
    await tester.pumpAndSettle();

    expect(find.text('Climb not found'), findsNothing);
    expect(find.text(peakName), findsOneWidget);
    expect(photosOnDisk(), isEmpty);

    await disposeApp(tester);
  });

  testWidgets('the last climb of a peak turns its card grey again', (
    tester,
  ) async {
    final int id = await logClimb();

    expect(
      await badgedPeaks(),
      <int>{await idOf(peakName)},
      reason: 'the badge is in the file before the delete takes it out',
    );

    await openClimb(tester, id);
    await tapDelete(tester);
    await confirmDelete(tester);

    await pumpRealUntil(
      tester,
      () async => (await climbIds()).isEmpty,
      waitingFor: 'the climb to leave the log',
    );

    // The half a badge grid would contradict.
    expect(await badgedPeaks(), isEmpty);
    expect(await unlockedTypes(), isEmpty);

    // And the list itself. A card still at full colour with its mark on it, over
    // a log with no climbs in it, is the contradiction anyone would spot.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await pumpRealAsync(tester);

    final PeakCard card = tester.widget<PeakCard>(
      find.ancestor(of: find.text(peakName), matching: find.byType(PeakCard)),
    );
    expect(card.climbed, isFalse);

    await disposeApp(tester);
  });

  testWidgets('one of two climbs of the same peak keeps the badge', (
    tester,
  ) async {
    final int id = await logClimb();
    await logClimb(on: DateTime(2024, 3, 10));
    final int peakId = await idOf(peakName);

    expect(await badgedPeaks(), <int>{peakId});

    await openClimb(tester, id);
    await tapDelete(tester);
    await confirmDelete(tester);

    await pumpRealUntil(
      tester,
      () async => (await climbIds()).length == 1,
      waitingFor: 'the climb to leave the log',
    );

    expect(
      await badgedPeaks(),
      <int>{peakId},
      reason: 'the peak is still climbed, so the badge is still true',
    );
    expect(await unlockedTypes(), contains(AchievementType.firstClimb));

    await disposeApp(tester);
  });

  testWidgets('a milestone that no longer holds goes with the climb', (
    tester,
  ) async {
    // Three peaks climbed, then back to two. The third-peak milestone was in the
    // file, which is the line that stops this passing on a badge that never was.
    final List<Mountain> peaks = await mountains.getAll();
    for (var index = 0; index < 3; index++) {
      await climbs.logClimb(
        mountainId: peaks[index].id,
        date: DateTime(2024, 3, index + 1),
      );
    }
    expect(
      await unlockedTypes(),
      containsAll(<AchievementType>[
        AchievementType.firstClimb,
        AchievementType.threePeaks,
      ]),
    );

    final int id = (await climbs.getAll())
        .firstWhere((c) => c.mountainId == peaks[2].id)
        .id;

    await openClimb(tester, id);
    await tapDelete(tester);
    await confirmDelete(tester);

    await pumpRealUntil(
      tester,
      () async => (await climbIds()).length == 2,
      waitingFor: 'the climb to leave the log',
    );

    final Set<AchievementType> held = await unlockedTypes();
    expect(held, isNot(contains(AchievementType.threePeaks)));
    expect(
      held,
      contains(AchievementType.firstClimb),
      reason: 'two peaks still clears the first milestone',
    );

    await disposeApp(tester);
  });

  testWidgets('cancelling the confirmation changes nothing at all', (
    tester,
  ) async {
    final String first = storedPhoto('1755300000000001');
    final String second = storedPhoto('1755300000000002');
    final int id = await logClimb(
      companions: 'Mara and Enzo',
      notes: 'Sea of clouds at sunrise.',
      photoFilenames: <String>[first, second],
    );
    final int peakId = await idOf(peakName);

    await openClimb(tester, id);
    await tapDelete(tester);

    expect(find.byType(DeleteClimbDialog), findsOneWidget);

    await cancelDelete(tester);

    expect(find.byType(DeleteClimbDialog), findsNothing);
    expect(await climbIds(), <int>[id]);
    expect(photosOnDisk(), <String>[first, second]..sort());
    expect(await badgedPeaks(), <int>{peakId});
    expect(await unlockedTypes(), contains(AchievementType.firstClimb));
    // And still on the climb, with everything on it.
    expect(find.byType(ClimbDetailScreen), findsOneWidget);
    expect(find.text('Sea of clouds at sunrise.'), findsOneWidget);

    // Cancelling let go of the guard, so the control still works.
    await tapDelete(tester);
    expect(find.byType(DeleteClimbDialog), findsOneWidget);
    await cancelDelete(tester);

    await disposeApp(tester);
  });

  testWidgets('a delete that failed says so and takes nothing', (tester) async {
    final String photo = storedPhoto('1755300000000001');
    final int id = await logClimb(
      notes: 'Sea of clouds at sunrise.',
      photoFilenames: <String>[photo],
    );
    final int peakId = await idOf(peakName);
    final _ControlledClimbDao writes = _ControlledClimbDao(db)
      ..refuseNextDelete = true;

    await openClimb(
      tester,
      id,
      overrides: <Override>[climbDaoProvider.overrideWithValue(writes)],
    );
    await tapDelete(tester);
    await confirmDelete(tester);

    expect(find.text(deleteFailedMessage), findsOneWidget);
    expect(find.byType(ClimbDetailScreen), findsOneWidget);
    expect(await climbIds(), <int>[id]);
    expect(photosOnDisk(), <String>[photo]);
    expect(await badgedPeaks(), <int>{peakId});
    expect(find.text(climbDeleted), findsNothing);

    // The guard let go, so a real failure can be tried again.
    await tapDelete(tester);
    await confirmDelete(tester);
    await pumpRealUntil(
      tester,
      () async => (await climbIds()).isEmpty,
      waitingFor: 'the second attempt to land',
    );
    expect(writes.deletes, 2);
    expect(photosOnDisk(), isEmpty);

    await tester.pumpAndSettle();
    await disposeApp(tester);
  });

  testWidgets('two taps on the control open one confirmation', (tester) async {
    final int id = await logClimb();

    await openClimb(tester, id);
    await tester.ensureVisible(deleteControl());
    await tester.pumpAndSettle();

    tapTwiceInOneFrame(tester, buttonSaying(DeleteClimbAction.label));
    await tester.pumpAndSettle();

    // Two dialogs, one hidden behind the other, is what happens without the
    // flag. Confirming both would run two deletes, and the second would find no
    // row and tell somebody their climb did not delete a moment after it did.
    expect(find.byType(DeleteClimbDialog), findsOneWidget);

    await cancelDelete(tester);
    await disposeApp(tester);
  });

  testWidgets('two taps on the confirmation delete once', (tester) async {
    final int id = await logClimb();
    await logClimb(on: DateTime(2024, 3, 10));
    // Held open, and that is what makes the second tap mean anything. A DELETE
    // against an in-memory database can finish between two taps with no frame in
    // between, and the screen is already leaving by the time the second one is
    // aimed.
    final _ControlledClimbDao writes = _ControlledClimbDao(db)..holdWrites();
    // Released whatever happens, including on a failed expectation below. A
    // write left parked never answers, and the delete waiting on it would resume
    // inside whichever test ran next.
    addTearDown(writes.letEverythingThrough);

    await openClimb(
      tester,
      id,
      overrides: <Override>[climbDaoProvider.overrideWithValue(writes)],
    );
    await tapDelete(tester);

    // Two taps on the destructive button itself, inside one frame. Each one pops
    // a route: the first pops the dialog, and without the guard the second pops
    // climb detail out from under the delete that is still running.
    tapTwiceInOneFrame(tester, buttonSaying(DeleteClimbDialog.confirmLabel));

    await pumpRealUntil(
      tester,
      () => writes.parked >= 1,
      waitingFor: 'the delete to be parked',
    );
    await pumpRealAsync(tester);
    // Lets the dialog finish leaving. It is mid-pop while the write is parked,
    // and a route still animating out is still in the tree.
    await tester.pumpAndSettle();

    // The write is held, so nothing has navigated yet. The dialog is gone and
    // the screen that started the delete is still standing.
    expect(find.byType(DeleteClimbDialog), findsNothing);
    expect(
      find.byType(ClimbDetailScreen),
      findsOneWidget,
      reason: 'the second tap took the screen under the dialog with it',
    );

    // Read while the write is held, asserted after it has been let go. An
    // expectation that failed with a write still parked would leave a delete
    // waiting on an answer that never comes.
    final int callsWhileDeleting = writes.deletes;

    writes.letEverythingThrough();
    await pumpRealUntil(
      tester,
      () async => (await climbIds()).length == 1,
      waitingFor: 'the delete to land',
    );
    // Generous on purpose. A second write runs a moment behind the first, so
    // counting the instant the first one landed would find one either way.
    await pumpRealAsync(tester);

    expect(callsWhileDeleting, 1, reason: 'the second tap reached the write');
    expect(writes.deletes, 1);
    expect(await climbIds(), hasLength(1));

    await tester.pumpAndSettle();
    await disposeApp(tester);
  });
}

/// A photo store that holds its deletions until the test says so.
///
/// The real one is over in a millisecond, and the window it leaves open is the
/// one the navigation has to survive, so a test cannot hope to catch it by
/// racing. This holds it still instead.
class _HeldPhotoDeletion extends PhotoStore {
  _HeldPhotoDeletion(Directory documents)
    : super(directory: (() async => documents));

  final List<Completer<void>> _gates = <Completer<void>>[];

  /// How many deletions are parked right now.
  int get parked => _gates.length;

  @override
  Future<void> removeAll(Iterable<String> filenames) async {
    final Completer<void> gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    return super.removeAll(filenames);
  }

  /// Lets every deletion land: the ones parked now and the ones still to come.
  void letEverythingThrough() {
    final List<Completer<void>> waiting = List<Completer<void>>.of(_gates);
    _gates.clear();
    for (final Completer<void> gate in waiting) {
      if (!gate.isCompleted) gate.complete();
    }
  }
}

/// The delete path with a valve and a switch on it.
///
/// Two things the real DAO will not do on demand: hold a write open, so a test
/// can look at the screen while one is in flight, and refuse one, so a test can
/// see the line the screen puts up and try again afterwards. Anything it neither
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

  /// How many times a delete was asked for, whether it landed or not.
  ///
  /// The sharp assertion about a double tap. Rows can be read a moment too
  /// early, but a call that was never made cannot turn up later.
  int deletes = 0;

  /// The next delete throws instead of landing, once.
  bool refuseNextDelete = false;

  @override
  Future<ClimbRemoved?> deleteClimb({required int id}) async {
    deletes++;

    if (refuseNextDelete) {
      refuseNextDelete = false;
      throw Exception('the delete was refused');
    }

    if (_holding) {
      final Completer<void> gate = Completer<void>();
      _gates.add(gate);
      await gate.future;
    }

    return super.deleteClimb(id: id);
  }
}
