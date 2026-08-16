import 'package:cairn/data/database/daos/achievement_dao.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/database/tables/achievements.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

/// Badges, and the write that unlocks them.
///
/// The rule the whole file circles: a milestone counts **peaks**, not climbs,
/// and no badge can unlock twice. The second half is held by two partial unique
/// indexes in the file itself, proven in `schema_constraints_test.dart` with raw
/// SQL that never touches Dart.
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

  /// The library, in a fixed order, so a test can say "the third peak".
  Future<List<Mountain>> library() => mountains.getAll();

  Future<Set<AchievementType>> unlockedTypes() async =>
      (await achievements.getAll()).map((a) => a.type).toSet();

  /// The badges held against one peak.
  Future<List<Achievement>> badgesFor(int mountainId) async =>
      (await achievements.getAll())
          .where((a) => a.mountainId == mountainId)
          .toList();

  Future<void> climbEach(Iterable<Mountain> peaks) async {
    var day = 1;
    for (final peak in peaks) {
      await climbs.logClimb(
        mountainId: peak.id,
        date: DateTime.utc(2026, 8, day++),
      );
    }
  }

  test('the first climb unlocks its peak badge and the first-climb milestone', () async {
    final peaks = await library();

    await climbs.logClimb(
      mountainId: peaks.first.id,
      date: DateTime.utc(2026, 8, 11),
    );

    final rows = await achievements.getAll();
    expect(rows, hasLength(2));

    final peakBadge = rows.singleWhere(
      (a) => a.type == AchievementType.perMountain,
    );
    expect(peakBadge.mountainId, peaks.first.id);

    final milestone = rows.singleWhere(
      (a) => a.type == AchievementType.firstClimb,
    );
    expect(
      milestone.mountainId,
      isNull,
      reason: 'a milestone belongs to nobody in particular',
    );
  });

  test('a second climb of the same peak unlocks nothing new', () async {
    final peak = (await library()).first;

    await climbs.logClimb(mountainId: peak.id, date: DateTime.utc(2026, 8, 11));
    final first = await achievements.getAll();

    await climbs.logClimb(mountainId: peak.id, date: DateTime.utc(2026, 8, 12));
    final second = await achievements.getAll();

    expect(second, hasLength(first.length));
    // Same rows, not replacements: the ids and the moment they fired both hold.
    expect(second.map((a) => a.id), unorderedEquals(first.map((a) => a.id)));
    expect(
      second.map((a) => a.unlockedAt),
      unorderedEquals(first.map((a) => a.unlockedAt)),
    );
  });

  test('three climbs of one peak is one peak, so no halfway milestone', () async {
    final peak = (await library()).first;

    await climbEach([peak, peak, peak]);

    expect(await climbs.getAll(), hasLength(3));
    expect(await climbs.countClimbedMountains(), 1);
    expect(await unlockedTypes(), <AchievementType>{
      AchievementType.perMountain,
      AchievementType.firstClimb,
    });
  });

  test('the halfway milestone waits for the third different peak', () async {
    final peaks = await library();

    await climbEach(peaks.take(2));
    expect(
      await unlockedTypes(),
      isNot(contains(AchievementType.threePeaks)),
      reason: 'two peaks is not halfway on a six-peak list',
    );

    await climbEach(peaks.skip(2).take(1));
    expect(await unlockedTypes(), contains(AchievementType.threePeaks));

    // One badge for each peak so far, plus first climb and halfway.
    expect(await achievements.getAll(), hasLength(3 + 2));
  });

  test('climbing every peak in the library unlocks the last milestone', () async {
    final peaks = await library();

    await climbEach(peaks);

    expect(await unlockedTypes(), <AchievementType>{
      AchievementType.perMountain,
      AchievementType.firstClimb,
      AchievementType.threePeaks,
      AchievementType.allPeaks,
    });
    for (final peak in peaks) {
      expect(await badgesFor(peak.id), hasLength(1), reason: peak.name);
    }
  });

  test('all peaks means the library, not six', () async {
    // The app lets a user add a peak of their own, so the finish line moves.
    final added = await mountains.add(
      MountainsCompanion.insert(name: 'Mt. Talamitam'),
    );
    final curated = (await library()).where((p) => p.id != added);
    expect(curated, hasLength(6));

    await climbEach(curated);
    expect(
      await unlockedTypes(),
      isNot(contains(AchievementType.allPeaks)),
      reason: 'six of seven is not all of them',
    );

    await climbs.logClimb(mountainId: added, date: DateTime.utc(2026, 8, 20));
    expect(await unlockedTypes(), contains(AchievementType.allPeaks));
  });

  test('a peak badge is per peak, so a second peak earns its own', () async {
    final peaks = await library();

    await climbEach(peaks.take(2));

    final peakBadges = (await achievements.getAll())
        .where((a) => a.type == AchievementType.perMountain)
        .toList();
    expect(peakBadges, hasLength(2));
    expect(
      peakBadges.map((a) => a.mountainId),
      unorderedEquals(<int?>[peaks[0].id, peaks[1].id]),
    );
  });

  test('the badge stamp is the moment it fired, not the day of the climb', () async {
    final peak = (await library()).first;
    final firedAt = DateTime.utc(2026, 8, 17, 9, 30);

    await climbs.logClimb(
      mountainId: peak.id,
      // A hike from years ago, logged this morning.
      date: DateTime.utc(2019, 3, 2),
      unlockedAt: firedAt,
    );

    for (final badge in await achievements.getAll()) {
      // Compared as an instant. The column is a real timestamp, stored as epoch
      // seconds and read back in the device's own zone, which is the whole
      // difference between this column and `climbs.date`.
      expect(badge.unlockedAt.toUtc(), firedAt);
      expect(badge.unlockedAt.toUtc(), isNot(DateTime.utc(2019, 3, 2)));
    }
  });

  test('the halfway milestone is stored under its own name', () async {
    // The column is text, and T18 renamed the value. This reads the raw cell
    // rather than the enum, so a rename that only half landed would show up.
    await climbEach((await library()).take(3));

    final rows = await db
        .customSelect('SELECT type FROM achievements WHERE mountain_id IS NULL')
        .get();
    final stored = rows.map((r) => r.read<String>('type')).toSet();

    expect(stored, <String>{'firstClimb', 'threePeaks'});
    expect(stored, isNot(contains('fivePeaks')));
  });

  test('a badge that cannot be written takes the climb down with it', () async {
    final peak = (await library()).first;

    // The failure has to land inside the unlock, after the climb row is in.
    // Refusing every achievement insert at the database itself is the bluntest
    // way to arrange that, and it needs no seam in the code under test.
    await db.customStatement('''
      CREATE TRIGGER refuse_every_badge BEFORE INSERT ON achievements
      BEGIN SELECT RAISE(ABORT, 'no badges today'); END;
    ''');

    await expectLater(
      climbs.logClimb(mountainId: peak.id, date: DateTime.utc(2026, 8, 11)),
      throwsA(anything),
    );

    expect(
      await climbs.getAll(),
      isEmpty,
      reason: 'the climb should have rolled back with the badge',
    );
    expect(await achievements.getAll(), isEmpty);

    // And the same save works once the refusal is lifted, so the test proved a
    // rollback rather than a write path that was broken all along.
    await db.customStatement('DROP TRIGGER refuse_every_badge');
    await climbs.logClimb(mountainId: peak.id, date: DateTime.utc(2026, 8, 11));
    expect(await climbs.getAll(), hasLength(1));
    expect(await achievements.getAll(), hasLength(2));
  });

  test('a climb added straight through add() unlocks nothing', () async {
    // The seam matters: add() is the raw insert tests and seeds use, logClimb
    // is the app's write path. Badges hang off the write path.
    final peak = (await library()).first;

    await climbs.add(
      ClimbsCompanion.insert(mountainId: peak.id, date: DateTime.utc(2026, 8)),
    );

    expect(await achievements.getAll(), isEmpty);
  });

  group('the milestone rule on its own', () {
    List<AchievementType> earned(int climbed, int library) =>
        AchievementDao.earnedMilestones(
          peaksClimbed: climbed,
          peaksInLibrary: library,
        );

    test('nothing at all before the first peak', () {
      expect(earned(0, 6), isEmpty);
    });

    test('the halfway milestone is three peaks', () {
      expect(earned(2, 6), <AchievementType>[AchievementType.firstClimb]);
      expect(earned(3, 6), <AchievementType>[
        AchievementType.firstClimb,
        AchievementType.threePeaks,
      ]);
    });

    test('an empty library earns nothing, not everything', () {
      // peaksClimbed >= 0 is true of every climber alive, and "all peaks" over
      // a library of none is not an achievement.
      expect(earned(0, 0), isEmpty);
    });

    test('a library smaller than the halfway mark still finishes', () {
      expect(earned(2, 2), <AchievementType>[
        AchievementType.firstClimb,
        AchievementType.allPeaks,
      ]);
    });
  });

  test('deleting a peak takes its badge but leaves the milestones', () async {
    final peaks = await library();
    await climbEach(peaks.take(3));

    await mountains.removeById(peaks.first.id);

    expect(await badgesFor(peaks.first.id), isEmpty);
    expect(await unlockedTypes(), contains(AchievementType.threePeaks));
  });
}
