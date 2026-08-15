import 'dart:io';

import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/database/tables/mountains.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// v2 seeded six peaks by name and left every other column null, because no
/// verified figures existed yet. v3 carries them. The seed cannot deliver them
/// on its own: it runs from `beforeOpen` only on the open that creates the file,
/// and that open already happened on every phone the app is installed on. So
/// this migration is the only route the figures have to an install that exists.
///
/// The DDL below is the real v2 schema, dumped from a database this app built,
/// not a hand-written approximation. Nothing about the tables changed in v3, so
/// the same dump is a faithful v2 and a faithful v3. `setup` lays it down and
/// stamps `user_version = 2`, so opening [AppDatabase] over the file takes the
/// upgrade path exactly as an existing phone would.
const _v2Ddl = [
  'CREATE TABLE IF NOT EXISTS "mountains" ("id" INTEGER NOT NULL PRIMARY KEY '
      'AUTOINCREMENT, "name" TEXT NOT NULL UNIQUE, "region" TEXT NULL, '
      '"elevation_m" INTEGER NULL, "difficulty" TEXT NULL, "jump_off_point" '
      'TEXT NULL, "estimated_hours" REAL NULL, "notes" TEXT NULL);',
  'CREATE TABLE IF NOT EXISTS "climbs" ("id" INTEGER NOT NULL PRIMARY KEY '
      'AUTOINCREMENT, "mountain_id" INTEGER NOT NULL REFERENCES mountains (id) '
      'ON DELETE CASCADE, "date" TEXT NOT NULL, "companions" TEXT NULL, '
      '"notes" TEXT NULL, "photo_filenames" TEXT NOT NULL DEFAULT \'[]\');',
  'CREATE TABLE IF NOT EXISTS "achievements" ("id" INTEGER NOT NULL PRIMARY KEY '
      'AUTOINCREMENT, "type" TEXT NOT NULL, "unlocked_at" INTEGER NOT NULL, '
      '"mountain_id" INTEGER NULL REFERENCES mountains (id) ON DELETE CASCADE);',
  'CREATE INDEX idx_climbs_mountain_id ON climbs (mountain_id);',
  'CREATE INDEX idx_climbs_date ON climbs (date);',
  'CREATE UNIQUE INDEX ux_achievements_peak ON achievements (type, mountain_id) '
      'WHERE mountain_id IS NOT NULL;',
  'CREATE UNIQUE INDEX ux_achievements_milestone ON achievements (type) '
      'WHERE mountain_id IS NULL;',
];

/// The library as a phone running v2 holds it, and every case the migration has
/// to tell apart.
///
/// Four peaks with a name and nothing else, which is what T4's seed wrote.
///
/// Kabunian arrives already carrying a region and an elevation, standing in for
/// a row someone has edited. Nothing in the app edits a peak yet, so this case
/// cannot happen in the wild today. It can from E3 onwards, and a migration
/// that overwrites user data is only ever discovered after it has overwritten
/// some.
///
/// Apo is the user's own peak. It is not curated, so the migration must not
/// know it exists.
///
/// Mariglem is deliberately missing. If it is back in the table afterwards then
/// the seed ran, which would mean the whole file was created rather than
/// upgraded, and every other assertion here would be certifying the seed
/// instead of the migration.
const _v2Rows = [
  "INSERT INTO mountains (name) VALUES ('Mt. Pulag'), ('Mt. Ulap'), "
      "('Mt. Batulao'), ('Mt. Daraitan');",
  // 'Mountain Province' is a real province and a wrong one for Kabunian, which
  // is the point: it has to differ from the curated 'Benguet' or the
  // no-clobber assertion below passes without the guard doing anything.
  'INSERT INTO mountains (name, region, elevation_m) '
      "VALUES ('Mt. Kabunian', 'Mountain Province', 1840);",
  'INSERT INTO mountains '
      '(name, region, elevation_m, difficulty, jump_off_point, '
      'estimated_hours, notes) '
      "VALUES ('Mt. Apo', 'Davao', 2954, 'hard', 'Kidapawan', 20.0, 'someday');",
];

final _v2Database = [..._v2Ddl, ..._v2Rows, 'PRAGMA user_version = 2;'];

void main() {
  late Directory dir;
  late AppDatabase db;
  late MountainDao dao;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cairn_migration_v3_test');
    db = AppDatabase(
      NativeDatabase(
        File('${dir.path}/cairn.sqlite'),
        setup: (rawDb) {
          for (final statement in _v2Database) {
            rawDb.execute(statement);
          }
        },
      ),
    );
    dao = MountainDao(db);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<Mountain> peak(String name) async =>
      (await dao.getAll()).firstWhere((p) => p.name == name);

  test('the upgrade lands on schema version 3', () async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();

    expect(row.read<int>('user_version'), 3);
  });

  test('a name-only peak comes out carrying every figure', () async {
    final pulag = await peak('Mt. Pulag');

    // Written out rather than read off the seed constant. A test that compares
    // the migration's output to the same list the migration wrote from passes
    // on a typo, which is how a wrong answer gets certified.
    expect(pulag.region, 'Benguet');
    expect(pulag.elevationM, 2922);
    expect(pulag.difficulty, Difficulty.easy);
    expect(pulag.jumpOffPoint, 'DENR Ambangeg Ranger Station, Bokod.');
    expect(pulag.estimatedHours, 4);

    // Not one lucky row: every name-only peak in the fixture fills.
    for (final name in ['Mt. Ulap', 'Mt. Batulao', 'Mt. Daraitan']) {
      final filled = await peak(name);

      expect(filled.region, isNotNull, reason: '$name region');
      expect(filled.elevationM, isNotNull, reason: '$name elevation');
      expect(filled.difficulty, isNotNull, reason: '$name difficulty');
      expect(filled.jumpOffPoint, isNotNull, reason: '$name jump-off');
      expect(filled.estimatedHours, isNotNull, reason: '$name hours');
    }
  });

  test('a value already in the row survives, and only the gaps fill', () async {
    final kabunian = await peak('Mt. Kabunian');

    // The fixture's own values, not the curated ones. Curated says 'Benguet'
    // and 1,789, so either of those appearing here is the migration writing
    // over something a person put in.
    expect(kabunian.region, 'Mountain Province');
    expect(kabunian.elevationM, 1840);

    // The columns that were empty still had to fill, or the guard is just
    // skipping the row.
    expect(kabunian.difficulty, Difficulty.moderate);
    expect(
      kabunian.jumpOffPoint,
      'Brgy. Poblacion, Bakun. Register at Bakun National High School or '
      'the Municipal Tourism Council.',
    );
    expect(kabunian.estimatedHours, 4);
  });

  test('a peak the user added is left exactly as it was', () async {
    final apo = await peak('Mt. Apo');

    expect(apo.region, 'Davao');
    expect(apo.elevationM, 2954);
    expect(apo.difficulty, Difficulty.hard);
    expect(apo.jumpOffPoint, 'Kidapawan');
    expect(apo.estimatedHours, 20.0);
    expect(apo.notes, 'someday');
  });

  test('the migration fills rows and never adds them', () async {
    final peaks = await dao.getAll();

    // Six went in, six come out. A curated peak the user deleted stays deleted,
    // and the seed did not run behind the migration's back.
    expect(peaks, hasLength(6));
    expect(peaks.map((p) => p.name), isNot(contains('Mt. Mariglem')));
  });

  test('the upgraded database still enforces foreign keys', () async {
    expect(
      () => db
          .into(db.climbs)
          .insert(
            ClimbsCompanion.insert(mountainId: 9999, date: DateTime(2026, 8, 11)),
          ),
      throwsA(isA<Exception>()),
    );
  });
}
