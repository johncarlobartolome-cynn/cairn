// Runs on a device through `flutter drive`, never under `flutter test`:
//
//   adb -s emulator-5554 shell screenrecord --time-limit 60 /sdcard/t26.mp4 &
//   flutter drive --device-id emulator-5554 --keep-app-running \
//     --driver test_driver/integration_test.dart \
//     --target integration_test/t26_motion_test.dart
//
// The whole point of this file is that the motion has to be watched rather than
// described. It walks the one path T26 is about, at the speed a thumb walks it:
// open a peak nobody has climbed, mark it climbed, read the acknowledgement, go
// back to the list, and watch the card gain its colour. Once in light and once
// in dark, so the reveal is judged in both palettes from one recording.
//
// The pauses are for the camera. They are the only reason a test would sit still
// on a settled screen, and they are what makes the recording legible at normal
// speed instead of a blur of taps.
//
// It runs against an in-memory library, so the emulator's own `cairn.sqlite` is
// neither read nor written. See t26_fixture.dart.

import 'package:cairn/app/app.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/providers.dart';
import 'package:cairn/shared/widgets/peak_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 't26_fixture.dart';

/// Long enough to read what is on screen at normal playback speed.
const Duration _beat = Duration(milliseconds: 1200);

/// Longer, for the two moments the recording exists to show: the sentence naming
/// the badges, and the card changing.
const Duration _hold = Duration(milliseconds: 2600);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('marking a peak climbed, from the action to the list', (
    tester,
  ) async {
    final AppDatabase db = fixtureDatabase();
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final List<Mountain> peaks = await MountainDao(db).getAll();
    expect(peaks, hasLength(6), reason: 'the fixture seeds the six');

    /// One pass: open the list, climb [peak], come back and watch the card.
    Future<void> walk(Mountain peak, ThemeMode theme, String tag) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: CairnApp(key: ValueKey<String>(tag), themeMode: theme),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(_beat);

      // The card as it stands: grey, no mark.
      final Finder card = find.ancestor(
        of: find.text(peak.name),
        matching: find.byType(PeakCard),
      );
      expect(card, findsOneWidget);

      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.pump(_beat);

      await tester.tap(find.text('Mark climbed'));
      await tester.pumpAndSettle();
      await tester.pump(_beat);

      await tester.ensureVisible(find.text('Save climb'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save climb'));
      await tester.pumpAndSettle();

      // The sheet is gone and the acknowledgement is up, naming what was
      // earned. Held, because six seconds on screen is no use if the recording
      // moves on after one.
      expect(find.text('Save climb'), findsNothing);
      expect(find.textContaining('You earned'), findsOneWidget);
      await tester.pump(_hold);

      // Back to the list, which is where the change lands.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pump(_hold);

      // And it landed: the card is climbed, in colour, with the mark on it.
      expect(
        find.descendant(of: card, matching: find.byType(ColorFiltered)),
        findsNothing,
        reason: '${peak.name} should be at full colour now',
      );
    }

    await walk(peaks[1], ThemeMode.light, 'light');
    await walk(peaks[3], ThemeMode.dark, 'dark');

    final List<Climb> logged = await ClimbDao(db).getAll();
    expect(logged, hasLength(2), reason: 'one climb per pass');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
