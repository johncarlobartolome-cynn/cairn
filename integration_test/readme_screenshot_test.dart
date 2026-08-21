// Runs on a device through `flutter drive`, never under `flutter test`. Use
// `tool/screenshots.sh readme`; it wires the driver that writes the PNGs to
// disk.
//
// The pictures the README is built from, over a library seeded for the purpose.
// `screenshot_test.dart` is the sweep: every route, both themes, whatever the
// emulator's own database happens to hold. This is the opposite job. It shoots
// four screens over one deliberate state, because a README picture of six grey
// cards and a locked badge grid shows none of the work.
//
// Nothing here reads or writes `cairn.sqlite`, and nothing lands in the app's
// documents directory. See readme_fixture.dart for why, and for what the state
// actually is.
//
// Both themes are captured. The committed images are the light ones, because
// light is the app's default and three pictures is what the README wants; the
// dark pair is evidence, and it is how a theme regression gets noticed.

import 'package:cairn/app/app.dart';
import 'package:cairn/app/router.dart';
import 'package:cairn/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'readme_fixture.dart';

/// One image: a route, a theme, and the filename the driver writes.
class _Shot {
  const _Shot(this.name, this.location, this.themeMode);

  final String name;
  final String location;
  final ThemeMode themeMode;
}

/// How long a route gets to leave its loading spinner behind.
///
/// Generous: the first shot pays for the app's cold start. Running out is a
/// failure, not a reason to capture the spinner.
const Duration _renderBudget = Duration(seconds: 20);

const Duration _pumpStep = Duration(milliseconds: 100);

/// Frames between the route settling and the shutter.
///
/// More than the sweep's two, because one of these screens draws photographs off
/// the disk. A stored photo waits on the documents directory and then on the
/// image loader, and neither shows a spinner: the half-frame is a plain fill, so
/// firing early would produce a picture of an empty frame that looks like a
/// broken photo rather than a loading one.
const int _settleFrames = 15;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the README screens, over the seeded demo library', (
    tester,
  ) async {
    // Android draws Flutter into a surface the framework cannot read back. This
    // swaps it for an image view for the rest of the test. It asserts if called
    // twice, so all eight shots share one test.
    await binding.convertFlutterSurfaceToImage();

    final DemoLibrary demo = await seedDemoLibrary();

    // One container for the whole run, over the seeded library rather than the
    // device's own. The documents directory goes with it: a stored photo is a
    // bare filename resolved against whatever that provider answers, so
    // pointing it at the fixture's throwaway folder is what makes the seeded
    // photographs render without anything being written to the real one.
    final container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(demo.db),
        documentsDirectoryProvider.overrideWith((ref) async => demo.photos),
      ],
    );

    final shots = <_Shot>[
      for (final MapEntry<String, ThemeMode> theme in const {
        'light': ThemeMode.light,
        'dark': ThemeMode.dark,
      }.entries) ...<_Shot>[
        // The one that carries the whole idea: three of six in colour, three
        // washed out, and the count confirming it.
        _Shot('readme-peaks-${theme.key}', CairnRoute.peaks, theme.value),
        _Shot(
          'readme-peak-detail-${theme.key}',
          CairnRoute.mountain(demo.detailPeakId),
          theme.value,
        ),
        // Five earned against four locked, including a milestone, so the shape
        // that tells a milestone from a peak badge is on screen next to the
        // outline of one nobody has earned.
        _Shot('readme-badges-${theme.key}', CairnRoute.badges, theme.value),
        // Not a README image. It is the only screen that draws a stored
        // photograph, so it is how anyone checks what the seeded pictures
        // actually look like before trusting them anywhere else.
        _Shot(
          'readme-climb-detail-${theme.key}',
          CairnRoute.climb(demo.photoClimbId),
          theme.value,
        ),
      ],
    ];

    for (final _Shot shot in shots) {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          // A fresh key per shot. `CairnApp` builds its router once in its
          // state, so reusing the key would keep the first location for every
          // shot.
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

    // Let the drift streams close before the library goes, so the teardown does
    // not race the last frame.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(_pumpStep);
    container.dispose();
    // Closed here rather than by the container: the override handed the
    // database over as a value, so nothing else owns it.
    await demo.db.close();
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
      for (var frame = 0; frame < _settleFrames; frame++) {
        await tester.pump(_pumpStep);
      }
      return;
    }
  }

  throw StateError(
    '${shot.location} was still loading after ${_renderBudget.inSeconds}s, '
    'so ${shot.name}.png would have been a spinner.',
  );
}
