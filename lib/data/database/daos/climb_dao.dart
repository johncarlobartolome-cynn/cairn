import 'package:drift/drift.dart';

import '../database.dart';

/// Every query against `climbs`. Nothing above this layer writes SQL.
class ClimbDao extends DatabaseAccessor<AppDatabase> {
  ClimbDao(super.attachedDatabase);

  $ClimbsTable get _climbs => attachedDatabase.climbs;

  /// Newest first.
  Stream<List<Climb>> watchAll() =>
      (select(_climbs)..orderBy([(c) => OrderingTerm.desc(c.date)])).watch();

  Stream<List<Climb>> watchForMountain(int mountainId) =>
      (select(_climbs)
            ..where((c) => c.mountainId.equals(mountainId))
            ..orderBy([(c) => OrderingTerm.desc(c.date)]))
          .watch();

  Stream<Climb?> watchById(int id) =>
      (select(_climbs)..where((c) => c.id.equals(id))).watchSingleOrNull();

  /// The ids of every peak with at least one climb, for the climbed/unclimbed
  /// treatment. Grouped in SQL rather than pulling every climb row up to Dart.
  Stream<Set<int>> watchClimbedMountainIds() {
    final query = selectOnly(_climbs)
      ..addColumns([_climbs.mountainId])
      ..groupBy([_climbs.mountainId]);
    return query
        .map((row) => row.read(_climbs.mountainId)!)
        .watch()
        .map((ids) => ids.toSet());
  }

  /// Returns the new row id.
  Future<int> add(ClimbsCompanion climb) => into(_climbs).insert(climb);

  Future<int> removeById(int id) =>
      (delete(_climbs)..where((c) => c.id.equals(id))).go();
}
