import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'database/daos/achievement_dao.dart';
import 'database/daos/climb_dao.dart';
import 'database/daos/mountain_dao.dart';
import 'database/database.dart';
import 'photos/photo_picker.dart';
import 'photos/photo_store.dart';

/// The photo types travel with their providers, for the same reason the row
/// types do: a widget cannot render a stored photo without naming them.
export 'photos/photo_picker.dart' show PhotoPicker;
export 'photos/photo_store.dart' show PhotoStore;

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

/// Every climb logged against one peak, newest first.
///
/// Auto-disposed for the same reason as [mountainByIdProvider]: peak detail is
/// the only watcher, so the query closes with the screen rather than staying
/// open for a peak nobody is looking at.
final climbsForMountainProvider = StreamProvider.autoDispose
    .family<List<Climb>, int>(
      (ref, mountainId) =>
          ref.watch(climbDaoProvider).watchForMountain(mountainId),
    );

/// The ids of peaks with at least one logged climb.
final climbedMountainIdsProvider = StreamProvider<Set<int>>(
  (ref) => ref.watch(climbDaoProvider).watchClimbedMountainIds(),
);

final achievementsProvider = StreamProvider<List<Achievement>>(
  (ref) => ref.watch(achievementDaoProvider).watchAll(),
);

/// Where the app's own files live: `cairn.sqlite` and every climb photo.
///
/// A provider that asks, rather than a string anybody can hold on to. The
/// answer is only true for as long as this install lasts, and a widget that
/// watches it is asking again on every build, which is exactly the behaviour
/// the photo rule needs. Storing the answer next to a photo is how the photo
/// gets lost.
///
/// Tests override it with a throwaway directory, which is what lets one prove
/// a stored filename still renders after the directory underneath it moved.
final documentsDirectoryProvider = FutureProvider<Directory>(
  (ref) => getApplicationDocumentsDirectory(),
);

/// Copies picked photos into the documents directory and hands back the bare
/// filename to store. See `photos/photo_filename.dart` for why that is the only
/// thing allowed into the column.
final photoStoreProvider = Provider<PhotoStore>(
  (ref) => PhotoStore(
    directory: () => ref.read(documentsDirectoryProvider.future),
  ),
);

/// The system photo picker, behind a seam so a test can stand in for it. No
/// test on any device can tap another process's UI.
final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => const SystemPhotoPicker(),
);
