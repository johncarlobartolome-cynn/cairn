// Harness support, not a test. No `main`, so `flutter test` never picks it up
// and `flutter drive` compiles it only as an import.

import 'dart:io';

import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/providers.dart' show PhotoStore;
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'painted_photo_picker.dart';

/// The state the README's pictures are taken of.
///
/// **Why a fixture and not the device's own database.** `screenshot_test.dart`
/// photographs the app as it stands on the emulator, which is the right thing
/// for a sweep of every route: it shoots what a real install shows. It is the
/// wrong thing for a README. The default state is six unclimbed cards, an empty
/// badges screen and no climb to open, so the picture that has to carry the idea
/// would show none of it, and a picture of a state somebody hand-built on one
/// emulator is not reproducible by anybody else.
///
/// So the README set gets a library of its own, seeded here. Three peaks
/// climbed out of six, two badges plus three peak badges earned, and photographs
/// on one climb. Anyone can run it and get the same screens.
///
/// **Nothing here touches `cairn.sqlite` or the app's documents directory.** The
/// library is held in memory and the photographs go to a throwaway directory
/// under the temporary folder, so a capture run leaves the emulator exactly as
/// it found it and cannot plant demo climbs in somebody's real log. This is the
/// same reasoning `t26_fixture.dart` is built on. The two stay separate files
/// rather than sharing one, because they seed opposite things: T26 wants
/// libraries the real one cannot hold, and this wants one honest library that a
/// reader would recognise.
typedef DemoLibrary = ({
  /// The seeded library, in memory. Close it when the run is done.
  AppDatabase db,

  /// Stands in for the app documents directory, so the copies the photo store
  /// makes are throwaway.
  Directory photos,

  /// The climbed peak the detail shot opens. Carries the log entry with
  /// companions, a note and the photographs.
  int detailPeakId,

  /// The climb the photo shot opens.
  int photoClimbId,
});

/// One climb to seed, said the way the log would say it.
typedef _DemoClimb = ({
  String peak,
  DateTime day,
  String companions,
  String notes,
  bool photos,
});

/// The peak the detail shot opens.
///
/// Kabunian rather than one of the other two, because its jump-off point is the
/// longest of the six and carries a second sentence about registering. That is
/// the string the never-truncate rule was written for, so it is the one worth
/// having a picture of.
const String detailPeakName = 'Mt. Kabunian';

/// Three of the six, and which three is a decision rather than the first three.
///
/// The library reads alphabetically, so Batulao, Kabunian and Ulap land first,
/// third and sixth in the grid. Climbing the first three would put a solid block
/// of colour over a solid block of grey, which reads as two lists rather than as
/// one set part way done.
///
/// Dates are fixed, not relative to today, so two runs a month apart produce the
/// same screens.
final List<_DemoClimb> _log = <_DemoClimb>[
  (
    peak: 'Mt. Batulao',
    day: DateTime(2026, 5, 17),
    companions: 'Mara',
    notes:
        'Ten little peaks along the ridge and the wind never let up. '
        'Back at the jump-off before noon.',
    photos: false,
  ),
  (
    peak: detailPeakName,
    day: DateTime(2026, 7, 4),
    companions: 'Mara and Enzo',
    notes:
        'Left at three in the morning and caught the sunrise from the summit. '
        'Wind on the ridge was worse than the climb.',
    photos: true,
  ),
  (
    peak: 'Mt. Ulap',
    day: DateTime(2026, 8, 9),
    companions: 'Rafa',
    notes: 'The clouds held until eight. Easy walking the whole way up.',
    photos: false,
  ),
];

/// How many photographs the climb that has them carries.
///
/// Two rather than one, because the photo strip gives up a slice of the front
/// card once a climb has company and one photograph would never show that.
const int _photoCount = 2;

/// Builds the demo library and returns what a shot needs to open it.
///
/// The climbs go in through [ClimbDao.logClimb], the same call the mark-climbed
/// sheet makes, so the badges unlock the way they unlock for a real climber:
/// inside each climb's own transaction, by the app's own rules. Nothing here
/// writes a badge row directly, which is what keeps the badges grid honest
/// rather than dressed.
Future<DemoLibrary> seedDemoLibrary() async {
  final AppDatabase db = AppDatabase(NativeDatabase.memory());
  final ClimbDao climbs = ClimbDao(db);

  // The seed runs when the database is created, so the six curated peaks are
  // already here. Looked up by name rather than by position: the ids are an
  // insertion order and the shots are about particular mountains.
  final Map<String, int> idByName = <String, int>{
    for (final Mountain peak in await MountainDao(db).getAll())
      peak.name: peak.id,
  };

  final Directory photos = await _emptyPhotoDirectory();
  final List<String> filenames = await _paintedPhotos(photos);

  int? photoClimbId;
  for (final _DemoClimb entry in _log) {
    final int? peakId = idByName[entry.peak];
    if (peakId == null) {
      throw StateError(
        'The seeded library has no peak called ${entry.peak}, so the demo '
        'state cannot be built. Check the names in mountain_seed.dart.',
      );
    }

    final ClimbLogged logged = await climbs.logClimb(
      mountainId: peakId,
      date: entry.day,
      companions: entry.companions,
      notes: entry.notes,
      photoFilenames: entry.photos ? filenames : const <String>[],
      // Fixed, like the dates. Nothing on screen shows it, and a stamp that
      // moves every run is still a difference between two captures.
      unlockedAt: entry.day,
    );
    if (entry.photos) photoClimbId = logged.id;
  }

  final int? detailPeakId = idByName[detailPeakName];
  if (detailPeakId == null || photoClimbId == null) {
    throw StateError(
      'The demo log has to climb $detailPeakName and put photographs on one '
      'climb. Check _log above.',
    );
  }

  return (
    db: db,
    photos: photos,
    detailPeakId: detailPeakId,
    photoClimbId: photoClimbId,
  );
}

/// Painted pictures, copied in the way the app copies a picked photo.
///
/// [PaintedPhotoPicker] leaves files where the system picker leaves them, and
/// [PhotoStore.copyIn] is the app's own copy, cap and naming. So the filenames
/// on the seeded climb are filenames the app itself would have written, and the
/// screen renders them through the same path it renders a real photograph.
Future<List<String>> _paintedPhotos(Directory documents) async {
  final PhotoStore store = PhotoStore(directory: () async => documents);
  return <String>[
    for (final String picked in await PaintedPhotoPicker(_photoCount).pick())
      await store.copyIn(picked),
  ];
}

/// A directory standing in for the app documents directory, emptied first.
///
/// Emptied rather than added to, so a second run does not photograph the
/// leftovers of the first one.
Future<Directory> _emptyPhotoDirectory() async {
  final Directory dir = Directory(
    '${(await getTemporaryDirectory()).path}/cairn-readme-photos',
  );
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);
  return dir;
}
