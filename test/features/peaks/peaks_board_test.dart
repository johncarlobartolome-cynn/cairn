import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/features/peaks/peaks_board.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

/// The reconciliation the peaks list runs on: the library says which peaks
/// exist, the climb log says which of them are climbed, and the filter says
/// which of those to draw.
///
/// Rows come from a real database rather than hand-built structs, so the
/// mapping is tested against the shapes the queries actually hand over.
void main() {
  late AppDatabase db;
  late MountainDao mountains;
  late ClimbDao climbs;

  setUp(() {
    db = createTestDatabase();
    mountains = MountainDao(db);
    climbs = ClimbDao(db);
  });

  tearDown(() => db.close());

  Future<PeaksBoard> board(PeakFilter filter) async => PeaksBoard.from(
    library: await mountains.getAll(),
    climbedIds: await climbs.watchClimbedMountainIds().first,
    filter: filter,
  );

  Future<int> climbFirst() async {
    final peak = (await mountains.getAll()).first;
    await climbs.logClimb(mountainId: peak.id, date: DateTime.utc(2026, 8, 15));
    return peak.id;
  }

  test('All admits every peak, in the library order', () async {
    final library = await mountains.getAll();
    final all = await board(PeakFilter.all);

    expect(all.visible.map((peak) => peak.name), library.map((p) => p.name));
    expect(all.libraryTotal, library.length);
    expect(all.climbedTotal, 0);
  });

  test('the two halves add up to the whole', () async {
    await climbFirst();

    final toClimb = await board(PeakFilter.toClimb);
    final climbed = await board(PeakFilter.climbed);
    final all = await board(PeakFilter.all);

    expect(climbed.visible, hasLength(1));
    expect(toClimb.visible, hasLength(all.libraryTotal - 1));
    expect(
      <String>{
        for (final peak in toClimb.visible) peak.name,
        for (final peak in climbed.visible) peak.name,
      },
      all.visible.map((peak) => peak.name).toSet(),
    );
  });

  test('the count follows the library when a peak is added', () async {
    await climbFirst();
    expect((await board(PeakFilter.all)).libraryTotal, 6);

    await mountains.add(MountainsCompanion.insert(name: 'Mt. Zambales'));

    final grown = await board(PeakFilter.all);
    expect(grown.libraryTotal, 7);
    expect(grown.climbedTotal, 1);
  });

  test('a climbed id outside the library cannot inflate the count', () async {
    // Counted off the library rather than off the id set. Nothing writes a
    // stray id today, and the strip saying "7 of 6" is a bad enough sentence
    // to be worth making impossible rather than unlikely.
    final board = PeaksBoard.from(
      library: await mountains.getAll(),
      climbedIds: const <int>{9999},
      filter: PeakFilter.all,
    );

    expect(board.climbedTotal, 0);
    expect(board.allClimbed, isFalse);
  });

  test('every peak climbed empties the To climb list on purpose', () async {
    for (final peak in await mountains.getAll()) {
      await climbs.logClimb(mountainId: peak.id, date: DateTime.utc(2026, 8, 15));
    }

    final toClimb = await board(PeakFilter.toClimb);

    expect(toClimb.isEmpty, isTrue);
    expect(toClimb.allClimbed, isTrue);
    expect(toClimb.libraryIsEmpty, isFalse);
  });

  test('an empty library is empty rather than finished', () async {
    for (final peak in await mountains.getAll()) {
      await mountains.removeById(peak.id);
    }

    final all = await board(PeakFilter.all);

    expect(all.libraryIsEmpty, isTrue);
    // Nothing climbed and nothing to climb is not the finish line, and the
    // screen shows a different message for it.
    expect(all.allClimbed, isFalse);
  });

  test('every filter has a label written for it', () {
    for (final filter in PeakFilter.values) {
      expect(filter.label, isNotEmpty, reason: '$filter reaches a pill unnamed');
      expect(filter.label, isNot(contains('—')));
    }
  });
}
