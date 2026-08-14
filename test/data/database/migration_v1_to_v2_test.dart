import 'dart:io';

import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// v1 stored `climbs.date` as Unix epoch seconds: the instant of a `DateTime`
/// the app built in local time. v2 stores the calendar day as `YYYY-MM-DD` text,
/// so the migration has to rewrite the column, and it has to read the old
/// instant in the zone that wrote it. Read as UTC, every hike logged before the
/// device's offset lands on the wrong day.
///
/// The DDL below is the real v1 schema, dumped from a v1 database built by this
/// app before the change, not a hand-written approximation. `setup` lays it down
/// and stamps `user_version = 1`, so opening [AppDatabase] over the file takes
/// the upgrade path exactly as a phone with the old build would.
const _v1Ddl = [
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
];

/// The v1 climb rows, built the way v1 built them: a local `DateTime`, whose
/// instant Drift wrote as epoch seconds. Deriving the fixture from a local time
/// is the whole point. A UTC-parsed literal would share its frame with a
/// UTC-reading migration and agree with it by construction, which is how the
/// wrong conversion passed a test in the first place.
///
/// All three name 11 August on the wall clock, so all three have to read back as
/// 11 August, in every zone. The spread is deliberate: 00:30 is the row that
/// slips back a day when the instant is read as UTC east of Greenwich, 23:30 is
/// the one that slips forward west of it, and 12:00 goes wrong past a 12-hour
/// offset either way.
final _v1Climbs = [
  (mountainId: 1, note: 'early', writtenAt: DateTime(2026, 8, 11, 0, 30)),
  (mountainId: 1, note: 'midday', writtenAt: DateTime(2026, 8, 11, 12)),
  (mountainId: 2, note: 'late', writtenAt: DateTime(2026, 8, 11, 23, 30)),
];

String _v1ClimbInsert(({int mountainId, String note, DateTime writtenAt}) c) {
  final epochSeconds = c.writtenAt.millisecondsSinceEpoch ~/ 1000;
  return 'INSERT INTO climbs (mountain_id, date, notes) '
      "VALUES (${c.mountainId}, $epochSeconds, '${c.note}');";
}

/// The v1 file in order: schema, peaks, climbs, then the stamp that sends the
/// next open down the upgrade path.
final _v1Database = [
  ..._v1Ddl,
  ..._v1Climbs.map(_v1ClimbInsert),
  'PRAGMA user_version = 1;',
];

/// The day a row was logged on, as the converter hands days back: UTC midnight.
DateTime _loggedDay(DateTime writtenAt) =>
    DateTime.utc(writtenAt.year, writtenAt.month, writtenAt.day);

void main() {
  late Directory dir;
  late AppDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cairn_migration_test');
    db = AppDatabase(
      NativeDatabase(
        File('${dir.path}/cairn.sqlite'),
        setup: (rawDb) {
          for (final statement in _v1Database) {
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

  test('every v1 instant becomes the day it was locally', () async {
    final climbs = await ClimbDao(db).watchAll().first;

    expect(climbs, hasLength(_v1Climbs.length));
    for (final row in _v1Climbs) {
      final migrated = climbs.firstWhere((c) => c.notes == row.note);

      expect(
        migrated.date,
        _loggedDay(row.writtenAt),
        reason:
            'the ${row.note} climb was logged at ${row.writtenAt} local, so it '
            'belongs to ${_loggedDay(row.writtenAt)} whatever the zone. Reading '
            'its instant as UTC gives '
            '${row.writtenAt.toUtc().toIso8601String()}, a different day.',
      );
    }
  });

  test('the rewritten column holds text, not a number', () async {
    final rows = await db
        .customSelect('SELECT date, typeof(date) AS kind FROM climbs')
        .get();

    // Every fixture row is local 11 August, so one expected string covers all
    // three in any zone.
    for (final row in rows) {
      expect(row.read<String>('date'), '2026-08-11');
      expect(row.read<String>('kind'), 'text');
    }
  });

  test('the recreated table redeclares date and keeps its indexes', () async {
    final columns = await db.customSelect('PRAGMA table_info(climbs)').get();
    final date = columns.singleWhere((c) => c.read<String>('name') == 'date');

    // v1 declared this column INTEGER, and nothing but the rewrite turns it into
    // TEXT. Asserting the declaration rather than an index name is what stops
    // this test passing on the fixture alone with the migration step skipped.
    expect(date.read<String>('type'), 'TEXT');

    // Recreating a table in SQLite takes its indexes down with it. Drift is
    // meant to put them back from the current schema, which is the part of
    // alterTable this checks.
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

    // An upgrade is not a create, so the seed must leave the two peaks the
    // fixture already holds alone.
    expect(await MountainDao(db).getAll(), hasLength(2));
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
