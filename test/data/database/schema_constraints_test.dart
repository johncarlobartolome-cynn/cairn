import 'package:cairn/data/database/daos/achievement_dao.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/database/tables/achievements.dart';
// `show` keeps drift's `isNull` expression from shadowing the matcher of the
// same name from flutter_test.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MountainDao mountains;
  late ClimbDao climbs;
  late AchievementDao achievements;

  setUp(() {
    db = createTestDatabase();
    mountains = MountainDao(db);
    climbs = ClimbDao(db);
    achievements = AchievementDao(db);
  });

  tearDown(() => db.close());

  Future<int> pulagId() async =>
      (await mountains.getAll()).firstWhere((p) => p.name == 'Mt. Pulag').id;

  test('foreign keys are enforced, so a climb needs a real peak', () async {
    expect(
      () => climbs.add(
        ClimbsCompanion.insert(mountainId: 9999, date: DateTime.utc(2026)),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('deleting a peak cascades to its climbs and badges', () async {
    final id = await pulagId();

    await climbs.add(
      ClimbsCompanion.insert(mountainId: id, date: DateTime.utc(2026, 8, 11)),
    );
    await achievements.unlock(
      AchievementsCompanion.insert(
        type: AchievementType.perMountain,
        unlockedAt: DateTime.utc(2026, 8, 11),
        mountainId: Value(id),
      ),
    );
    expect(await climbs.watchAll().first, hasLength(1));
    expect(await achievements.watchAll().first, hasLength(1));

    await mountains.removeById(id);

    expect(await climbs.watchAll().first, isEmpty);
    expect(await achievements.watchAll().first, isEmpty);
  });

  test('a per-peak badge cannot unlock twice for the same peak', () async {
    final id = await pulagId();
    final badge = AchievementsCompanion.insert(
      type: AchievementType.perMountain,
      unlockedAt: DateTime.utc(2026, 8, 11),
      mountainId: Value(id),
    );

    await achievements.unlock(badge);
    await achievements.unlock(badge);

    expect(await achievements.watchCount().first, 1);
  });

  test('a milestone badge cannot unlock twice despite its null peak', () async {
    final badge = AchievementsCompanion.insert(
      type: AchievementType.firstClimb,
      unlockedAt: DateTime.utc(2026, 8, 11),
    );

    await achievements.unlock(badge);
    await achievements.unlock(badge);

    expect(await achievements.watchCount().first, 1);
  });

  test('the database itself refuses a duplicate peak badge', () async {
    // The two tests above go through `unlock`, which asks SQLite to ignore a
    // repeat. That shows the app is polite, not that the file is safe. This one
    // and the next write raw SQL with no ignore clause, so the only thing that
    // can stop them is the index in the file. Drop the index and they pass.
    final id = await pulagId();
    const insert =
        'INSERT INTO achievements (type, unlocked_at, mountain_id) '
        "VALUES ('perMountain', 1786900000, ?)";

    await db.customStatement(insert, <Object?>[id]);

    await expectLater(
      db.customStatement(insert, <Object?>[id]),
      throwsA(
        predicate(
          (Object? e) => '$e'.contains('UNIQUE constraint failed'),
          'a UNIQUE constraint failure',
        ),
      ),
    );
    expect(await achievements.watchCount().first, 1);
  });

  test('the database itself refuses a duplicate milestone badge', () async {
    // The one SQLite would otherwise wave through. Every NULL counts as
    // distinct inside a unique index, so `(type, mountain_id)` as an ordinary
    // pair would let the same milestone unlock as often as it liked. The
    // partial index on `type` alone, where `mountain_id IS NULL`, closes that.
    const insert =
        'INSERT INTO achievements (type, unlocked_at, mountain_id) '
        "VALUES ('firstClimb', 1786900000, NULL)";

    await db.customStatement(insert);

    await expectLater(
      db.customStatement(insert),
      throwsA(
        predicate(
          (Object? e) => '$e'.contains('UNIQUE constraint failed'),
          'a UNIQUE constraint failure',
        ),
      ),
    );
    expect(await achievements.watchCount().first, 1);
  });

  test('the same peak can hold two badges of different types', () async {
    final id = await pulagId();

    await achievements.unlock(
      AchievementsCompanion.insert(
        type: AchievementType.perMountain,
        unlockedAt: DateTime.utc(2026, 8, 11),
        mountainId: Value(id),
      ),
    );
    await achievements.unlock(
      AchievementsCompanion.insert(
        type: AchievementType.firstClimb,
        unlockedAt: DateTime.utc(2026, 8, 11),
        mountainId: Value(id),
      ),
    );

    expect(await achievements.watchCount().first, 2);
  });

  test('climbed peak ids come back grouped, one entry per peak', () async {
    final id = await pulagId();

    await climbs.add(
      ClimbsCompanion.insert(mountainId: id, date: DateTime.utc(2025, 1, 1)),
    );
    await climbs.add(
      ClimbsCompanion.insert(mountainId: id, date: DateTime.utc(2026, 8, 11)),
    );

    expect(await climbs.watchClimbedMountainIds().first, {id});
  });

  test('a climb with no photos reads back as an empty list', () async {
    final id = await pulagId();
    await climbs.add(
      ClimbsCompanion.insert(mountainId: id, date: DateTime.utc(2026, 8, 11)),
    );

    final climb = (await climbs.watchAll().first).single;
    expect(climb.photoFilenames, isEmpty);
    expect(climb.companions, isNull);
    expect(climb.notes, isNull);
  });
}
