import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/daos/achievement_dao.dart';
import 'database/daos/climb_dao.dart';
import 'database/daos/mountain_dao.dart';
import 'database/database.dart';

/// The three row types, re-exported.
///
/// The layer rule says the UI never imports `database.dart`, and a widget cannot
/// watch `StreamProvider<List<Mountain>>` without naming `Mountain`. So the type
/// travels with the provider that hands it over, and `providers.dart` stays the
/// one door into the data layer.
export 'database/database.dart' show Achievement, Climb, Mountain;

/// The one database instance for the app.
///
/// `driftDatabase` opens `cairn.sqlite` in the app documents directory. Tests
/// override this provider with an in-memory or throwaway-file executor, which
/// is why no widget or DAO ever constructs its own database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'cairn'));
  ref.onDispose(db.close);
  return db;
});

final mountainDaoProvider = Provider<MountainDao>(
  (ref) => MountainDao(ref.watch(databaseProvider)),
);

final climbDaoProvider = Provider<ClimbDao>(
  (ref) => ClimbDao(ref.watch(databaseProvider)),
);

final achievementDaoProvider = Provider<AchievementDao>(
  (ref) => AchievementDao(ref.watch(databaseProvider)),
);

/// Reads are streams fed by Drift's `watch()`, so a write anywhere refreshes
/// every screen showing the affected table with no manual invalidation.
final mountainsProvider = StreamProvider<List<Mountain>>(
  (ref) => ref.watch(mountainDaoProvider).watchAll(),
);

final mountainCountProvider = StreamProvider<int>(
  (ref) => ref.watch(mountainDaoProvider).watchCount(),
);

/// One peak, or null when nothing in the library has that id.
///
/// Auto-disposed, unlike the list providers: a detail screen is the only watcher
/// and its query should close when the screen is gone rather than stay open for
/// an id nobody is looking at. The null is a real answer, not an error, so a bad
/// id in a link becomes a not-found screen instead of an exception.
final mountainByIdProvider = StreamProvider.autoDispose.family<Mountain?, int>(
  (ref, id) => ref.watch(mountainDaoProvider).watchById(id),
);

/// One climb, or null when nothing in the log has that id. Auto-disposed for the
/// same reason as [mountainByIdProvider].
final climbByIdProvider = StreamProvider.autoDispose.family<Climb?, int>(
  (ref, id) => ref.watch(climbDaoProvider).watchById(id),
);

final climbsProvider = StreamProvider<List<Climb>>(
  (ref) => ref.watch(climbDaoProvider).watchAll(),
);

/// The ids of peaks with at least one logged climb.
final climbedMountainIdsProvider = StreamProvider<Set<int>>(
  (ref) => ref.watch(climbDaoProvider).watchClimbedMountainIds(),
);

final achievementsProvider = StreamProvider<List<Achievement>>(
  (ref) => ref.watch(achievementDaoProvider).watchAll(),
);
