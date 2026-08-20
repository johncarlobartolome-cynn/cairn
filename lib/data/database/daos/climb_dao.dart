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

/// One deleted climb: the photographs that went with it, and the badges that no
/// longer hold.
///
/// The mirror of [ClimbLogged]. The filenames travel up because the files are
/// not the database's to delete and the row that named them is already gone, so
/// this is the last moment anything knows what they were called. The badges
/// travel for the reason the earned ones do: they went inside the same
/// transaction, so a caller holding this holds the whole of what the delete did.
@immutable
class ClimbRemoved {
  const ClimbRemoved({required this.photoFilenames, required this.revoked});

  /// The bare filenames the row was holding, in the order it held them.
  final List<String> photoFilenames;

  final RevokedBadges revoked;
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

  /// Rewrites one climb's own fields, and says whether a row changed.
  ///
  /// The gap this closes: a climb saved on a trail with no signal used to be
  /// final. Somebody logs the day, walks out, and the companions, the notes and
  /// the photographs are all things they meant to add at home. There was no way
  /// to add them.
  ///
  /// **Every field is written, including the empty ones.** An edit is the whole
  /// of what the climb now says, so a note the user deleted has to arrive here
  /// as null and land as null. A patch API that skipped absent fields could not
  /// clear one, and clearing one is a thing people do.
  ///
  /// **[mountainId] is not among them, on purpose.** A climb belongs to the peak
  /// it was logged against. Moving one to another peak is a different operation
  /// with its own consequences, since which peaks have climbs is what the badges
  /// are counted from, and nothing in the app asks for it.
  ///
  /// **No badge unlocks here, and none can.** Every badge is a function of which
  /// peaks have a climb against them, and an edit cannot change that: the row
  /// keeps its peak, and it was already counted when it was first saved. So this
  /// is a plain write rather than a transaction, and the caller has nothing to
  /// announce.
  ///
  /// False means nothing changed, which is a climb that is no longer in the log.
  /// The screen that asked was showing it a moment ago, so the honest answer is
  /// to say the edit did not save rather than to pretend it did.
  ///
  /// [photoFilenames] are bare filenames, same as [logClimb]. The column's
  /// converter refuses a path, so an edit that skipped the copy fails here.
  Future<bool> updateClimb({
    required int id,
    required DateTime date,
    String? companions,
    String? notes,
    List<String> photoFilenames = const <String>[],
  }) async {
    final int changed = await (update(_climbs)..where((c) => c.id.equals(id)))
        .write(
          ClimbsCompanion(
            date: Value(date),
            companions: Value(companions),
            notes: Value(notes),
            photoFilenames: Value(photoFilenames),
          ),
        );
    return changed > 0;
  }

  /// Deletes one climb, and everything that was only true because of it.
  ///
  /// The gap this closes: nothing in the app deleted anything. A climb logged
  /// against the wrong peak, or a second one saved by a tap that got through,
  /// was permanent. The same shape as the one T34 closed, where the app
  /// recorded something and would not let you fix it.
  ///
  /// **Null means there was no such climb**, which is the honest answer for a
  /// screen that was showing it a moment ago. Nothing was deleted and nothing
  /// was revoked, so the caller has a failure to report rather than a success
  /// to act on.
  ///
  /// **The row and the badges go in one transaction**, mirroring [logClimb]. A
  /// climb whose badge outlived it is the contradiction anyone would spot: the
  /// peaks list turns the card grey while the badge grid still shows it gold. A
  /// crash part way has to leave both or neither.
  ///
  /// The revoke is the inverse of the unlock rather than a rule of its own. See
  /// [AchievementDao.revokeUnearned] and [AchievementDao.unearnedMilestones]
  /// for why that is the only version of this that stays correct.
  ///
  /// **The photographs are not deleted here.** They are files, the file system
  /// knows nothing about this transaction, and a rollback cannot bring a deleted
  /// file back. So the names come out and the caller deletes the files once the
  /// row is definitely gone. The cost of that order is a file left behind if the
  /// app dies in between, which is litter. The other order costs a photograph
  /// off a climb that is still in the log.
  ///
  /// Every filename on a climb is that climb's own. `PhotoStore.copyIn` builds
  /// each one from a microsecond stamp and a random suffix and then checks the
  /// directory before using it, so no two copies of anything share a name and
  /// nothing here can delete a photograph another climb is showing. Held by
  /// `photo_store_test.dart`, and again by the two-climb case in
  /// `climb_delete_test.dart`.
  Future<ClimbRemoved?> deleteClimb({required int id}) {
    return transaction(() async {
      // Read before the delete, because the filenames are on the row and the
      // row is about to stop existing.
      final Climb? climb = await (select(
        _climbs,
      )..where((c) => c.id.equals(id))).getSingleOrNull();
      if (climb == null) return null;

      await (delete(_climbs)..where((c) => c.id.equals(id))).go();

      // Counted after the delete and inside the same transaction, so the climb
      // being deleted is already out of the answer. The exact mirror of the
      // unlock in [logClimb].
      final RevokedBadges revoked = await _achievements.revokeUnearned(
        mountainId: climb.mountainId,
        mountainStillClimbed: await _hasClimbs(climb.mountainId),
        peaksClimbed: await countClimbedMountains(),
        peaksInLibrary: await _mountains.countAll(),
      );

      return ClimbRemoved(
        photoFilenames: List<String>.unmodifiable(climb.photoFilenames),
        revoked: revoked,
      );
    });
  }

  /// Whether this peak still has a climb against it.
  ///
  /// Counted in SQL rather than read as rows, for the reason
  /// [countClimbedMountains] is: the answer is a number and nothing wants the
  /// list.
  Future<bool> _hasClimbs(int mountainId) async {
    final count = _climbs.id.count();
    final query = selectOnly(_climbs)
      ..addColumns([count])
      ..where(_climbs.mountainId.equals(mountainId));
    return ((await query.getSingle()).read(count) ?? 0) > 0;
  }
}
