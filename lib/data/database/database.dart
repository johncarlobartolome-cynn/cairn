import 'package:drift/drift.dart';

// Imported for database.g.dart, which instantiates both converters.
import 'converters/date_only_converter.dart';
import 'converters/photo_filenames_converter.dart';
import 'daos/mountain_dao.dart';
import 'seed/mountain_seed.dart';
import 'tables/achievements.dart';
import 'tables/climbs.dart';
import 'tables/mountains.dart';

part 'database.g.dart';

/// The single SQLite database behind the app.
///
/// Nothing above the DAO layer touches this class. Widgets watch providers,
/// providers call DAOs, DAOs own the SQL.
@DriftDatabase(tables: [Mountains, Climbs, Achievements])
class AppDatabase extends _$AppDatabase {
  /// Takes the executor instead of opening one itself.
  ///
  /// Production passes the `cairn.sqlite` file connection from `drift_flutter`;
  /// tests pass `NativeDatabase.memory()` or a throwaway file. This seam is the
  /// reason the data layer is testable at all.
  AppDatabase(super.e);

  /// 2 arrived when `climbs.date` stopped being a timestamp and became a
  /// calendar day. v1 never left this branch, but the doc's rule is that a table
  /// change bumps the version and adds a step even pre-release, so it does.
  ///
  /// 3 arrived with the verified figures for the six curated peaks. No table
  /// changed: those columns have existed since v1 and simply held null. The
  /// version still moves, because a version bump is the only thing that runs
  /// code against a database that already exists.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v1 stored climbs.date as Unix epoch seconds, which let the calendar
        // day move with the device timezone. v2 stores the day itself as
        // YYYY-MM-DD text, so the column has to be rewritten, not reinterpreted.
        //
        // The number v1 wrote is the instant of a DateTime the app built in
        // local time. 'unixepoch' turns those seconds back into a timestamp, but
        // reads it in UTC, and that is the wrong frame: 00:30 on 11 August in
        // Manila is 16:30 on the 10th in UTC, so the day would move back one.
        // 'localtime' puts the instant into the zone it came from, where the
        // number names the day the hiker meant. v1 kept no offset next to the
        // instant, so the device's current zone is the only record of that frame
        // there is.
        //
        // alterTable recreates the table and its indexes for us, and foreign
        // keys are still off at this point because beforeOpen runs afterwards.
        await m.alterTable(
          TableMigration(
            climbs,
            columnTransformer: {
              climbs.date: const CustomExpression<String>(
                "strftime('%Y-%m-%d', date, 'unixepoch', 'localtime')",
              ),
            },
          ),
        );
      }

      if (from < 3) {
        // A data step rather than a schema one. T4 seeded six peaks by name and
        // left region, elevation, difficulty, jump-off point and hours null,
        // because no verified figures existed yet. T12 gathered them.
        //
        // The seed cannot deliver them on its own: it runs from `beforeOpen`
        // only when the database file is created, and that already happened on
        // every phone the app is installed on. So the figures either arrive
        // here or they never arrive at all.
        //
        // Reaching for the generated `mountains` table through the DAO is safe
        // in this one step because the table is byte-identical in v2 and v3. A
        // later migration that actually changes `mountains` has to freeze this
        // step against the v3 schema before doing so, or it will start writing
        // v2 rows through a v4 shape.
        await backfillSeededPeakFacts(MountainDao(this));
      }
    },
    beforeOpen: (details) async {
      // SQLite ignores foreign keys unless asked, per connection. Without this
      // the cascade deletes on climbs and achievements silently do nothing and
      // orphan rows pile up.
      await customStatement('PRAGMA foreign_keys = ON');

      // Runs the one time the database file is created. The seed itself is also
      // idempotent, so a retry cannot double the library.
      if (details.wasCreated) {
        await seedMountains(MountainDao(this));
      }
    },
  );
}
