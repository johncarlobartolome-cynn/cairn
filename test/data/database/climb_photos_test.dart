import 'dart:convert';

import 'package:cairn/data/database/converters/photo_filenames_converter.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/photos/photo_filename.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

/// What actually reaches the `photo_filenames` column.
///
/// Read as raw text rather than through the converter, because the converter is
/// half of what is on trial. The same query runs against the device's real
/// `cairn.sqlite` as T17's evidence, so the shape asserted here is the shape
/// checked on the phone.
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

  /// Every `photo_filenames` cell in the file, exactly as SQLite holds it.
  Future<List<String>> rawColumn() async {
    final rows = await db
        .customSelect('SELECT photo_filenames FROM climbs ORDER BY id')
        .get();
    return <String>[
      for (final row in rows) row.read<String>('photo_filenames'),
    ];
  }

  test('a climb with no photos stores an empty list, not null', () async {
    await climbs.logClimb(mountainId: await pulagId(), date: DateTime(2026, 8));

    expect(await rawColumn(), <String>['[]']);
    expect((await climbs.getAll()).single.photoFilenames, isEmpty);
  });

  test('filenames go in and come back in the order they were picked', () async {
    const names = <String>[
      'climb_1755300000000001_a1b2c3d4.jpg',
      'climb_1755300000000002_e5f6a7b8.png',
      'climb_1755300000000003_c9d0e1f2.heic',
    ];

    await climbs.logClimb(
      mountainId: await pulagId(),
      date: DateTime(2026, 8),
      photoFilenames: names,
    );

    expect((await climbs.getAll()).single.photoFilenames, names);
  });

  test('nothing stored is a path', () async {
    // The assertion the whole ticket turns on, made against the file rather
    // than against the object graph. Repeated on the device by pulling
    // cairn.sqlite and running the same query.
    final int id = await pulagId();
    await climbs.logClimb(
      mountainId: id,
      date: DateTime(2026, 8),
      photoFilenames: const <String>['climb_1755300000000001_a1b2c3d4.jpg'],
    );
    await climbs.logClimb(mountainId: id, date: DateTime(2026, 8, 2));
    await climbs.logClimb(
      mountainId: id,
      date: DateTime(2026, 8, 3),
      photoFilenames: const <String>[
        'climb_1755300000000002_e5f6a7b8.png',
        'climb_1755300000000003_c9d0e1f2.heic',
      ],
    );

    for (final String cell in await rawColumn()) {
      for (final Object? value in jsonDecode(cell) as List<dynamic>) {
        final String name = value! as String;
        expect(
          isBarePhotoFilename(name),
          isTrue,
          reason: '$name says where it lives, so it will not be found later',
        );
        expect(name, isNot(contains('/')));
        expect(name, isNot(contains(r'\')));
        expect(name.startsWith('/'), isFalse);
      }
    }
  });

  group('the column refuses a path outright', () {
    for (final String path in <String>[
      '/data/user/0/com.cynnlabs.cairn/app_flutter/climb.jpg',
      'app_flutter/climb.jpg',
      '../climb.jpg',
      r'C:\photos\climb.jpg',
      'file:///tmp/climb.jpg',
      '',
    ]) {
      test('"$path"', () async {
        // Loud at save time beats quiet at reinstall time. A refused save is a
        // bug somebody fixes today; a stored path is a photo nobody can find
        // and nobody knows to look for.
        await expectLater(
          climbs.logClimb(
            mountainId: await pulagId(),
            date: DateTime(2026, 8),
            photoFilenames: <String>[path],
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(await climbs.getAll(), isEmpty);
      });
    }
  });

  test('one bad name in a list refuses the whole list', () async {
    await expectLater(
      climbs.logClimb(
        mountainId: await pulagId(),
        date: DateTime(2026, 8),
        photoFilenames: const <String>[
          'climb_1755300000000001_a1b2c3d4.jpg',
          '/tmp/sneaky.jpg',
        ],
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(await climbs.getAll(), isEmpty);
  });

  test('the converter round-trips on its own', () {
    const converter = PhotoFilenamesConverter();
    const names = <String>['a.jpg', 'b.png'];

    expect(converter.fromSql(converter.toSql(names)), names);
    expect(converter.toSql(const <String>[]), '[]');
    // A row written before the column had a default reads as no photos rather
    // than as a crash.
    expect(converter.fromSql(''), isEmpty);
  });
}
