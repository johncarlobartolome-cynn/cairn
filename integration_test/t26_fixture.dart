// Harness support, not a test. No `main`, so `flutter test` never picks it up
// and `flutter drive` compiles it only as an import.

import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/database/tables/mountains.dart' show Difficulty;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';

/// A library the app can be pointed at, held in memory on the device.
///
/// **Nothing here touches `cairn.sqlite`.** T26 needs states the real file does
/// not hold: a peak nobody has climbed, a name longer than any of the six, a
/// library of one, a library of fourteen. Writing those into the app's own file
/// would leave the emulator carrying somebody's fixture, and the architecture
/// note already records that deleting a climb does not take its badges back, so
/// a seeded climb cannot be cleanly undone.
///
/// In memory also means the app under test and the harness share one connection
/// and nothing survives the run, which is what a fixture should do.
AppDatabase fixtureDatabase() => AppDatabase(NativeDatabase.memory());

/// Adds one peak and returns its id. Only the name is required, which is the
/// whole point of the bare-peak case.
Future<int> addPeak(
  AppDatabase db, {
  required String name,
  String? region,
  int? elevationM,
  Difficulty? difficulty,
  String? jumpOffPoint,
  double? estimatedHours,
}) => MountainDao(db).add(
  MountainsCompanion.insert(
    name: name,
    region: Value(region),
    elevationM: Value(elevationM),
    difficulty: Value(difficulty),
    jumpOffPoint: Value(jumpOffPoint),
    estimatedHours: Value(estimatedHours),
  ),
);

/// Empties the seeded library, for the shots that need a library of their own
/// shape rather than the six.
Future<void> clearLibrary(AppDatabase db) async {
  final MountainDao mountains = MountainDao(db);
  for (final Mountain peak in await mountains.getAll()) {
    await mountains.removeById(peak.id);
  }
}
