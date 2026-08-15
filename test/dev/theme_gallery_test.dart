import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/dev/theme_gallery.dart';
import 'package:cairn/shared/widgets/badge_tile.dart';
import 'package:cairn/shared/widgets/cairn_button.dart';
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
    // The primary button, live and disabled.
    expect(find.byType(CairnButton), findsNWidgets(2));
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

  testWidgets('reserves the clearance the nav asks for', (tester) async {
    await pumpGallery(tester);

    final listView = tester.widget<ListView>(find.byType(ListView));
    final padding = listView.padding!.resolve(TextDirection.ltr);
    final context = tester.element(find.byType(ListView));

    expect(padding.bottom, greaterThanOrEqualTo(PillNav.clearanceFor(context)));
  });

  testWidgets('scrolled to the end, the last content clears the nav', (
    tester,
  ) async {
    // Phone height, so the list genuinely scrolls rather than fitting at once.
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ThemeGalleryApp());
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView), const Offset(0, -8000), 5000);
    await tester.pumpAndSettle();

    // The gold swatch caption is the very last thing in the catalogue, so it is
    // the one that proves nothing is trapped behind the floating bar.
    final lastContent = tester.getRect(find.text('gold'));
    final navTop = tester.getRect(
      find
          .descendant(of: find.byType(PillNav), matching: find.byType(Material))
          .first,
    ).top;
    expect(lastContent.bottom, lessThanOrEqualTo(navTop));
  });
}
