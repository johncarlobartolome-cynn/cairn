import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/dev/theme_gallery.dart';
import 'package:cairn/shared/widgets/badge_tile.dart';
import 'package:cairn/shared/widgets/filter_pill_row.dart';
import 'package:cairn/shared/widgets/frosted_sheet.dart';
import 'package:cairn/shared/widgets/peak_card.dart';
import 'package:cairn/shared/widgets/pill_nav.dart';
import 'package:cairn/shared/widgets/section_label.dart';
import 'package:cairn/shared/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The gallery is the tool the design system is reviewed through, so it gets a
/// smoke test: it must boot, hold every widget, and flip brightness.
void main() {
  /// The catalogue scrolls, and a lazy list only builds what is on screen, so
  /// the surface is grown tall enough to build the whole thing at once.
  Future<void> pumpGallery(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 3400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ThemeGalleryApp());
    await tester.pumpAndSettle();
  }

  testWidgets('boots holding every widget in the kit', (tester) async {
    await pumpGallery(tester);

    expect(find.byType(SectionLabel), findsWidgets);
    expect(find.byType(FilterPillRow), findsOneWidget);
    expect(find.byType(PeakCard), findsNWidgets(2));
    expect(find.byType(StatTile), findsNWidgets(4));
    expect(find.byType(BadgeTile), findsNWidgets(3));
    expect(find.byType(FrostedSheet), findsOneWidget);
    expect(find.byType(PillNav), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a peak card in both states at once', (tester) async {
    await pumpGallery(tester);

    final cards = tester.widgetList<PeakCard>(find.byType(PeakCard)).toList();
    expect(cards.map((c) => c.climbed), containsAll([true, false]));
  });

  testWidgets('flips the whole gallery between light and dark', (tester) async {
    await pumpGallery(tester);

    Color background() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode ==
                ThemeMode.dark
            ? CairnPalette.dark.ground
            : CairnPalette.light.ground;

    expect(background(), CairnPalette.light.ground);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(background(), CairnPalette.dark.ground);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wraps its body in a SafeArea', (tester) async {
    await pumpGallery(tester);

    expect(
      find.descendant(
        of: find.byType(Scaffold),
        matching: find.byType(SafeArea),
      ),
      findsWidgets,
    );
  });
}
