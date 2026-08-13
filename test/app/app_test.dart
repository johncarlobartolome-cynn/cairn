import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/features/peaks/peaks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

/// Covers the app's theme seam, the one the screenshot harness leans on: it names
/// a theme so a single run can capture both, rather than reaching for the device's
/// display settings between images.
void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  ThemeData themeOnScreen(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(PeaksScreen)));

  testWidgets('follows the device by default', (tester) async {
    await pumpApp(tester, db);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    // The test view reports light, so system resolves to the light palette.
    expect(themeOnScreen(tester).brightness, Brightness.light);

    await disposeApp(tester);
  });

  testWidgets('a named theme wins over the device setting', (tester) async {
    await pumpApp(tester, db, themeMode: ThemeMode.dark);

    final theme = themeOnScreen(tester);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, CairnPalette.dark.ground);

    await disposeApp(tester);
  });

  testWidgets('light stays light on a dark device', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester, db, themeMode: ThemeMode.light);

    final theme = themeOnScreen(tester);
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, CairnPalette.light.ground);

    await disposeApp(tester);
  });
}
