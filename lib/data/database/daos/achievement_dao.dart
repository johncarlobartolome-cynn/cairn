import 'package:drift/drift.dart';

import '../database.dart';

/// Every query against `achievements`. Nothing above this layer writes SQL.
class AchievementDao extends DatabaseAccessor<AppDatabase> {
  AchievementDao(super.attachedDatabase);

  $AchievementsTable get _achievements => attachedDatabase.achievements;

  /// Newest unlock first.
  Stream<List<Achievement>> watchAll() => (select(
    _achievements,
  )..orderBy([(a) => OrderingTerm.desc(a.unlockedAt)])).watch();

  /// Unlocks a badge, or does nothing if it is already unlocked.
  ///
  /// Safe to call on every climb. The two partial unique indexes on the table
  /// turn a repeat into an ignored insert, so no caller has to check first.
  Future<void> unlock(AchievementsCompanion badge) =>
      into(_achievements).insert(badge, mode: InsertMode.insertOrIgnore);

  Stream<int> watchCount() {
    final count = _achievements.id.count();
    final query = selectOnly(_achievements)..addColumns([count]);
    return query.map((row) => row.read(count)!).watchSingle();
  }
}
