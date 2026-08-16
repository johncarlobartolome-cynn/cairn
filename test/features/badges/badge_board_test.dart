import 'package:cairn/data/database/daos/achievement_dao.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/providers.dart';
import 'package:cairn/features/badges/badge_board.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

/// The reconciliation the badges screen runs on: the library says which badges
/// exist, the `achievements` table says which ones are earned.
///
/// Rows come from a real database rather than hand-built structs, so the
/// mapping is tested against the shapes the DAOs actually hand over.
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

  Future<BadgeBoard> board() async => BadgeBoard.from(
    library: await mountains.getAll(),
    unlocked: await achievements.getAll(),
  );

  BadgeView named(BadgeBoard board, String name) =>
      board.all.firstWhere((badge) => badge.name == name);

  group('the strings', () {
    test('every milestone has a name and a condition written for it', () {
      for (final type in milestoneOrder) {
        expect(
          milestoneNames[type],
          isNotNull,
          reason: '$type reaches the screen with no name',
        );
        expect(
          milestoneConditions[type],
          isNotNull,
          reason: '$type reaches the screen with no way to earn it',
        );
      }
    });

    test('perMountain is not a milestone', () {
      expect(milestoneOrder, isNot(contains(AchievementType.perMountain)));
      expect(milestoneOrder, hasLength(3));
    });

    test('the milestones run first climb, three peaks, all peaks', () {
      expect(milestoneOrder, <AchievementType>[
        AchievementType.firstClimb,
        AchievementType.threePeaks,
        AchievementType.allPeaks,
      ]);
    });

    test('no string carries an em dash, a slash or a parenthetical', () {
      final strings = <String>[
        ...milestoneNames.values,
        ...milestoneConditions.values,
        peakCondition,
      ];

      for (final line in strings) {
        expect(line, isNot(contains('—')), reason: line);
        expect(line, isNot(contains('/')), reason: line);
        expect(line, isNot(contains('(')), reason: line);
      }
    });

    test('the all-peaks badge names no number', () {
      final all = <String>[
        milestoneNames[AchievementType.allPeaks]!,
        milestoneConditions[AchievementType.allPeaks]!,
      ].join(' ').toLowerCase();

      // The library grows. A badge that says six is wrong the day somebody adds
      // a seventh peak.
      for (final number in <String>['six', '6', 'seven', '7']) {
        expect(all, isNot(contains(number)), reason: all);
      }
    });
  });

  group('the board', () {
    test(
      'draws every peak in the library, locked, before anything is climbed',
      () async {
        final library = await mountains.getAll();
        final built = await board();

        expect(built.peaks, hasLength(library.length));
        expect(
          built.peaks.map((badge) => badge.name),
          library.map((peak) => peak.name),
        );
        expect(built.peaks.every((badge) => badge.isUnlocked), isFalse);
        expect(built.earned, 0);
        expect(built.total, library.length + 3);
      },
    );

    test('a peak added to the library gets a tile of its own', () async {
      final before = (await board()).peaks.length;

      await mountains.add(
        MountainsCompanion.insert(
          name: 'Mt. Halcon',
          region: const Value('Mindoro'),
        ),
      );

      final after = await board();
      expect(after.peaks, hasLength(before + 1));
      expect(named(after, 'Mt. Halcon').isUnlocked, isFalse);
    });

    test(
      'one climb unlocks that peak and first climb, and nothing else',
      () async {
        final library = await mountains.getAll();
        final climbed = library.first;

        await climbs.logClimb(
          mountainId: climbed.id,
          date: DateTime.utc(2026, 8, 15),
        );

        final built = await board();

        expect(named(built, climbed.name).isUnlocked, isTrue);
        expect(named(built, library[1].name).isUnlocked, isFalse);
        expect(named(built, 'First climb').isUnlocked, isTrue);
        expect(named(built, 'Three peaks').isUnlocked, isFalse);
        expect(named(built, 'All peaks').isUnlocked, isFalse);

        expect(built.earned, 2);
        expect(built.milestonesEarned, 1);
      },
    );

    test('a locked badge still carries the sentence that earns it', () async {
      final built = await board();

      for (final badge in built.all) {
        expect(badge.condition.trim(), isNotEmpty, reason: badge.name);
      }
      expect(built.peaks.first.condition, peakCondition);
      expect(
        named(built, 'Three peaks').condition,
        milestoneConditions[AchievementType.threePeaks],
      );
    });

    test('a climbed peak with no badge row reads as locked', () async {
      // The emulator's own state: two peaks were climbed during E3, before any
      // code unlocked anything. A save is what unlocks, so the badge is not
      // owed and nothing backfills it.
      final peak = (await mountains.getAll()).first;
      await climbs.add(
        ClimbsCompanion.insert(
          mountainId: peak.id,
          date: DateTime.utc(2026, 8, 1),
        ),
      );

      expect(named(await board(), peak.name).isUnlocked, isFalse);
    });

    test('a milestone is a milestone and a peak badge is not', () async {
      await climbs.logClimb(
        mountainId: (await mountains.getAll()).first.id,
        date: DateTime.utc(2026, 8, 15),
      );

      final built = await board();
      expect(named(built, 'First climb').isMilestone, isTrue);
      expect(built.peaks.first.isMilestone, isFalse);
      expect(built.peaks.first.milestone, isNull);
    });
  });
}
