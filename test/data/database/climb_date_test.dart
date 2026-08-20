import 'package:cairn/data/database/converters/date_only_converter.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

/// A climb date is the calendar day of the hike, so it must not move when the
/// device timezone does.
///
/// The suite is run twice from the command line, once under `TZ=Pacific/Niue`
/// (UTC-11) and once under `TZ=Pacific/Kiritimati` (UTC+14), which is a 25-hour
/// spread. Nothing in here reads the local zone, so both runs assert the same
/// thing and a zone-dependent column fails at least one of them.
void main() {
  late AppDatabase db;
  late ClimbDao climbs;
  late MountainDao mountains;

  setUp(() {
    db = createTestDatabase();
    climbs = ClimbDao(db);
    mountains = MountainDao(db);
  });

  tearDown(() => db.close());

  Future<int> pulagId() async =>
      (await mountains.getAll()).firstWhere((p) => p.name == 'Mt. Pulag').id;

  Future<DateTime> roundTrip(DateTime date) async {
    final id = await pulagId();
    await climbs.add(ClimbsCompanion.insert(mountainId: id, date: date));
    final stored = (await climbs.watchAll().first).single;
    await climbs.deleteClimb(id: stored.id);
    return stored.date;
  }

  void expectDay(DateTime actual, int year, int month, int day) {
    expect(actual.year, year);
    expect(actual.month, month);
    expect(actual.day, day);
  }

  group('the converter', () {
    test('writes the calendar day and drops everything below it', () {
      const converter = DateOnlyConverter();

      expect(converter.toSql(DateTime(2026, 8, 11)), '2026-08-11');
      expect(converter.toSql(DateTime(2026, 8, 11, 23, 59, 59)), '2026-08-11');
      expect(converter.toSql(DateTime.utc(2026, 8, 11, 12)), '2026-08-11');
    });

    test('pads single-digit months and days', () {
      expect(
        const DateOnlyConverter().toSql(DateTime(2026, 1, 5)),
        '2026-01-05',
      );
    });

    test('reads a stored day back as UTC midnight', () {
      final read = const DateOnlyConverter().fromSql('2026-08-11');

      expect(read, DateTime.utc(2026, 8, 11));
      expect(read.isUtc, isTrue);
    });
  });

  group('a stored climb date', () {
    test('survives the round trip as the same calendar day', () async {
      expectDay(await roundTrip(DateTime(2026, 8, 11)), 2026, 8, 11);
    });

    test('holds for a hike logged just after local midnight', () async {
      // 00:30 local. Under epoch-second storage this lands on the previous day
      // in every zone east of UTC.
      expectDay(await roundTrip(DateTime(2026, 8, 11, 0, 30)), 2026, 8, 11);
    });

    test('holds for a hike logged just before local midnight', () async {
      // 23:30 local, which epoch-second storage pushes onto 12 August in every
      // zone west of UTC.
      expectDay(await roundTrip(DateTime(2026, 8, 11, 23, 30)), 2026, 8, 11);
    });

    test('holds across a year boundary', () async {
      expectDay(await roundTrip(DateTime(2026, 12, 31, 22)), 2026, 12, 31);
      expectDay(await roundTrip(DateTime(2027, 1, 1, 1)), 2027, 1, 1);
    });

    test('is stored on disk as YYYY-MM-DD text, not a number', () async {
      final id = await pulagId();
      await climbs.add(
        ClimbsCompanion.insert(
          mountainId: id,
          date: DateTime(2026, 8, 11, 17, 45),
          notes: const Value('Summit at first light.'),
        ),
      );

      // Raw SQL on purpose: the point of this assertion is the shape of the
      // value in the file, which a typed read would hide.
      final row = await db
          .customSelect('SELECT date, typeof(date) AS kind FROM climbs')
          .getSingle();

      expect(row.read<String>('date'), '2026-08-11');
      expect(row.read<String>('kind'), 'text');
    });

    test('orders newest first on the text column', () async {
      final id = await pulagId();
      for (final date in [
        DateTime(2025, 3, 9),
        DateTime(2026, 8, 11),
        DateTime(2026, 1, 2),
      ]) {
        await climbs.add(ClimbsCompanion.insert(mountainId: id, date: date));
      }

      final ordered = await climbs.watchAll().first;
      expect(ordered.map((c) => c.date), [
        DateTime.utc(2026, 8, 11),
        DateTime.utc(2026, 1, 2),
        DateTime.utc(2025, 3, 9),
      ]);
    });
  });
}
