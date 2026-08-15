import 'package:drift/drift.dart' show Value;

import '../daos/mountain_dao.dart';
import '../database.dart';
import '../tables/mountains.dart';

/// One curated peak and the figures T12 verified for it.
///
/// Every field is non-null here, unlike the table, because a curated peak is
/// the one case where all of it is known. The table stays nullable for the
/// peaks a user adds themselves.
typedef SeededPeak = ({
  String name,
  String region,
  int elevationM,
  Difficulty difficulty,
  String jumpOffPoint,

  /// Whole hours today, though the column is fractional on purpose. These are
  /// guide figures for a fit hiker and get replaced by Jeysi's own splits once
  /// he has climbed the peak, at which point halves start showing up.
  double estimatedHours,
});

/// The six peaks the app ships with, from Jeysi's own hiking list.
///
/// Every figure traces to a source in the project's peak-data note, researched
/// for T12. Nothing here was invented to fill a cell. Where the sources
/// disagreed the note records which number was taken and why, and the comments
/// below carry those decisions to the place a reader will question them.
///
/// Difficulty is PinoyMountaineer's 1 to 9 scale, banded 1-3 easy, 4-6
/// moderate, 7-9 hard. It grades against every Philippine mountain rather than
/// against these six, so nothing in this list is `hard` and that is correct:
/// 7-9 is Guiting-Guiting territory. A scale relative to the list would
/// re-grade every existing peak each time a user adds one.
const seededPeaks = <SeededPeak>[
  (
    name: 'Mt. Kabunian',
    region: 'Benguet (Bakun)',
    // 1,789 and 1,840 both circulate, from genuinely different sources rather
    // than one bad copy. Bakun's own registration materials say 1,789.
    elevationM: 1789,
    difficulty: Difficulty.moderate,
    jumpOffPoint:
        'Brgy. Poblacion, Bakun — register at Bakun National High School / '
        'Municipal Tourism Council',
    estimatedHours: 4,
  ),
  (
    name: 'Mt. Pulag',
    region: 'Benguet (Bokod)',
    // Wikipedia cites PHIVOLCS for 2,928 and is arguably the better survey
    // figure. 2,922 is what the permit and the trail signage say, which is the
    // number a hiker stands next to.
    elevationM: 2922,
    // The Ambangeg trail, which is 3/9 and the way roughly 95% of hikers go.
    // Akiki is 6-7/9 and Tawangan harder still: difficulty really belongs to a
    // route, not a mountain, and one column cannot hold that. Tracked as an
    // open question against a future `routes` table.
    difficulty: Difficulty.easy,
    jumpOffPoint: 'DENR Ambangeg Ranger Station, Bokod',
    estimatedHours: 4,
  ),
  (
    name: 'Mt. Ulap',
    region: 'Benguet (Itogon)',
    elevationM: 1846,
    difficulty: Difficulty.easy,
    jumpOffPoint:
        'Brgy. Ampucao, Itogon — register at the Barangay Hall / Elementary '
        'School gym',
    estimatedHours: 3,
  ),
  (
    name: 'Mt. Batulao',
    region: 'Batangas (Nasugbu)',
    elevationM: 811,
    difficulty: Difficulty.moderate,
    // Renamed from Evercrest, and access here has changed more than once.
    // Worth re-checking before a real trip.
    jumpOffPoint:
        'KC Hillcrest (was Evercrest Golf Course), Brgy. Patutong Malaki, '
        'Nasugbu',
    estimatedHours: 3,
  ),
  (
    name: 'Mt. Daraitan',
    region: 'Rizal (Tanay)',
    elevationM: 739,
    difficulty: Difficulty.moderate,
    jumpOffPoint: 'Brgy. Daraitan Barangay Hall, Tanay',
    estimatedHours: 3,
  ),
  (
    name: 'Mt. Mariglem',
    region: 'Zambales (Cabangan)',
    // The shakiest row in the list. Mariglem only opened to hikers in 2023,
    // after PinoyMountaineer went dormant, so no canonical entry exists and
    // every figure comes from 2025-26 blogs that may be copying each other.
    elevationM: 573,
    difficulty: Difficulty.easy,
    jumpOffPoint: 'Sitio Maporac, Brgy. New San Juan, Cabangan',
    estimatedHours: 2,
  ),
];

/// The curated names alone, for callers that only need to know which peaks the
/// app ships rather than what is known about them.
final seededPeakNames = List<String>.unmodifiable(
  seededPeaks.map((peak) => peak.name),
);

/// Inserts any curated peak the table does not hold yet, in full.
///
/// Idempotent. `mountains.name` is unique and the insert ignores conflicts, so
/// a second run leaves six rows rather than twelve, and it never rewrites a
/// peak the user has since edited.
///
/// Runs from `beforeOpen` on the one open that creates the file. An install
/// that already exists never comes through here, which is why
/// [backfillSeededPeakFacts] exists.
Future<void> seedMountains(MountainDao dao) => dao.insertMissing(_rows);

/// Fills the curated figures onto peaks that are already in the table without
/// them.
///
/// The 2 to 3 migration calls this. T4 seeded six names and left every other
/// column null, so a phone that installed the app before T13 holds rows that
/// `onCreate` will never run over again. This is the only path the figures have
/// to reach them.
Future<void> backfillSeededPeakFacts(MountainDao dao) =>
    dao.fillMissingFacts(_rows);

/// The seed as table rows. Both writers above go through this, so the data has
/// one definition and the insert and the backfill cannot drift apart.
List<MountainsCompanion> get _rows => [
  for (final peak in seededPeaks)
    MountainsCompanion.insert(
      name: peak.name,
      region: Value(peak.region),
      elevationM: Value(peak.elevationM),
      difficulty: Value(peak.difficulty),
      jumpOffPoint: Value(peak.jumpOffPoint),
      estimatedHours: Value(peak.estimatedHours),
    ),
];
