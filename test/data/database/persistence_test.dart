import 'dart:io';

import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves rows survive the process, not just the test.
///
/// The in-memory tests would pass even if nothing were ever written to disk, so
/// this one uses a real file, closes the database, and opens a second
/// [AppDatabase] over the same file. That is the closest a host test gets to
/// force-quitting the app and reopening it, which is E3's tie-breaker.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cairn_persistence_test');
    file = File('${dir.path}/cairn.sqlite');
  });

  tearDown(() => dir.delete(recursive: true));

  test('seeded peaks and a logged climb survive close and reopen', () async {
    // Local, not UTC: drift stores a DateTime as Unix epoch seconds and reads
    // it back in the device's zone, so a local value round-trips exactly.
    final climbedOn = DateTime(2026, 8, 11);

    // First run: the file does not exist yet, so beforeOpen seeds it.
    final first = AppDatabase(NativeDatabase(file));
    final firstMountains = MountainDao(first);
    final peaks = await firstMountains.getAll();
    expect(peaks, hasLength(6));

    final pulag = peaks.firstWhere((p) => p.name == 'Mt. Pulag');
    await ClimbDao(first).add(
      ClimbsCompanion.insert(
        mountainId: pulag.id,
        date: climbedOn,
        notes: const Value('Sea of clouds at sunrise.'),
        companions: const Value('Solo'),
        photoFilenames: const Value(['pulag-summit.jpg']),
      ),
    );
    await first.close();

    expect(file.existsSync(), isTrue, reason: 'nothing was written to disk');

    // Second run over the same file: beforeOpen must not re-seed.
    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);

    final reread = await MountainDao(second).getAll();
    expect(reread, hasLength(6));
    expect(reread.map((p) => p.name), containsAll(['Mt. Pulag', 'Mt. Ulap']));

    final climbs = await ClimbDao(second).watchAll().first;
    expect(climbs, hasLength(1));
    expect(climbs.single.mountainId, pulag.id);
    expect(climbs.single.date, climbedOn);
    expect(climbs.single.notes, 'Sea of clouds at sunrise.');
    expect(climbs.single.photoFilenames, ['pulag-summit.jpg']);
  });
}
