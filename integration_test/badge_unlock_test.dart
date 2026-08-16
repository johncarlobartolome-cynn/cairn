// Runs on a device through `flutter drive`, never under `flutter test`:
//
//   flutter drive --device-id emulator-5554 --keep-app-running \
//     --driver test_driver/integration_test.dart \
//     --target integration_test/badge_unlock_test.dart
//
// Pass --keep-app-running. Without it the run uninstalls the app when it
// finishes, and an uninstalled app has no `cairn.sqlite` left to read the
// badges out of.
//
// The host tests prove the rule against an in-memory database seeded a line
// earlier. This drives the real sheet on a real Android device and leaves the
// badge rows in the app's own file, where adb can read them back without
// asking Dart anything.
//
// It works off whatever the device already holds rather than a fixture: it
// climbs every peak that has no climb yet, one at a time, and checks the badge
// set after each save. So the assertions are written against counts read from
// the file, not against a number typed here.

import 'package:cairn/app/app.dart';
import 'package:cairn/app/router.dart';
import 'package:cairn/data/database/daos/achievement_dao.dart';
import 'package:cairn/data/database/tables/achievements.dart';
import 'package:cairn/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// How many different peaks the halfway milestone asks for.
///
/// Written out here rather than imported, so the test states the rule instead
/// of agreeing with whatever the code currently says.
const int _halfway = 3;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unlocks badges on the device as peaks are climbed', (
    tester,
  ) async {
    // One container for the run, so the app under test and the assertions below
    // share a single connection to the file on the device.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mountainDao = container.read(mountainDaoProvider);
    final climbDao = container.read(climbDaoProvider);
    final AchievementDao badges = container.read(achievementDaoProvider);

    final peaks = await mountainDao.getAll();
    expect(peaks, isNotEmpty, reason: 'the seed should have run');

    Future<Set<AchievementType>> milestones() async => (await badges.getAll())
        .where((a) => a.mountainId == null)
        .map((a) => a.type)
        .toSet();

    Future<List<int>> peaksWithABadge() async => (await badges.getAll())
        .where((a) => a.type == AchievementType.perMountain)
        .map((a) => a.mountainId!)
        .toList();

    /// Opens a peak, taps through the sheet, saves. The whole path a thumb
    /// takes, so nothing here writes a row on the test's behalf.
    Future<void> markClimbed(Mountain peak, String tag) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: CairnApp(
            key: ValueKey<String>(tag),
            initialLocation: CairnRoute.mountain(peak.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark climbed'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save climb'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save climb'));
      await tester.pumpAndSettle();

      // The sheet closes on a save that landed.
      expect(find.text('Save climb'), findsNothing);
    }

    final climbedAtStart = await climbDao.countClimbedMountains();
    // ignore: avoid_print
    print(
      'before: ${peaks.length} peaks in the library, '
      '$climbedAtStart of them climbed, '
      '${(await badges.getAll()).length} badges',
    );

    final climbedIds = (await climbDao.getAll())
        .map((c) => c.mountainId)
        .toSet();
    final todo = peaks.where((p) => !climbedIds.contains(p.id)).toList();
    expect(
      todo,
      isNotEmpty,
      reason: 'nothing left to climb, so this run would prove nothing',
    );

    for (final peak in todo) {
      await markClimbed(peak, 'first-${peak.id}');

      final climbed = await climbDao.countClimbedMountains();

      expect(
        await peaksWithABadge(),
        contains(peak.id),
        reason: '${peak.name} was climbed and has no badge',
      );
      expect(
        (await peaksWithABadge()).where((id) => id == peak.id),
        hasLength(1),
        reason: 'one badge per peak, never two',
      );

      final reached = await milestones();
      expect(reached, contains(AchievementType.firstClimb));
      expect(
        reached.contains(AchievementType.threePeaks),
        climbed >= _halfway,
        reason: '$climbed peaks climbed',
      );
      expect(
        reached.contains(AchievementType.allPeaks),
        climbed >= peaks.length,
        reason: '$climbed of ${peaks.length} peaks climbed',
      );

      // ignore: avoid_print
      print(
        'climbed ${peak.name}: $climbed of ${peaks.length} peaks, '
        'milestones ${reached.map((t) => t.name).toList()}',
      );
    }

    // Every peak now has a climb, so the last milestone has to be in.
    expect(await milestones(), contains(AchievementType.allPeaks));

    // The same peak again. Nothing new can unlock, and the rows already there
    // must be the same rows rather than fresh ones wearing the same names.
    final before = await badges.getAll();
    await markClimbed(todo.last, 'again-${todo.last.id}');
    final after = await badges.getAll();

    expect(after, hasLength(before.length));
    expect(after.map((a) => a.id), unorderedEquals(before.map((a) => a.id)));
    expect(
      after.map((a) => a.unlockedAt),
      unorderedEquals(before.map((a) => a.unlockedAt)),
      reason: 'a re-unlock would have restamped the row',
    );

    for (final badge in after) {
      // ignore: avoid_print
      print(
        'badge id=${badge.id} type=${badge.type.name} '
        'mountainId=${badge.mountainId} '
        'unlockedAt=${badge.unlockedAt.toIso8601String()}',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
