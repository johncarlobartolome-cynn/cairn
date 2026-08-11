import 'package:drift/drift.dart';

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

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
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
