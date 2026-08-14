import 'package:cairn/shared/widgets/cairn_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_widget.dart';

void main() {
  /// The colour the glyph is actually painted in, rather than the one handed to
  /// the button. A button resolves its foreground through an [IconTheme], so
  /// reading the icon's own `color` field would report null on a working button.
  Color? glyphColour(WidgetTester tester) => tester
      .widget<RichText>(
        find.descendant(
          of: find.byIcon(Icons.arrow_back_rounded),
          matching: find.byType(RichText),
        ),
      )
      .text
      .style
      ?.color;

  for (final brightness in Brightness.values) {
    testWidgets('draws the arrow in ink in ${brightness.name}', (tester) async {
      await pumpCairn(
        tester,
        const CairnBackButton(),
        brightness: brightness,
      );

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(glyphColour(tester), paletteFor(brightness).ink);
    });
  }

  testWidgets('is a full tap target, not a bare glyph', (tester) async {
    await pumpCairn(tester, const CairnBackButton());

    // The glyph is 22, so a 22 box would be well under the 48 minimum. The
    // button supplies the rest.
    final box = tester.getSize(find.byType(CairnBackButton));
    expect(box.width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(box.height, greaterThanOrEqualTo(kMinInteractiveDimension));
  });

  testWidgets('carries the platform back label for screen readers', (
    tester,
  ) async {
    await pumpCairn(tester, const CairnBackButton());

    expect(find.byTooltip('Back'), findsOneWidget);
  });
}
