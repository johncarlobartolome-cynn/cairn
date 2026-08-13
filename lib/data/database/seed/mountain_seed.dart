import '../daos/mountain_dao.dart';

/// The six peaks the app ships with, taken from Jeysi's own hiking list.
///
/// Names only. Region, elevation, difficulty, jump-off point and estimated
/// hours stay null until E2 gathers verified figures. A guessed elevation is
/// worse than a blank one, because a blank reads as missing and a wrong number
/// reads as fact.
const seededPeakNames = <String>[
  'Mt. Kabunian',
  'Mt. Pulag',
  'Mt. Ulap',
  'Mt. Batulao',
  'Mt. Daraitan',
  'Mt. Mariglem',
];

/// Inserts any seed peak that is not in the table yet.
///
/// Idempotent. `mountains.name` is unique and the insert ignores conflicts, so
/// running this a second time leaves six rows rather than twelve. It also never
/// overwrites a peak the user has since edited.
Future<void> seedMountains(MountainDao dao) =>
    dao.insertMissingNames(seededPeakNames);
