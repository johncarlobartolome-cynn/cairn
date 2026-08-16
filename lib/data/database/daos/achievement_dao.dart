import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/achievements.dart';

/// How many different peaks the halfway milestone asks for.
///
/// Three, on a six-peak library. Set here rather than at the call site, because
/// this is the file that says what a milestone means.
const int kHalfwayPeaks = 3;

/// Every query against `achievements`. Nothing above this layer writes SQL.
class AchievementDao extends DatabaseAccessor<AppDatabase> {
  AchievementDao(super.attachedDatabase);

  $AchievementsTable get _achievements => attachedDatabase.achievements;

  /// Newest unlock first.
  Stream<List<Achievement>> watchAll() => (select(
    _achievements,
  )..orderBy([(a) => OrderingTerm.desc(a.unlockedAt)])).watch();

  /// Newest unlock first, read once.
  ///
  /// The mirror of [watchAll] for a caller that wants an answer rather than a
  /// subscription. Widget tests need this one: opening a Drift stream inside a
  /// `testWidgets` body leaves work the fake clock cannot get past.
  Future<List<Achievement>> getAll() => (select(
    _achievements,
  )..orderBy([(a) => OrderingTerm.desc(a.unlockedAt)])).get();

  /// Unlocks a badge, or does nothing if it is already unlocked.
  ///
  /// Safe to call on every climb. The two partial unique indexes on the table
  /// turn a repeat into an ignored insert, so no caller has to check first.
  Future<void> unlock(AchievementsCompanion badge) =>
      into(_achievements).insert(badge, mode: InsertMode.insertOrIgnore);

  /// Unlocks every badge the climber has earned as of right now.
  ///
  /// Called from inside the write that logs a climb, so the counts it is handed
  /// already include that climb. [peaksClimbed] is how many *different* peaks
  /// have at least one climb, never how many climbs there are: three trips up
  /// Batulao is one peak. [peaksInLibrary] is how many peaks the library holds
  /// today, which is why the last milestone is not a hardcoded six. The app
  /// lets a user add their own peak, and adding one has to move the finish
  /// line rather than leave a badge that says "all peaks" over a list with a
  /// peak still grey on it.
  ///
  /// Every insert ignores a row that is already there, so this asks for the
  /// full earned set each time rather than working out what changed. That makes
  /// it safe to call on a climb that earns nothing, and it also lets a badge
  /// that was somehow missed arrive on the next climb instead of never.
  Future<void> unlockEarned({
    required int mountainId,
    required int peaksClimbed,
    required int peaksInLibrary,
    required DateTime at,
  }) async {
    await unlock(
      AchievementsCompanion.insert(
        type: AchievementType.perMountain,
        unlockedAt: at,
        mountainId: Value(mountainId),
      ),
    );

    for (final type in earnedMilestones(
      peaksClimbed: peaksClimbed,
      peaksInLibrary: peaksInLibrary,
    )) {
      await unlock(
        AchievementsCompanion.insert(type: type, unlockedAt: at),
      );
    }
  }

  /// Which milestones a climber with this many peaks behind them has reached.
  ///
  /// Pure, so the rule can be read on its own and tested without a database.
  /// An empty library earns nothing: `peaksClimbed >= 0` is true of everybody,
  /// and "all peaks" over a library of none is not an achievement.
  static List<AchievementType> earnedMilestones({
    required int peaksClimbed,
    required int peaksInLibrary,
  }) {
    return <AchievementType>[
      if (peaksClimbed >= 1) AchievementType.firstClimb,
      if (peaksClimbed >= kHalfwayPeaks) AchievementType.threePeaks,
      if (peaksInLibrary > 0 && peaksClimbed >= peaksInLibrary)
        AchievementType.allPeaks,
    ];
  }

  Stream<int> watchCount() {
    final count = _achievements.id.count();
    final query = selectOnly(_achievements)..addColumns([count]);
    return query.map((row) => row.read(count)!).watchSingle();
  }
}
