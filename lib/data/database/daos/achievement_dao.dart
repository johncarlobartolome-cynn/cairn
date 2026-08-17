import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../database.dart';
import '../tables/achievements.dart';

/// How many different peaks the halfway milestone asks for.
///
/// Three, on a six-peak library. Set here rather than at the call site, because
/// this is the file that says what a milestone means.
const int kHalfwayPeaks = 3;

/// The badges one save unlocked, and only the ones it unlocked.
///
/// A save asks for the whole earned set every time rather than working out what
/// changed, so most of what it asks for is already in the file. This is the
/// difference: what fired just now. It exists because the app has to be able to
/// name the badge somebody just earned, and a list of every badge they hold
/// cannot do that.
@immutable
class EarnedBadges {
  const EarnedBadges({required this.peak, required this.milestones});

  /// The answer for a save that earned nothing, which is most saves.
  static const EarnedBadges none = EarnedBadges(
    peak: false,
    milestones: <AchievementType>[],
  );

  /// True when this climb was the peak's first, so the peak's own badge fired.
  final bool peak;

  /// The milestones that fired, in the order they are reached.
  final List<AchievementType> milestones;

  bool get isEmpty => !peak && milestones.isEmpty;

  /// How many badges fired. At most three: a peak's own badge and the two
  /// milestones a single climb can cross at once.
  int get count => (peak ? 1 : 0) + milestones.length;
}

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

  /// Unlocks a badge, or does nothing if it is already unlocked. True when it
  /// was this call that unlocked it.
  ///
  /// Safe to call on every climb. The two partial unique indexes on the table
  /// turn a repeat into an ignored insert, so no caller has to check first.
  ///
  /// `RETURNING` is what tells a fresh unlock from an ignored one: a row comes
  /// back when the insert landed and nothing comes back when the index refused
  /// it. So the answer is the write's own, rather than a read before the write
  /// that another write could slip past.
  Future<bool> unlock(AchievementsCompanion badge) async {
    final Achievement? written = await into(
      _achievements,
    ).insertReturningOrNull(badge, mode: InsertMode.insertOrIgnore);
    return written != null;
  }

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
  ///
  /// It reports what actually fired, which is the half the app says out loud.
  /// Asking for the whole set and reporting the whole set would tell somebody
  /// on their fourth trip up Batulao that they had just earned three badges.
  Future<EarnedBadges> unlockEarned({
    required int mountainId,
    required int peaksClimbed,
    required int peaksInLibrary,
    required DateTime at,
  }) async {
    final bool peak = await unlock(
      AchievementsCompanion.insert(
        type: AchievementType.perMountain,
        unlockedAt: at,
        mountainId: Value(mountainId),
      ),
    );

    final milestones = <AchievementType>[];
    for (final type in earnedMilestones(
      peaksClimbed: peaksClimbed,
      peaksInLibrary: peaksInLibrary,
    )) {
      if (await unlock(
        AchievementsCompanion.insert(type: type, unlockedAt: at),
      )) {
        milestones.add(type);
      }
    }

    return EarnedBadges(
      peak: peak,
      milestones: List<AchievementType>.unmodifiable(milestones),
    );
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
