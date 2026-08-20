import 'package:cairn/data/database/daos/achievement_dao.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/database/tables/achievements.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

/// Taking a climb out of the log, and everything that was only true because it
/// was in there.
///
/// The rule the whole file circles: **the revoke is the unlock read backwards.**
/// A peak badge means you have been up that peak, so it survives while any climb
/// of it survives. A milestone is a function of how many different peaks have a
/// climb, so it holds exactly while [AchievementDao.earnedMilestones] still says
/// so.
///
/// **Every revoke test asserts the badge was in the file first.** A test that
/// only looks afterwards passes just as happily on a badge that was never there,
/// which is the easiest way to write a revoke test that proves nothing.
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

  /// The peak badges in the file, by the peak they belong to.
  Future<Set<int>> badgedPeaks() async => <int>{
    for (final Achievement badge in await achievements.getAll())
      if (badge.type == AchievementType.perMountain) badge.mountainId!,
  };

  /// One climb per peak, a different day each.
  Future<void> climbEach(Iterable<Mountain> peaks) async {
    var day = 1;
    for (final peak in peaks) {
      await climbs.logClimb(
        mountainId: peak.id,
        date: DateTime.utc(2026, 8, day++),
      );
    }
  }

  /// A filename the photo column will accept, without a file behind it. The row
  /// is what this file is about; `climb_delete_test` in `features/` proves the
  /// files themselves go.
  String photoNamed(String stamp) => 'climb_${stamp}_a1b2c3d4.jpg';

  group('the row', () {
    test('goes, and takes nothing else in the log with it', () async {
      final peaks = await library();
      final int first = (await climbs.logClimb(
        mountainId: peaks.first.id,
        date: DateTime.utc(2026, 8, 11),
      )).id;
      final int second = (await climbs.logClimb(
        mountainId: peaks[1].id,
        date: DateTime.utc(2026, 8, 12),
      )).id;

      final ClimbRemoved? removed = await climbs.deleteClimb(id: first);

      expect(removed, isNotNull);
      expect((await climbs.getAll()).map((c) => c.id), <int>[
        second,
      ], reason: 'one delete, one row');
    });

    test('hands back the photographs it was holding', () async {
      // The last moment anything knows their names. The row that held them is
      // gone by the time this answers, so if the delete did not carry them up
      // the files would be unreachable litter forever.
      final peaks = await library();
      final List<String> photos = <String>[
        photoNamed('1755300000000001'),
        photoNamed('1755300000000002'),
      ];
      final int id = (await climbs.logClimb(
        mountainId: peaks.first.id,
        date: DateTime.utc(2026, 8, 11),
        photoFilenames: photos,
      )).id;

      final ClimbRemoved removed = (await climbs.deleteClimb(id: id))!;

      expect(removed.photoFilenames, photos);
    });

    test('a climb with no photographs hands back an empty list', () async {
      final peaks = await library();
      final int id = (await climbs.logClimb(
        mountainId: peaks.first.id,
        date: DateTime.utc(2026, 8, 11),
      )).id;

      expect((await climbs.deleteClimb(id: id))!.photoFilenames, isEmpty);
    });

    test('deleting one climb leaves the other climb its own photos', () async {
      // The claim that nothing is shared, checked rather than trusted. Every
      // name comes off `PhotoStore.copyIn`, which builds it from a microsecond
      // stamp and a random suffix and then checks the directory, so two rows
      // cannot name the same file and a delete cannot reach across.
      final peaks = await library();
      final String mine = photoNamed('1755300000000001');
      final String yours = photoNamed('1755300000000002');
      final int first = (await climbs.logClimb(
        mountainId: peaks.first.id,
        date: DateTime.utc(2026, 8, 11),
        photoFilenames: <String>[mine],
      )).id;
      final int second = (await climbs.logClimb(
        mountainId: peaks.first.id,
        date: DateTime.utc(2026, 8, 12),
        photoFilenames: <String>[yours],
      )).id;

      final ClimbRemoved removed = (await climbs.deleteClimb(id: first))!;

      expect(removed.photoFilenames, <String>[mine]);
      expect(
        removed.photoFilenames,
        isNot(contains(yours)),
        reason: 'the surviving climb still shows that photograph',
      );
      expect((await climbs.getAll()).single.id, second);
    });

    test('a climb that is not there answers null and changes nothing', () async {
      // What the screen turns into "that climb did not delete". It was showing
      // the climb a moment ago, so saying nothing happened is the honest answer.
      final peaks = await library();
      await climbEach(peaks.take(3));
      final Set<AchievementType> before = await unlockedTypes();

      expect(await climbs.deleteClimb(id: 9999), isNull);

      expect(await climbs.getAll(), hasLength(3));
      expect(
        await unlockedTypes(),
        before,
        reason: 'a delete that found nothing may not revoke anything',
      );
    });
  });

  group("the peak's own badge", () {
    test('goes with the last climb of that peak', () async {
      final peaks = await library();
      final int id = (await climbs.logClimb(
        mountainId: peaks.first.id,
        date: DateTime.utc(2026, 8, 11),
      )).id;

      // Asserted before the delete, and this is the line that makes the test
      // worth anything. Without it the expectation below passes on a badge that
      // never existed.
      expect(await badgedPeaks(), <int>{peaks.first.id});

      final ClimbRemoved removed = (await climbs.deleteClimb(id: id))!;

      expect(removed.revoked.peak, isTrue);
      expect(await badgedPeaks(), isEmpty);
    });

    test('stays while a second climb of the same peak remains', () async {
      // Two climbs of one peak are legal on purpose. The peak is still climbed,
      // so the badge is still true.
      final peaks = await library();
      final int first = (await climbs.logClimb(
        mountainId: peaks.first.id,
        date: DateTime.utc(2026, 8, 11),
      )).id;
      await climbs.logClimb(
        mountainId: peaks.first.id,
        date: DateTime.utc(2026, 8, 12),
      );

      expect(await badgedPeaks(), <int>{peaks.first.id});

      final ClimbRemoved removed = (await climbs.deleteClimb(id: first))!;

      expect(removed.revoked.peak, isFalse);
      expect(await badgedPeaks(), <int>{peaks.first.id});
    });

    test('stays even when both climbs were on the same day', () async {
      // The case the owner chose delete over a unique index for. Both rows are
      // the same peak on the same day, and taking one out leaves the peak
      // climbed.
      final peaks = await library();
      final int first = (await climbs.logClimb(
        mountainId: peaks.first.id,
        date: DateTime.utc(2026, 8, 11),
      )).id;
      await climbs.logClimb(
        mountainId: peaks.first.id,
        date: DateTime.utc(2026, 8, 11),
      );

      final ClimbRemoved removed = (await climbs.deleteClimb(id: first))!;

      expect(removed.revoked.peak, isFalse);
      expect(await badgedPeaks(), <int>{peaks.first.id});
    });

    test('only the deleted climb of a peak loses its badge', () async {
      final peaks = await library();
      await climbEach(peaks.take(3));
      final int id = (await climbs.getAll())
          .firstWhere((c) => c.mountainId == peaks[1].id)
          .id;

      expect(await badgedPeaks(), <int>{peaks[0].id, peaks[1].id, peaks[2].id});

      await climbs.deleteClimb(id: id);

      expect(await badgedPeaks(), <int>{peaks[0].id, peaks[2].id});
    });
  });

  group('the milestones', () {
    test('a milestone that no longer holds goes', () async {
      final peaks = await library();
      await climbEach(peaks.take(3));

      expect(
        await unlockedTypes(),
        containsAll(<AchievementType>[
          AchievementType.firstClimb,
          AchievementType.threePeaks,
        ]),
        reason: 'three peaks is in the file before the delete takes it out',
      );

      // Third peak out, so three climbed peaks becomes two.
      final int id = (await climbs.getAll())
          .firstWhere((c) => c.mountainId == peaks[2].id)
          .id;
      final ClimbRemoved removed = (await climbs.deleteClimb(id: id))!;

      expect(removed.revoked.milestones, <AchievementType>[
        AchievementType.threePeaks,
      ]);
      expect(
        await unlockedTypes(),
        isNot(contains(AchievementType.threePeaks)),
      );
    });

    test('a milestone that still holds is kept', () async {
      final peaks = await library();
      await climbEach(peaks.take(3));

      // Two climbs of the same peak now, so deleting one leaves three climbed
      // peaks and every milestone earned so far still true.
      await climbs.logClimb(
        mountainId: peaks[2].id,
        date: DateTime.utc(2026, 8, 20),
      );
      final int id = (await climbs.getAll())
          .firstWhere(
            (c) =>
                c.mountainId == peaks[2].id &&
                c.date == DateTime.utc(2026, 8, 20),
          )
          .id;

      final ClimbRemoved removed = (await climbs.deleteClimb(id: id))!;

      expect(removed.revoked.isEmpty, isTrue);
      expect(
        await unlockedTypes(),
        containsAll(<AchievementType>[
          AchievementType.firstClimb,
          AchievementType.threePeaks,
        ]),
      );
    });

    test('all peaks goes as soon as one peak is unclimbed again', () async {
      final peaks = await library();
      await climbEach(peaks);

      expect(await unlockedTypes(), contains(AchievementType.allPeaks));

      final int id = (await climbs.getAll())
          .firstWhere((c) => c.mountainId == peaks.last.id)
          .id;
      final ClimbRemoved removed = (await climbs.deleteClimb(id: id))!;

      expect(removed.revoked.milestones, <AchievementType>[
        AchievementType.allPeaks,
      ]);
      expect(
        await unlockedTypes(),
        containsAll(<AchievementType>[
          AchievementType.firstClimb,
          AchievementType.threePeaks,
        ]),
        reason: 'five peaks still clears both of the earlier milestones',
      );
    });

    test('the last climb in the log takes every milestone with it', () async {
      final peaks = await library();
      final int id = (await climbs.logClimb(
        mountainId: peaks.first.id,
        date: DateTime.utc(2026, 8, 11),
      )).id;

      expect(await unlockedTypes(), contains(AchievementType.firstClimb));

      final ClimbRemoved removed = (await climbs.deleteClimb(id: id))!;

      expect(removed.revoked.peak, isTrue);
      expect(removed.revoked.milestones, <AchievementType>[
        AchievementType.firstClimb,
      ]);
      expect(
        await achievements.getAll(),
        isEmpty,
        reason: 'an empty log holds no badges at all',
      );
    });

    test('a delete that revokes nothing reports nothing', () async {
      // Two climbs of one peak, one taken out. Nothing changes, and the answer
      // has to say so rather than reporting the badges that are still there.
      final peaks = await library();
      final int id = (await climbs.logClimb(
        mountainId: peaks.first.id,
        date: DateTime.utc(2026, 8, 11),
      )).id;
      await climbs.logClimb(
        mountainId: peaks.first.id,
        date: DateTime.utc(2026, 8, 12),
      );

      final ClimbRemoved removed = (await climbs.deleteClimb(id: id))!;

      expect(removed.revoked.isEmpty, isTrue);
      expect(removed.revoked.count, 0);
    });
  });

  group('the rule read backwards', () {
    List<AchievementType> unearned(int climbed, int library) =>
        AchievementDao.unearnedMilestones(
          peaksClimbed: climbed,
          peaksInLibrary: library,
        );

    List<AchievementType> earned(int climbed, int library) =>
        AchievementDao.earnedMilestones(
          peaksClimbed: climbed,
          peaksInLibrary: library,
        );

    /// Every milestone there is. The one thing both lists have to add up to.
    const Set<AchievementType> allMilestones = <AchievementType>{
      AchievementType.firstClimb,
      AchievementType.threePeaks,
      AchievementType.allPeaks,
    };

    test('earned and unearned always partition the milestones', () async {
      // The property that keeps a revoke from drifting from an unlock. Whatever
      // the counts, every milestone is in exactly one of the two lists, so a
      // tier added later cannot be forgotten by the revoke.
      for (var climbed = 0; climbed <= 7; climbed++) {
        for (var inLibrary = 0; inLibrary <= 7; inLibrary++) {
          final held = earned(climbed, inLibrary).toSet();
          final gone = unearned(climbed, inLibrary).toSet();

          expect(
            held.intersection(gone),
            isEmpty,
            reason:
                'a badge cannot be both held and revoked at $climbed of '
                '$inLibrary',
          );
          expect(
            held.union(gone),
            allMilestones,
            reason: 'every milestone is decided at $climbed of $inLibrary',
          );
        }
      }
    });

    test('no peak climbed leaves no milestone standing', () {
      expect(unearned(0, 6), <AchievementType>[
        AchievementType.firstClimb,
        AchievementType.threePeaks,
        AchievementType.allPeaks,
      ]);
    });

    test('two of six keeps the first climb and drops the rest', () {
      expect(unearned(2, 6), <AchievementType>[
        AchievementType.threePeaks,
        AchievementType.allPeaks,
      ]);
    });

    test('every peak climbed leaves nothing to revoke', () {
      expect(unearned(6, 6), isEmpty);
    });

    test('the peak badge is never in either list', () {
      // It is not a function of a count, so it has no place in a list decided by
      // one. The delete decides it from whether the peak still has a climb.
      for (var climbed = 0; climbed <= 7; climbed++) {
        expect(
          unearned(climbed, 6),
          isNot(contains(AchievementType.perMountain)),
        );
        expect(
          earned(climbed, 6),
          isNot(contains(AchievementType.perMountain)),
        );
      }
    });
  });
}
