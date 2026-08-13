import 'dart:io';

import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// v1 stored `climbs.date` as Unix epoch seconds. v2 stores the calendar day as
/// `YYYY-MM-DD` text, so the migration has to rewrite the column rather than
/// reinterpret it.
///
/// The DDL below is the real v1 schema, dumped from a v1 database built by this
/// app before the change, not a hand-written approximation. `setup` lays it down
/// and stamps `user_version = 1`, so opening [AppDatabase] over the file takes
/// the upgrade path exactly as a phone with the old build would.
const _v1Schema = [
  'CREATE TABLE IF NOT EXISTS "mountains" ("id" INTEGER NOT NULL PRIMARY KEY '
      'AUTOINCREMENT, "name" TEXT NOT NULL UNIQUE, "region" TEXT NULL, '
      '"elevation_m" INTEGER NULL, "difficulty" TEXT NULL, "jump_off_point" '
      'TEXT NULL, "estimated_hours" REAL NULL, "notes" TEXT NULL);',
  'CREATE TABLE IF NOT EXISTS "climbs" ("id" INTEGER NOT NULL PRIMARY KEY '
      'AUTOINCREMENT, "mountain_id" INTEGER NOT NULL REFERENCES mountains (id) '
      'ON DELETE CASCADE, "date" INTEGER NOT NULL, "companions" TEXT NULL, '
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
  "INSERT INTO mountains (name) VALUES ('Mt. Pulag'), ('Mt. Ulap');",
  // 00:30, 15:30 and 23:30 UTC on 11 August. Spread across the day on purpose:
  // under epoch storage the outer two are the ones that slide onto a
  // neighbouring day once a timezone is applied.
  'INSERT INTO climbs (mountain_id, date, notes) VALUES '
      "(1, strftime('%s','2026-08-11 00:30:00'), 'early'), "
      "(1, strftime('%s','2026-08-11 15:30:00'), 'midday'), "
      "(2, strftime('%s','2026-08-11 23:30:00'), 'late');",
  'PRAGMA user_version = 1;',
];

void main() {
  late Directory dir;
  late AppDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cairn_migration_test');
    db = AppDatabase(
      NativeDatabase(
        File('${dir.path}/cairn.sqlite'),
        setup: (rawDb) {
          for (final statement in _v1Schema) {
            rawDb.execute(statement);
          }
        },
      ),
    );
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('the upgrade lands on schema version 2', () async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();

    expect(row.read<int>('user_version'), 2);
  });

  test('every v1 epoch date becomes the calendar day it fell on', () async {
    final climbs = await ClimbDao(db).watchAll().first;

    expect(climbs, hasLength(3));
    for (final climb in climbs) {
      expect(climb.date, DateTime.utc(2026, 8, 11));
    }
  });

  test('the rewritten column holds text, not a number', () async {
    final rows = await db
        .customSelect('SELECT date, typeof(date) AS kind FROM climbs')
        .get();

    for (final row in rows) {
      expect(row.read<String>('date'), '2026-08-11');
      expect(row.read<String>('kind'), 'text');
    }
  });

  test('recreating the table keeps its rows, indexes and peaks', () async {
    expect(await MountainDao(db).getAll(), hasLength(2));

    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'climbs' AND sql IS NOT NULL",
        )
        .get();

    expect(
      indexes.map((r) => r.read<String>('name')),
      containsAll(['idx_climbs_mountain_id', 'idx_climbs_date']),
    );
  });

  test('the upgraded database still enforces foreign keys', () async {
    expect(
      () => ClimbDao(db).add(
        ClimbsCompanion.insert(mountainId: 9999, date: DateTime(2026, 8, 11)),
      ),
      throwsA(isA<Exception>()),
    );
  });
}
