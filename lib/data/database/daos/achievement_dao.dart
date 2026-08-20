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

/// The badges one delete took away, and only the ones it took away.
///
/// The mirror of [EarnedBadges], and it has to be a mirror: a delete asks for
/// the whole unearned set every time rather than working out what changed, so
/// most of what it asks for was never in the file. This is the difference.
///
/// Nothing in the app says any of this out loud, and that is deliberate. A
/// climb deleted by mistake is a thing the confirmation already asked about,
/// and a line naming the badge that went with it would be the app reading the
/// consequence back as a punishment. The badges grid shows it. This exists so
/// the write can be held to what it took, rather than a test having to infer it
/// from a table that may never have held the row.
@immutable
class RevokedBadges {
  const RevokedBadges({required this.peak, required this.milestones});

  /// The answer for a delete that took nothing, which is most deletes.
  static const RevokedBadges none = RevokedBadges(
    peak: false,
    milestones: <AchievementType>[],
  );

  /// True when that was the peak's last climb, so the peak's own badge went.
  final bool peak;

  /// The milestones that no longer hold, in the order they are reached.
  final List<AchievementType> milestones;

  bool get isEmpty => !peak && milestones.isEmpty;

  /// How many badges went.
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

  /// Takes away every badge the climber no longer holds.
  ///
  /// **The exact inverse of [unlockEarned], and the whole design is that it
  /// cannot be anything else.** Called from inside the write that deletes a
  /// climb, so the counts it is handed already have that climb out of them, the
  /// same way the unlock's counts already have the new one in.
  ///
  /// The peak's own badge is the one part that is not a count. A peak badge
  /// means "you have been up here", so it goes when the last climb of that peak
  /// goes and stays while any climb of it remains. [mountainStillClimbed]
  /// carries that answer in rather than asking, because whether a peak has
  /// climbs left is a question about `climbs` and this DAO owns
  /// `achievements`. Same reason [peaksClimbed] arrives as a number.
  ///
  /// The milestones come off [unearnedMilestones], which is [earnedMilestones]
  /// read backwards rather than a second rule written out. That is the point: a
  /// revoke rule spelled out on its own would be right today and wrong the day
  /// a tier is added or a threshold moves, and it would be wrong silently.
  ///
  /// Every delete ignores a badge that is not there, so this asks for the full
  /// unearned set each time. It makes a delete that takes nothing free, and it
  /// also lets a badge that should have gone earlier go on the next delete
  /// instead of never.
  Future<RevokedBadges> revokeUnearned({
    required int mountainId,
    required bool mountainStillClimbed,
    required int peaksClimbed,
    required int peaksInLibrary,
  }) async {
    // Short-circuits before the delete, so a peak with a climb still on it is
    // never even asked about.
    final bool peak =
        !mountainStillClimbed && await _revokePeakBadge(mountainId);

    final milestones = <AchievementType>[];
    for (final AchievementType type in unearnedMilestones(
      peaksClimbed: peaksClimbed,
      peaksInLibrary: peaksInLibrary,
    )) {
      if (await _revokeMilestone(type)) milestones.add(type);
    }

    return RevokedBadges(
      peak: peak,
      milestones: List<AchievementType>.unmodifiable(milestones),
    );
  }

  /// True when there was a peak badge on [mountainId] and it is gone now.
  Future<bool> _revokePeakBadge(int mountainId) async {
    final int gone =
        await (delete(_achievements)..where(
              (a) =>
                  a.type.equalsValue(AchievementType.perMountain) &
                  a.mountainId.equals(mountainId),
            ))
            .go();
    return gone > 0;
  }

  /// True when that milestone was in the file and is gone now.
  ///
  /// The `mountainId IS NULL` half is not decoration. It is what the milestone
  /// unique index is partial on, and without it a badge type that ever gained a
  /// per-peak form would have its peak rows swept up by a milestone revoke.
  Future<bool> _revokeMilestone(AchievementType type) async {
    final int gone = await (delete(
      _achievements,
    )..where((a) => a.type.equalsValue(type) & a.mountainId.isNull())).go();
    return gone > 0;
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

  /// Which milestones a climber with this many peaks behind them has not.
  ///
  /// **Derived from [earnedMilestones] rather than written out**, and that is
  /// the whole of why the revoke cannot drift from the unlock. There is one
  /// statement of what a milestone means in this file. This reads it the other
  /// way round.
  ///
  /// A second list, spelled out here, would be right on the day it was written
  /// and wrong the first time a tier was added or a threshold moved, and it
  /// would be wrong quietly: nothing fails when a badge simply fails to go
  /// away.
  ///
  /// [AchievementType.perMountain] is not a milestone and is skipped. It is not
  /// a function of a count at all, so it has no place in a list decided by one.
  static List<AchievementType> unearnedMilestones({
    required int peaksClimbed,
    required int peaksInLibrary,
  }) {
    final Set<AchievementType> held = earnedMilestones(
      peaksClimbed: peaksClimbed,
      peaksInLibrary: peaksInLibrary,
    ).toSet();

    return <AchievementType>[
      for (final AchievementType type in AchievementType.values)
        if (type != AchievementType.perMountain && !held.contains(type)) type,
    ];
  }

  Stream<int> watchCount() {
    final count = _achievements.id.count();
    final query = selectOnly(_achievements)..addColumns([count]);
    return query.map((row) => row.read(count)!).watchSingle();
  }
}
