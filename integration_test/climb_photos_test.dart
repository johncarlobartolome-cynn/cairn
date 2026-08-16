// Runs on a device through `flutter drive`, never under `flutter test`:
//
//   flutter drive --device-id emulator-5554 --keep-app-running \
//     --driver test_driver/integration_test.dart \
//     --target integration_test/climb_photos_test.dart
//
// Pass --keep-app-running. Without it the run uninstalls the app when it
// finishes, and an uninstalled app has no photos and no database left to prove
// anything with.
//
// What this covers and what it does not. The system photo picker is another
// process and no test on any device can tap it, so `photoPickerProvider` is
// overridden with a stub that paints an image, writes it to the same temporary
// directory image_picker writes to, and hands back the path image_picker would
// have handed back. Everything after that point is Cairn's own work: the copy
// into the documents directory, the name, the row, the render. That is the part
// that loses photos, and that is the part this drives.
//
// It leaves the climb and its files behind on purpose. Force-stop the app,
// reopen it, and read the row and the directory with adb; those reads are the
// evidence.

import 'package:cairn/app/app.dart';
import 'package:cairn/app/router.dart';
import 'package:cairn/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'painted_photo_picker.dart';

/// How many photos the stub picker hands over.
const int _photoCount = 2;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('attaches photos to a climb on the device', (tester) async {
    final picker = PaintedPhotoPicker(_photoCount);

    // One container for the run, so the app under test and the assertions below
    // share a single connection to the file on the device.
    final container = ProviderContainer(
      overrides: <Override>[photoPickerProvider.overrideWithValue(picker)],
    );
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

    // The photo row sits under the notes field, so on a phone it starts below
    // the fold.
    await tester.ensureVisible(find.text('Add photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add photos'));
    await tester.pumpAndSettle();

    expect(picker.openings, 1);

    await tester.ensureVisible(find.text('Save climb'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save climb'));
    await tester.pumpAndSettle();

    // The sheet closes on a save that landed.
    expect(find.text('Save climb'), findsNothing);

    final after = await container.read(climbDaoProvider).getAll();
    expect(after, hasLength(before.length + 1));

    final saved = after.first;
    expect(saved.mountainId, peak.id);
    expect(saved.photoFilenames, hasLength(_photoCount));

    // The rule, asserted against the row that is now in the file on the phone.
    for (final String name in saved.photoFilenames) {
      expect(name, isNot(contains('/')), reason: name);
      expect(name, isNot(contains(r'\')), reason: name);
      expect(name.startsWith('/'), isFalse, reason: name);
      expect(name, isNot(contains(':')), reason: name);
    }

    // Every stored name is a file that is really there, in the app's own
    // documents directory, resolved the way the widgets resolve it.
    final store = container.read(photoStoreProvider);
    for (final String name in saved.photoFilenames) {
      final String resolved = await store.resolve(name);
      // ignore: avoid_print
      print('photo $name resolves to $resolved');
    }

    // Printed so the run's log names the row the adb reads should find.
    // ignore: avoid_print
    print(
      'wrote climb id=${saved.id} mountainId=${saved.mountainId} '
      'date=${saved.date.toIso8601String()} '
      'photos=${saved.photoFilenames}',
    );

    // Open the climb the way a tap on the history row does, and confirm the
    // photos draw before the app is ever restarted.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CairnApp(
          key: const ValueKey<String>('climb-detail'),
          initialLocation: CairnRoute.climb(saved.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
