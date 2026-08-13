import 'package:drift/drift.dart';

import 'mountains.dart';

/// Which badge a row is.
///
/// [perMountain] pairs with a `mountainId`. The rest are milestones and carry a
/// null `mountainId`. A plain per-mountain/milestone flag could not tell the
/// three milestones apart, which is what the unique index below has to do.
///
/// Stored as text, so E4 can add a tier without a migration.
enum AchievementType { perMountain, firstClimb, fivePeaks, allPeaks }

/// An unlocked badge.
///
/// A badge unlocks once. `uniqueKeys` alone would not enforce that: SQLite
/// treats every NULL as distinct inside a unique index, so a `(type,
/// mountain_id)` pair would happily let the same milestone unlock twice. Two
/// partial indexes cover the two shapes instead.
@DataClassName('Achievement')
@TableIndex.sql('''
  CREATE UNIQUE INDEX ux_achievements_peak
    ON achievements (type, mountain_id) WHERE mountain_id IS NOT NULL;
''')
@TableIndex.sql('''
  CREATE UNIQUE INDEX ux_achievements_milestone
    ON achievements (type) WHERE mountain_id IS NULL;
''')
class Achievements extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get type => textEnum<AchievementType>()();

  /// A real timestamp, not a calendar day: the moment the badge fired. Left on
  /// Drift's default epoch-second storage, because the instant is the point.
  /// Contrast `climbs.date`, a day that must not move when the timezone does.
  DateTimeColumn get unlockedAt => dateTime()();

  /// Null for a milestone badge. Deleting a peak takes its badge with it.
  IntColumn get mountainId => integer().nullable().references(
    Mountains,
    #id,
    onDelete: KeyAction.cascade,
  )();
}
