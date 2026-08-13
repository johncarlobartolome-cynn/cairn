// Runs on a device through `flutter drive`, never under `flutter test`. Use
// tool/screenshots.sh; it wires the driver that writes the PNGs to disk.
//
// One pass over every route in both themes, eight images. The app boots against
// the real database in the app documents directory, so the screens show whatever
// the app itself would show: today that means six seeded peaks, no climbs, and a
// climb detail that honestly renders its not-found branch.

import 'package:cairn/app/app.dart';
import 'package:cairn/app/router.dart';
import 'package:cairn/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// One image: a route, a theme, and the filename the driver writes.
class _Shot {
  const _Shot(this.name, this.location, this.themeMode);

  final String name;
  final String location;
  final ThemeMode themeMode;
}

/// How long a route gets to leave its loading spinner behind.
///
/// Generous: the first shot pays for the app's cold start and the database
/// opening. Running out is a failure, not a reason to capture the spinner.
const Duration _renderBudget = Duration(seconds: 20);

const Duration _pumpStep = Duration(milliseconds: 100);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every route renders in both themes', (tester) async {
    // Android draws Flutter into a surface the framework cannot read back. This
    // swaps it for an image view for the rest of the test. It asserts if called
    // twice, so all eight shots share one test.
    await binding.convertFlutterSurfaceToImage();

    // One container for the whole run, so the app and this test share a single
    // database connection and the ids below are the ids on screen.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final peaks = await container.read(mountainDaoProvider).getAll();
    if (peaks.isEmpty) {
      throw StateError(
        'The peaks library is empty, so /mountain/:id has nothing to open. '
        'The seed should have run when the database file was created.',
      );
    }
    final int peakId = peaks.first.id;

    // No climb exists yet, so id 1 misses and climb detail draws its not-found
    // branch. That is the screen as it stands. When E3 starts writing climbs the
    // harness picks up the real one with no edit here.
    final climbs = await container.read(climbDaoProvider).watchAll().first;
    final int climbId = climbs.isEmpty ? 1 : climbs.first.id;

    final shots = <_Shot>[
      for (final MapEntry<String, ThemeMode> theme in const {
        'light': ThemeMode.light,
        'dark': ThemeMode.dark,
      }.entries) ...<_Shot>[
        _Shot('peaks-${theme.key}', CairnRoute.peaks, theme.value),
        _Shot(
          'peak-detail-${theme.key}',
          CairnRoute.mountain(peakId),
          theme.value,
        ),
        _Shot(
          'climb-detail-${theme.key}',
          CairnRoute.climb(climbId),
          theme.value,
        ),
        _Shot('badges-${theme.key}', CairnRoute.badges, theme.value),
      ],
    ];

    for (final _Shot shot in shots) {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          // A fresh key per shot. `CairnApp` builds its router once in its state,
          // so reusing the key would keep the first location for every shot.
          child: CairnApp(
            key: ValueKey<String>(shot.name),
            initialLocation: shot.location,
            themeMode: shot.themeMode,
          ),
        ),
      );

      await _waitUntilRendered(tester, shot);
      await binding.takeScreenshot(shot.name);
    }

    // Let the drift streams close before the container goes, so the teardown does
    // not race the last frame.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(_pumpStep);
  });
}

/// Pumps until [shot]'s route is done loading, or fails saying which one hung.
///
/// The loading spinner is the one thing every screen shares while its stream is
/// still empty, so its absence is the signal that the route drew something real.
/// A route that throws surfaces here too, named, instead of arriving as a blank
/// image.
Future<void> _waitUntilRendered(WidgetTester tester, _Shot shot) async {
  final Finder spinner = find.byType(CircularProgressIndicator);
  final Stopwatch clock = Stopwatch()..start();

  while (clock.elapsed < _renderBudget) {
    await tester.pump(_pumpStep);

    final Object? error = tester.takeException();
    if (error != null) {
      throw StateError('${shot.location} threw while building: $error');
    }

    if (spinner.evaluate().isEmpty) {
      // Two more frames so the first painted frame is the settled one.
      await tester.pump(_pumpStep);
      await tester.pump(_pumpStep);
      return;
    }
  }

  throw StateError(
    '${shot.location} was still loading after ${_renderBudget.inSeconds}s, '
    'so ${shot.name}.png would have been a spinner.',
  );
}
