import 'package:drift/drift.dart';

import '../database.dart';

/// Every query against `climbs`. Nothing above this layer writes SQL.
class ClimbDao extends DatabaseAccessor<AppDatabase> {
  ClimbDao(super.attachedDatabase);

  $ClimbsTable get _climbs => attachedDatabase.climbs;

  /// Newest first.
  Stream<List<Climb>> watchAll() =>
      (select(_climbs)..orderBy([(c) => OrderingTerm.desc(c.date)])).watch();

  /// Newest first, read once. The mirror of [watchAll] for a caller that wants
  /// an answer rather than a subscription, e.g. a test asserting what landed in
  /// the file.
  Future<List<Climb>> getAll() =>
      (select(_climbs)..orderBy([(c) => OrderingTerm.desc(c.date)])).get();

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

  /// Logs one climb from plain values and returns its new row id.
  ///
  /// The write path above this layer hands over a mountain, a day and two
  /// optional strings, so no Drift type travels upwards and nothing outside
  /// `data/` has to build a companion. [date] arrives as whatever [DateTime]
  /// the caller happens to hold; the column's converter keeps the calendar day
  /// and drops the rest.
  ///
  /// Nothing here is unique. A peak can be climbed as often as you like, and
  /// twice on the same day is a real answer rather than a duplicate.
  Future<int> logClimb({
    required int mountainId,
    required DateTime date,
    String? companions,
    String? notes,
  }) => add(
    ClimbsCompanion.insert(
      mountainId: mountainId,
      date: date,
      companions: Value(companions),
      notes: Value(notes),
    ),
  );

  Future<int> removeById(int id) =>
      (delete(_climbs)..where((c) => c.id.equals(id))).go();
}
