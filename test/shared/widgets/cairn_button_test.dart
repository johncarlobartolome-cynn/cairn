import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/shared/widgets/cairn_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_widget.dart';

void main() {
  testWidgets('shows its label and reports the press', (tester) async {
    var pressed = 0;

    await pumpCairn(
      tester,
      CairnButton(label: 'Mark climbed', onPressed: () => pressed++),
      width: 320,
    );

    expect(find.text('Mark climbed'), findsOneWidget);

    await tester.tap(find.byType(CairnButton));
    expect(pressed, 1);
  });

  testWidgets('fills the width it is handed', (tester) async {
    await pumpCairn(
      tester,
      const CairnButton(label: 'Save climb', onPressed: null),
      width: 320,
    );

    expect(tester.getSize(find.byType(FilledButton)).width, 320);
  });

  testWidgets('shrinks to its label when asked to', (tester) async {
    // No width here: the two are compared against each other, because a
    // SizedBox around either would size both the same and prove nothing.
    await pumpCairn(
      tester,
      const CairnButton(label: 'Save', onPressed: null, expand: false),
    );
    final shrunk = tester.getSize(find.byType(FilledButton)).width;

    await pumpCairn(tester, const CairnButton(label: 'Save', onPressed: null));

    expect(shrunk, lessThan(tester.getSize(find.byType(FilledButton)).width));
  });

  testWidgets('stands at least a full touch target tall', (tester) async {
    await pumpCairn(
      tester,
      CairnButton(label: 'Mark climbed', onPressed: () {}),
      width: 320,
    );

    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(CairnSize.control),
    );
  });

  testWidgets('takes its fill from the palette, both themes', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpCairn(
        tester,
        CairnButton(label: 'Mark climbed', onPressed: () {}),
        width: 320,
        brightness: brightness,
      );
      // MaterialApp animates a theme swap, and the Cairn palette flips at the
      // halfway point rather than blending, so the second pass has to let the
      // transition finish before it reads a colour.
      await tester.pumpAndSettle();

      final style = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        style.style?.backgroundColor?.resolve(<WidgetState>{}),
        paletteFor(brightness).brand,
      );
      expect(
        style.style?.foregroundColor?.resolve(<WidgetState>{}),
        paletteFor(brightness).onBrand,
      );
    }
  });

  testWidgets('a null callback leaves nothing to press', (tester) async {
    await pumpCairn(
      tester,
      const CairnButton(label: 'Mark climbed', onPressed: null),
      width: 320,
    );

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isFalse,
    );
  });

  testWidgets('busy shows a spinner and swallows the press', (tester) async {
    // The sheet's second-tap guard. A save in flight must not be able to write
    // a second row because someone pressed again.
    var pressed = 0;

    await pumpCairn(
      tester,
      CairnButton(label: 'Save climb', busy: true, onPressed: () => pressed++),
      width: 320,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(CairnButton), warnIfMissed: false);
    await tester.pump();

    expect(pressed, 0);
    // Still says what it is doing. A spinner with no label is a button that has
    // forgotten what it was for.
    expect(find.text('Save climb'), findsOneWidget);
  });

  testWidgets('a long label wraps instead of being cut short', (tester) async {
    // Ellipsis is a bug, not a fallback, and a button is the one place a
    // designer is tempted to allow it.
    const label = 'Mark this peak climbed and save the day';

    await pumpCairn(
      tester,
      const CairnButton(label: label, onPressed: null),
      width: 200,
    );

    final paragraph = tester.renderObject<RenderParagraph>(find.text(label));

    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.size.height, greaterThan(paragraph.preferredLineHeight));
    expect(tester.takeException(), isNull);
  });
}
