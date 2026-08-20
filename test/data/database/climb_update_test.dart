import 'package:cairn/data/database/daos/achievement_dao.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

/// A climb can be finished later.
///
/// The gap Jeysi found on his own phone: a climb logged on the trail with only a
/// date could never gain the companions, the notes or the photographs, because
/// nothing could write to a row that already existed.
///
/// One test per field, each read back out of the file rather than off the value
/// that was passed in. The suite runs under more than one `TZ`, so the day
/// assertions are also assertions that an edit did not move the calendar day.
void main() {
  late AppDatabase db;
  late ClimbDao climbs;
  late MountainDao mountains;
  late AchievementDao badges;

  setUp(() {
    db = createTestDatabase();
    climbs = ClimbDao(db);
    mountains = MountainDao(db);
    badges = AchievementDao(db);
  });

  tearDown(() => db.close());

  Future<int> pulagId() async =>
      (await mountains.getAll()).firstWhere((p) => p.name == 'Mt. Pulag').id;

  /// A climb with only the day on it, which is the row this whole ticket is
  /// about.
  Future<int> logBareClimb({DateTime? date, int? mountainId}) async =>
      (await climbs.logClimb(
        mountainId: mountainId ?? await pulagId(),
        date: date ?? DateTime(2026, 8, 11),
      )).id;

  Future<Climb> readBack(int id) async =>
      (await climbs.getAll()).firstWhere((c) => c.id == id);

  test('an edit moves the day, and stores it as that calendar day', () async {
    final int id = await logBareClimb();

    expect(
      await climbs.updateClimb(id: id, date: DateTime(2026, 7, 4)),
      isTrue,
    );

    expect((await readBack(id)).date, DateTime.utc(2026, 7, 4));
  });

  test('an edit fills in the companions', () async {
    final int id = await logBareClimb();

    expect(
      await climbs.updateClimb(
        id: id,
        date: DateTime(2026, 8, 11),
        companions: 'Mara and Enzo',
      ),
      isTrue,
    );

    expect((await readBack(id)).companions, 'Mara and Enzo');
  });

  test('an edit fills in the notes', () async {
    final int id = await logBareClimb();

    expect(
      await climbs.updateClimb(
        id: id,
        date: DateTime(2026, 8, 11),
        notes: 'Sea of clouds at sunrise.',
      ),
      isTrue,
    );

    expect((await readBack(id)).notes, 'Sea of clouds at sunrise.');
  });

  test('an edit fills in the photo filenames', () async {
    const List<String> names = <String>[
      'climb_1755300000000001_a1b2c3d4.jpg',
      'climb_1755300000000002_e5f6a7b8.jpg',
    ];
    final int id = await logBareClimb();

    expect(
      await climbs.updateClimb(
        id: id,
        date: DateTime(2026, 8, 11),
        photoFilenames: names,
      ),
      isTrue,
    );

    expect((await readBack(id)).photoFilenames, names);
  });

  test('an edit clears a field somebody emptied', () async {
    // The other direction, and the reason every field is written rather than
    // patched. A note somebody deleted has to come back absent.
    final int id = (await climbs.logClimb(
      mountainId: await pulagId(),
      date: DateTime(2026, 8, 11),
      companions: 'Mara and Enzo',
      notes: 'Sea of clouds at sunrise.',
      photoFilenames: const <String>['climb_1755300000000001_a1b2c3d4.jpg'],
    )).id;

    await climbs.updateClimb(id: id, date: DateTime(2026, 8, 11));

    final Climb after = await readBack(id);
    expect(after.companions, isNull);
    expect(after.notes, isNull);
    expect(after.photoFilenames, isEmpty);
  });

  test('an edit leaves the climb on its own peak', () async {
    // There is no way to move one, on purpose. Which peaks have a climb is what
    // every badge is counted from.
    final int pulag = await pulagId();
    final int id = await logBareClimb(mountainId: pulag);

    await climbs.updateClimb(
      id: id,
      date: DateTime(2026, 7, 4),
      notes: 'Rebooked for the fourth.',
    );

    expect((await readBack(id)).mountainId, pulag);
  });

  test('an edit unlocks nothing, and says nothing about badges', () async {
    // An edit cannot earn a badge: the row keeps its peak and was counted the
    // day it was saved. The write returns a plain bool for exactly that reason.
    final int id = await logBareClimb();
    final List<Achievement> before = await badges.watchAll().first;

    await climbs.updateClimb(
      id: id,
      date: DateTime(2026, 8, 11),
      notes: 'Sea of clouds at sunrise.',
    );

    final List<Achievement> after = await badges.watchAll().first;
    expect(after.map((a) => a.id), before.map((a) => a.id));
  });

  test('an edit touches one row and leaves its neighbours alone', () async {
    final int first = await logBareClimb();
    final int second = await logBareClimb(date: DateTime(2026, 8, 12));

    await climbs.updateClimb(
      id: second,
      date: DateTime(2026, 8, 12),
      notes: 'Second trip.',
    );

    expect((await readBack(first)).notes, isNull);
    expect((await readBack(second)).notes, 'Second trip.');
  });

  test('an edit to a climb that is gone changes nothing and says so', () async {
    // False is what the sheet turns into "those changes did not save". The
    // screen that asked was showing the climb a moment ago, so saying nothing
    // happened is the honest answer.
    final int id = await logBareClimb();
    await climbs.removeById(id);

    expect(
      await climbs.updateClimb(
        id: id,
        date: DateTime(2026, 8, 11),
        notes: 'Written against a row that is gone.',
      ),
      isFalse,
    );
    expect(await climbs.getAll(), isEmpty);
  });

  test('a day that already holds a climb of the same peak is taken', () async {
    // **Nothing about a climb is unique, and this is the test that says so out
    // loud.** `climbs` carries plain indexes on `mountain_id` and on `date` and
    // no unique rule anywhere, which is a written decision: two trips up the
    // same peak on one day are two climbs rather than a duplicate.
    //
    // T34's brief said an edit onto an occupied day had to fail cleanly. There
    // is no constraint for it to fail against, so the honest behaviour is this,
    // and the readable-failure path is proven against a write that really does
    // fail. See `edit_climb_test.dart`.
    final int pulag = await pulagId();
    final int first = await logBareClimb(
      mountainId: pulag,
      date: DateTime(2026, 8, 11),
    );
    final int second = await logBareClimb(
      mountainId: pulag,
      date: DateTime(2026, 8, 12),
    );

    expect(
      await climbs.updateClimb(
        id: second,
        date: DateTime(2026, 8, 11),
        notes: 'Down and straight back up.',
      ),
      isTrue,
    );

    expect((await readBack(first)).date, DateTime.utc(2026, 8, 11));
    expect((await readBack(second)).date, DateTime.utc(2026, 8, 11));
    expect(await climbs.getAll(), hasLength(2));
  });

  test('a photo path is refused by an edit, the same as by a save', () async {
    final int id = await logBareClimb();

    await expectLater(
      climbs.updateClimb(
        id: id,
        date: DateTime(2026, 8, 11),
        photoFilenames: const <String>['/var/tmp/climb_1_a.jpg'],
      ),
      throwsArgumentError,
    );

    expect((await readBack(id)).photoFilenames, isEmpty);
  });
}
