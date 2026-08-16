import 'package:cairn/app/app.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boots the real app against [db], opening at [location].
///
/// Pass a location to arrive somewhere the way a deep link would, rather than
/// tapping your way there.
///
/// The view is set to a phone rather than the harness default of 800x600. A peak
/// card is a 4:3 photo across the full width, so on the wider default view the
/// first card alone is taller than the window and nothing below it can be
/// tapped.
/// Extra provider overrides go on top of the database one, for a test that has
/// to control when a read answers rather than what it answers.
///
/// [physicalSize], [devicePixelRatio] and [padding] describe the phone. The
/// defaults are the plain one above; pass a real device's numbers when the test
/// is about how much of a screen something takes up, since that answer is
/// different on every handset.
Future<void> pumpApp(
  WidgetTester tester,
  AppDatabase db, {
  String location = '/',
  ThemeMode themeMode = ThemeMode.system,
  List<Override> overrides = const <Override>[],
  Size physicalSize = const Size(1080, 2340),
  double devicePixelRatio = 3,
  FakeViewPadding padding = FakeViewPadding.zero,
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.padding = padding;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db), ...overrides],
      child: CairnApp(initialLocation: location, themeMode: themeMode),
    ),
  );
  // First frame, then the frame carrying the database's first stream event.
  await tester.pump();
  await tester.pump();
}

/// Tears the app down inside the test.
///
/// Cancelling a Drift stream schedules a zero-duration cleanup timer, and
/// `flutter_test` fails the test if that timer is still pending when the harness
/// disposes the tree itself. A bare `pump()` only flushes microtasks, so the last
/// pump has to advance the fake clock.
Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}
