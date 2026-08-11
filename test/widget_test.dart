import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/database/seed/mountain_seed.dart';
import 'package:cairn/data/providers.dart';
import 'package:cairn/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    // Opens the database and runs the seed before the first frame, so the
    // widget's first stream event already carries rows.
    await MountainDao(db).getAll();
  });

  tearDown(() => db.close());

  testWidgets('the debug list renders the six seeded peaks from the database', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const CairnApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(SafeArea), findsWidgets);
    expect(find.byType(ListTile), findsNWidgets(seededPeakNames.length));
    for (final name in seededPeakNames) {
      expect(find.text(name), findsOneWidget);
    }

    // Tear the tree down inside the test. Cancelling a Drift stream schedules a
    // zero-duration cleanup timer, and flutter_test fails the test if that timer
    // is still pending once the harness disposes the tree itself. A bare pump()
    // only flushes microtasks, so the pump below has to advance fake time.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
