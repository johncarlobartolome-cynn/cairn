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

  /// How many peaks the library holds, read once.
  ///
  /// The "all peaks" badge asks this rather than assuming six. A user is
  /// allowed to add a peak of their own, and a seventh peak has to move the
  /// finish line rather than leave a finished badge sitting over a list with a
  /// peak still unclimbed on it.
  Future<int> countAll() async {
    final count = _mountains.id.count();
    final query = selectOnly(_mountains)..addColumns([count]);
    return (await query.getSingle()).read(count)!;
  }

  /// Returns the new row id.
  Future<int> add(MountainsCompanion mountain) =>
      into(_mountains).insert(mountain);

  /// Adds one row per peak whose name is not present already and leaves the
  /// rest untouched. The seed relies on this to survive being run twice.
  Future<void> insertMissing(List<MountainsCompanion> peaks) {
    return batch((batch) {
      batch.insertAll(_mountains, peaks, mode: InsertMode.insertOrIgnore);
    });
  }

  /// Writes each peak's facts onto the matching row, but only into the columns
  /// that are empty there.
  ///
  /// The seed migration uses this to reach installs that were created before
  /// the figures existed. Three rules, each defensive on purpose:
  ///
  /// - rows are matched on `name`, which carries the unique index. Ids are
  ///   assigned per install and mean nothing across devices
  /// - a column that already holds a value is left alone. Nothing in the app
  ///   edits a peak today, so nothing can be clobbered yet, but E3 onwards adds
  ///   that and a migration that eats user edits only shows up after it has
  ///   eaten some
  /// - a name with no row behind it is skipped rather than inserted. A user is
  ///   allowed to delete a curated peak, and re-adding it here would be this
  ///   method quietly undoing that
  ///
  /// Peaks the caller does not name are never touched at all, so a mountain the
  /// user added themselves comes through untouched.
  Future<void> fillMissingFacts(List<MountainsCompanion> peaks) async {
    await transaction(() async {
      for (final peak in peaks) {
        final row = await (select(
          _mountains,
        )..where((m) => m.name.equals(peak.name.value))).getSingleOrNull();

        if (row == null) continue;

        final patch = MountainsCompanion(
          region: _ifMissing(row.region, peak.region),
          elevationM: _ifMissing(row.elevationM, peak.elevationM),
          difficulty: _ifMissing(row.difficulty, peak.difficulty),
          jumpOffPoint: _ifMissing(row.jumpOffPoint, peak.jumpOffPoint),
          estimatedHours: _ifMissing(row.estimatedHours, peak.estimatedHours),
        );

        // Nothing was missing. Writing an all-absent companion is not a legal
        // update, and touching the row anyway would wake every watcher on the
        // table for no change.
        if (patch.toColumns(false).isEmpty) continue;

        await (update(
          _mountains,
        )..where((m) => m.id.equals(row.id))).write(patch);
      }
    });
  }

  /// Offers [replacement] only where the row has nothing, so a set value wins
  /// over a curated one.
  static Value<T?> _ifMissing<T extends Object>(
    T? current,
    Value<T?> replacement,
  ) => current == null ? replacement : const Value.absent();

  /// Cascades to the peak's climbs and badges.
  Future<int> removeById(int id) =>
      (delete(_mountains)..where((m) => m.id.equals(id))).go();
}
