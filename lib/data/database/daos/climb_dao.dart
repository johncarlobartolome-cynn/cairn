import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../database.dart';
import 'achievement_dao.dart';
import 'mountain_dao.dart';

/// One saved climb: the row that landed, and the badges that fired with it.
///
/// The badges travel with the id because they were written in the same
/// transaction, so a caller holding this holds the whole of what the save did.
/// The alternative was reading the badge table back afterwards, which would
/// have to work out which rows were new by comparing timestamps.
@immutable
class ClimbLogged {
  const ClimbLogged({required this.id, required this.earned});

  /// The new row's id.
  final int id;

  final EarnedBadges earned;
}

/// Every query against `climbs`. Nothing above this layer writes SQL.
class ClimbDao extends DatabaseAccessor<AppDatabase> {
  ClimbDao(super.attachedDatabase);

  $ClimbsTable get _climbs => attachedDatabase.climbs;

  /// Badges are a consequence of a climb, so logging one reaches for them. Both
  /// of these are thin wrappers over the same database and hold no state, so
  /// building one per call costs nothing and keeps every query about a table in
  /// the DAO that owns it.
  AchievementDao get _achievements => AchievementDao(attachedDatabase);

  MountainDao get _mountains => MountainDao(attachedDatabase);

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

  /// How many different peaks have at least one climb.
  ///
  /// Distinct peaks, never climbs: three trips up Batulao count once. The
  /// milestones are built on this number, which is why it is counted in SQL
  /// rather than assembled from a list of rows.
  Future<int> countClimbedMountains() async {
    final climbed = _climbs.mountainId.count(distinct: true);
    final query = selectOnly(_climbs)..addColumns([climbed]);
    return (await query.getSingle()).read(climbed)!;
  }

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

  /// Logs one climb from plain values and returns what the save produced.
  ///
  /// The write path above this layer hands over a mountain, a day and two
  /// optional strings, so no Drift type travels upwards and nothing outside
  /// `data/` has to build a companion. [date] arrives as whatever [DateTime]
  /// the caller happens to hold; the column's converter keeps the calendar day
  /// and drops the rest.
  ///
  /// Nothing here is unique. A peak can be climbed as often as you like, and
  /// twice on the same day is a real answer rather than a duplicate.
  ///
  /// [photoFilenames] are bare filenames of files already copied into the
  /// documents directory. Never paths: the column's converter refuses one, so
  /// a caller that skipped the copy fails here and loudly, rather than storing
  /// a photo that nobody can find after the next install.
  ///
  /// **The badges this climb earns are unlocked here too, in the same
  /// transaction.** Two reasons it lives inside the write rather than beside
  /// it. Saving a climb that unlocks two badges is one thing the user did, so a
  /// crash between the row and the badge must leave neither rather than a climb
  /// with a badge missing. And a badge that only unlocks when the caller
  /// remembers to ask is a badge that stops unlocking the first time somebody
  /// adds a second save path.
  ///
  /// [unlockedAt] is the moment the badges fired, and defaults to now. Tests
  /// pass their own so the stamp on a row is something they can assert.
  ///
  /// **The badges that fired come back with the id**, because this is the only
  /// place that knows. The unlock ignores a badge already in the file, so which
  /// of them are new is something only the write can tell, and the app says it
  /// out loud the moment the sheet closes.
  Future<ClimbLogged> logClimb({
    required int mountainId,
    required DateTime date,
    String? companions,
    String? notes,
    List<String> photoFilenames = const <String>[],
    DateTime? unlockedAt,
  }) {
    return transaction(() async {
      final int id = await add(
        ClimbsCompanion.insert(
          mountainId: mountainId,
          date: date,
          companions: Value(companions),
          notes: Value(notes),
          photoFilenames: Value(photoFilenames),
        ),
      );

      // Counted after the insert and inside the same transaction, so the climb
      // being saved is already part of the answer.
      final EarnedBadges earned = await _achievements.unlockEarned(
        mountainId: mountainId,
        peaksClimbed: await countClimbedMountains(),
        peaksInLibrary: await _mountains.countAll(),
        at: unlockedAt ?? DateTime.now(),
      );

      return ClimbLogged(id: id, earned: earned);
    });
  }

  Future<int> removeById(int id) =>
      (delete(_climbs)..where((c) => c.id.equals(id))).go();
}
