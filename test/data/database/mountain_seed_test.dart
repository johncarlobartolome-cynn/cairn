import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/database/seed/mountain_seed.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

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

  test('seeded peaks carry a name and nothing else', () async {
    for (final peak in await dao.getAll()) {
      expect(peak.name, isNotEmpty);
      expect(peak.region, isNull);
      expect(peak.elevationM, isNull);
      expect(peak.difficulty, isNull);
      expect(peak.jumpOffPoint, isNull);
      expect(peak.estimatedHours, isNull);
      expect(peak.notes, isNull);
    }
  });

  test('seeding again leaves six rows, not twelve', () async {
    await seedMountains(dao);
    await seedMountains(dao);

    expect(await dao.getAll(), hasLength(6));
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
