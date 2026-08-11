import 'package:cairn/app/theme/theme.dart';
import 'package:cairn/app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a shared widget inside the real Cairn theme.
///
/// The kit reads its colours and type from theme extensions, so a bare
/// `pumpWidget` would exercise the fallback path instead of the shipped one.
///
/// [width] constrains the widget, which is how the narrow-width layout tests
/// squeeze a tile. [safeAreaInset] fakes a gesture bar, for the nav's
/// safe-area behaviour.
Future<void> pumpCairn(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  double? width,
  EdgeInsets? safeAreaInset,
  Alignment alignment = Alignment.center,
}) async {
  Widget body = child;
  if (width != null) {
    body = SizedBox(width: width, child: body);
  }
  body = Align(alignment: alignment, child: body);

  final inset = safeAreaInset;
  if (inset != null) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        // Copied, not constructed, so size and text scaling stay real.
        data: MediaQuery.of(context).copyWith(
          padding: inset,
          viewPadding: inset,
        ),
        child: inner,
      ),
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? CairnTheme.dark : CairnTheme.light,
      home: Scaffold(body: body),
    ),
  );
}

/// The palette a widget pumped at [brightness] will be reading.
CairnPalette paletteFor(Brightness brightness) =>
    brightness == Brightness.dark ? CairnPalette.dark : CairnPalette.light;
