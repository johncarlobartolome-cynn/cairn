import 'package:drift/drift.dart';

import '../database.dart';

/// Every query against `mountains`. Nothing above this layer writes SQL.
class MountainDao extends DatabaseAccessor<AppDatabase> {
  MountainDao(super.attachedDatabase);

  $MountainsTable get _mountains => attachedDatabase.mountains;

  /// Every peak, alphabetical, re-emitting after any write to the table.
  Stream<List<Mountain>> watchAll() => (select(
    _mountains,
  )..orderBy([(m) => OrderingTerm(expression: m.name)])).watch();

  Future<List<Mountain>> getAll() => (select(
    _mountains,
  )..orderBy([(m) => OrderingTerm(expression: m.name)])).get();

  Stream<Mountain?> watchById(int id) =>
      (select(_mountains)..where((m) => m.id.equals(id))).watchSingleOrNull();

  /// Drives the "X of Y climbed" counter.
  Stream<int> watchCount() {
    final count = _mountains.id.count();
    final query = selectOnly(_mountains)..addColumns([count]);
    return query.map((row) => row.read(count)!).watchSingle();
  }

  /// Returns the new row id.
  Future<int> add(MountainsCompanion mountain) =>
      into(_mountains).insert(mountain);

  /// Adds one row per name not already present and leaves the rest untouched.
  /// The seed relies on this to survive being run twice.
  Future<void> insertMissingNames(List<String> names) {
    return batch((batch) {
      batch.insertAll(_mountains, [
        for (final name in names) MountainsCompanion.insert(name: name),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  /// Cascades to the peak's climbs and badges.
  Future<int> removeById(int id) =>
      (delete(_mountains)..where((m) => m.id.equals(id))).go();
}
