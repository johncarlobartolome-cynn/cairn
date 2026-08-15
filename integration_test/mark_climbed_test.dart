// Runs on a device through `flutter drive`, never under `flutter test`:
//
//   flutter drive --device-id emulator-5554 \
//     --driver test_driver/integration_test.dart \
//     --target integration_test/mark_climbed_test.dart
//
// E3's bar is a climb that survives a force-quit, and a host test cannot prove
// that: `test/data/database/persistence_test.dart` reopens a file in the same
// process, which is as close as the harness gets. This one drives the real app
// on a real Android device, through the sheet, into the app's own
// `cairn.sqlite` in the documents directory.
//
// It leaves the row behind on purpose. Force-quit the app afterwards, reopen
// it, and read the row off the file with adb; that read is the evidence.

import 'package:cairn/app/app.dart';
import 'package:cairn/app/router.dart';
import 'package:cairn/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('marks a peak climbed on the device', (tester) async {
    // One container for the run, so the app under test and the assertions below
    // share a single connection to the file on the device.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final peaks = await container.read(mountainDaoProvider).getAll();
    expect(peaks, isNotEmpty, reason: 'the seed should have run');
    final peak = peaks.first;

    final before = await container.read(climbDaoProvider).getAll();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CairnApp(initialLocation: CairnRoute.mountain(peak.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark climbed'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'Mara and Enzo');
    await tester.enterText(
      fields.last,
      'Left at three in the morning and caught the sunrise from the summit.',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save climb'));
    await tester.pumpAndSettle();

    // The sheet closes on a save that landed, so its absence is the first
    // signal and the row is the second.
    expect(find.text('Save climb'), findsNothing);

    final after = await container.read(climbDaoProvider).getAll();
    expect(after, hasLength(before.length + 1));

    final saved = after.first;
    expect(saved.mountainId, peak.id);
    expect(saved.companions, 'Mara and Enzo');
    expect(saved.notes, isNotEmpty);

    final now = DateTime.now();
    expect(saved.date, DateTime.utc(now.year, now.month, now.day));

    // Printed so the run's log names the row that the adb read should find.
    // ignore: avoid_print
    print(
      'wrote climb id=${saved.id} mountainId=${saved.mountainId} '
      'date=${saved.date.toIso8601String()}',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
