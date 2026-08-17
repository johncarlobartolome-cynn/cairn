import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/database/seed/mountain_seed.dart';
import 'package:cairn/data/database/tables/mountains.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

typedef _Facts = ({
  String region,
  int elevationM,
  Difficulty difficulty,
  String jumpOffPoint,
  double estimatedHours,
});

/// The six peaks as the project's peak-data note states them, typed out again
/// here instead of read back off `seededPeaks`.
///
/// Comparing the seed against itself would certify nothing. That test passes
/// just as happily with 2,928 in it, or with Pulag graded hard. These literals
/// were checked against the sources by hand, so a slip in the seed fails here
/// rather than on a mountain.
const _expected = <String, _Facts>{
  'Mt. Kabunian': (
    region: 'Benguet',
    elevationM: 1789,
    difficulty: Difficulty.moderate,
    jumpOffPoint:
        'Brgy. Poblacion, Bakun. Register at Bakun National High School or '
        'the Municipal Tourism Council.',
    estimatedHours: 4,
  ),
  'Mt. Pulag': (
    region: 'Benguet',
    elevationM: 2922,
    difficulty: Difficulty.easy,
    jumpOffPoint: 'DENR Ambangeg Ranger Station, Bokod.',
    estimatedHours: 4,
  ),
  'Mt. Ulap': (
    region: 'Benguet',
    elevationM: 1846,
    difficulty: Difficulty.easy,
    jumpOffPoint:
        'Brgy. Ampucao, Itogon. Register at the Barangay Hall or the '
        'Elementary School gym.',
    estimatedHours: 3,
  ),
  'Mt. Batulao': (
    region: 'Batangas',
    elevationM: 811,
    difficulty: Difficulty.moderate,
    jumpOffPoint:
        'KC Hillcrest, Brgy. Patutong Malaki, Nasugbu. Formerly Evercrest '
        'Golf Course.',
    estimatedHours: 3,
  ),
  'Mt. Daraitan': (
    region: 'Rizal',
    elevationM: 739,
    difficulty: Difficulty.moderate,
    jumpOffPoint: 'Brgy. Daraitan Barangay Hall, Tanay.',
    estimatedHours: 3,
  ),
  'Mt. Mariglem': (
    region: 'Zambales',
    elevationM: 573,
    difficulty: Difficulty.easy,
    jumpOffPoint: 'Sitio Maporac, Brgy. New San Juan, Cabangan.',
    estimatedHours: 2,
  ),
};

void main() {
  late AppDatabase db;
  late MountainDao dao;

  setUp(() {
    db = createTestDatabase();
    dao = MountainDao(db);
  });

  tearDown(() => db.close());

  test(
    'a new database holds the six seeded peaks in alphabetical order',
    () async {
      final peaks = await dao.getAll();

      expect(peaks, hasLength(6));
      expect(peaks.map((p) => p.name), [
        'Mt. Batulao',
        'Mt. Daraitan',
        'Mt. Kabunian',
        'Mt. Mariglem',
        'Mt. Pulag',
        'Mt. Ulap',
      ]);
      expect(seededPeakNames.toSet(), peaks.map((p) => p.name).toSet());
    },
  );

  test('every seeded peak carries its verified figures', () async {
    final peaks = {for (final peak in await dao.getAll()) peak.name: peak};

    expect(peaks.keys, unorderedEquals(_expected.keys));

    _expected.forEach((name, facts) {
      final peak = peaks[name]!;

      expect(peak.region, facts.region, reason: '$name region');
      expect(peak.elevationM, facts.elevationM, reason: '$name elevation');
      expect(peak.difficulty, facts.difficulty, reason: '$name difficulty');
      expect(peak.jumpOffPoint, facts.jumpOffPoint, reason: '$name jump-off');
      expect(peak.estimatedHours, facts.estimatedHours, reason: '$name hours');
    });
  });

  test('no seeded value uses written-only punctuation', () async {
    // The rule for every string this app shows: write it for the spoken voice,
    // the way someone would say it out loud. Both jump-off points that needed
    // rewriting proved it twice over. They arrived with an em dash, were
    // rewritten with a parenthetical aside, and that still read like a
    // footnote rather than speech. An address and then a sentence is what a
    // person actually says.
    //
    // Only the characters are testable. "Reads like speech" is a review
    // judgement and nothing here pretends to check it, so this bans the three
    // marks that never survive being read aloud and leaves the phrasing to a
    // human. A test that claimed more than it checks would be worse than no
    // test, because it would be trusted.
    //
    // Asserted over `SELECT *` rather than over the six records, so a text
    // column a later ticket adds is covered without anyone remembering this
    // test exists.
    const banned = <String, String>{
      '—': 'an em dash, which reads as machine-written',
      '(': 'a parenthesis, which turns the aside into a footnote',
      ')': 'a parenthesis, which turns the aside into a footnote',
      '/': 'a slash standing in for the word "or"',
    };

    for (final row in await db.customSelect('SELECT * FROM mountains').get()) {
      row.data.forEach((column, value) {
        if (value is! String) return;

        banned.forEach((mark, why) {
          expect(
            value,
            isNot(contains(mark)),
            reason:
                'mountains.$column holds $why: "$value". Say it in plain '
                'sentences instead. The rule covers every string the app '
                'shows, not only the seeded six.',
          );
        });
      });
    }
  });

  test(
    'a seeded peak has no notes, because notes belong to the user',
    () async {
      for (final peak in await dao.getAll()) {
        expect(peak.notes, isNull);
      }
    },
  );

  test('seeding again leaves six rows, not twelve', () async {
    await seedMountains(dao);
    await seedMountains(dao);

    expect(await dao.getAll(), hasLength(6));
  });

  test('seeding again does not rewrite an edited peak', () async {
    final pulag = (await dao.getAll()).firstWhere((p) => p.name == 'Mt. Pulag');

    // The figure a hiker who trusts PHIVOLCS over the signage would type in.
    await db
        .update(db.mountains)
        .replace(pulag.copyWith(elevationM: const Value(2928)));

    await seedMountains(dao);

    final after = (await dao.getAll()).firstWhere((p) => p.name == 'Mt. Pulag');
    expect(after.elevationM, 2928);
  });

  test('the count stream reports six', () async {
    expect(await dao.watchCount().first, 6);
  });

  test('a peak with a duplicate name is rejected', () async {
    expect(
      () => dao.add(MountainsCompanion.insert(name: 'Mt. Pulag')),
      throwsA(isA<Exception>()),
    );
  });
}
