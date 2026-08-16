// Runs on a device through `flutter drive`, never under `flutter test`. Use
// tool/screenshots.sh; it wires the driver that writes the PNGs to disk.
//
// One pass over every route in both themes. The app boots against the real
// database in the app documents directory, so the screens show whatever the app
// itself would show: the six seeded peaks, and whatever climbs and photos are
// actually logged on the device.

import 'package:cairn/app/app.dart';
import 'package:cairn/app/router.dart';
import 'package:cairn/data/providers.dart';
import 'package:cairn/features/peaks/peaks_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'painted_photo_picker.dart';

/// One image: a route, a theme, and the filename the driver writes.
class _Shot {
  const _Shot(this.name, this.location, this.themeMode, {this.prepare});

  final String name;
  final String location;
  final ThemeMode themeMode;

  /// Optional taps and typing between the route settling and the shutter, for
  /// a shot of something you have to open first.
  final Future<void> Function(WidgetTester tester)? prepare;
}

/// Opens the mark-climbed sheet over peak detail, fills it in, and attaches a
/// photo to it.
///
/// Nothing is saved. The harness runs over the app's real database and a shot
/// is not a reason to write a row into it. The photos clear up after themselves
/// too: the draft deletes copies it was never told to keep, and the next shot
/// pumping a fresh app is what disposes it.
Future<void> _openFilledSheet(WidgetTester tester) async {
  await tester.tap(find.text('Mark climbed'));
  await tester.pumpAndSettle();

  final Finder fields = find.byType(TextField);
  await tester.enterText(fields.first, 'Mara and Enzo');
  await tester.enterText(
    fields.last,
    'Left at three in the morning and caught the sunrise from the summit.',
  );

  // The device's own keyboard answers the focus, and it would cover the half of
  // the sheet the shot is for.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.text('Add photos'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add photos'));
  await tester.pumpAndSettle();
}

/// Taps the Climbed pill on the peaks list.
///
/// The filter is UI state and nothing is written, so this leaves the app's
/// database exactly as it found it. The shot is of the grid answering a
/// question, which is the whole of what T20 added.
Future<void> _filterToClimbed(WidgetTester tester) async {
  await tester.tap(find.text('Climbed'));
  await tester.pumpAndSettle();
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
    //
    // The picker is stood in for because it is another process and no test can
    // tap it. Everything the shot is of, the thumbnails and the copies behind
    // them, is the app's own code.
    final container = ProviderContainer(
      overrides: <Override>[
        photoPickerProvider.overrideWithValue(PaintedPhotoPicker(2)),
      ],
    );
    addTearDown(container.dispose);

    final peaks = await container.read(mountainDaoProvider).getAll();
    if (peaks.isEmpty) {
      throw StateError(
        'The peaks library is empty, so /mountain/:id has nothing to open. '
        'The seed should have run when the database file was created.',
      );
    }
    final int peakId = peaks.first.id;

    // The most recently logged climb that has photographs on it, because that
    // is the screen worth photographing. `getAll` orders by date, and several
    // climbs on one day tie, so the id breaks the tie rather than SQLite's
    // arbitrary ordering: a screenshot run should not photograph a different
    // climb each time it is run.
    //
    // With no climbs at all, id 1 misses and climb detail draws its not-found
    // branch, which is honestly the screen as it stands.
    final climbs = await container.read(climbDaoProvider).getAll();
    final withPhotos = climbs
        .where((climb) => climb.photoFilenames.isNotEmpty)
        .toList();
    final pool = withPhotos.isEmpty ? climbs : withPhotos;
    final int climbId = pool.fold<int>(
      1,
      (newest, climb) => climb.id > newest ? climb.id : newest,
    );

    final shots = <_Shot>[
      for (final MapEntry<String, ThemeMode> theme in const {
        'light': ThemeMode.light,
        'dark': ThemeMode.dark,
      }.entries) ...<_Shot>[
        _Shot('peaks-${theme.key}', CairnRoute.peaks, theme.value),
        _Shot(
          'peaks-climbed-${theme.key}',
          CairnRoute.peaks,
          theme.value,
          prepare: _filterToClimbed,
        ),
        _Shot(
          'peak-detail-${theme.key}',
          CairnRoute.mountain(peakId),
          theme.value,
        ),
        _Shot(
          'mark-climbed-${theme.key}',
          CairnRoute.mountain(peakId),
          theme.value,
          prepare: _openFilledSheet,
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
      // One container serves the whole run, so UI state set by a shot is still
      // set for the next one. The peaks filter proved it: tapping Climbed for
      // one image left every later peaks shot filtered, and the two dark images
      // came out byte for byte identical. A shot has to be of the state it
      // names, so the filter goes back to All before each one.
      container.invalidate(peakFilterProvider);

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
      await shot.prepare?.call(tester);
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
