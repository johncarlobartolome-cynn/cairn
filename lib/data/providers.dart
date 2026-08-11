import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/daos/achievement_dao.dart';
import 'database/daos/climb_dao.dart';
import 'database/daos/mountain_dao.dart';
import 'database/database.dart';

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
