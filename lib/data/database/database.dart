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

  /// Bumped to 2 when `climbs.date` stopped being a timestamp and became a
  /// calendar day. v1 never left this branch, but the doc's rule is that a table
  /// change bumps the version and adds a step even pre-release, so it does.
  @override
  int get schemaVersion => 2;

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
