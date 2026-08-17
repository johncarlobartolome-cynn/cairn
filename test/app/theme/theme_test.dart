import 'package:cairn/app/theme/theme.dart';
import 'package:cairn/app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the wiring, not the taste. If a Material widget stops inheriting
/// Cairn colour or type, these fail before a screen does.
void main() {
  group('ColorScheme carries the palette', () {
    test('light', () {
      final t = CairnTheme.light;
      const p = CairnPalette.light;

      expect(t.brightness, Brightness.light);
      expect(t.colorScheme.primary, p.accent);
      expect(t.colorScheme.secondary, p.brand);
      expect(t.colorScheme.tertiary, p.gold);
      expect(t.colorScheme.surface, p.surface);
      expect(t.colorScheme.onSurface, p.ink);
      expect(t.colorScheme.onSurfaceVariant, p.inkMuted);
      expect(t.colorScheme.outline, p.hairline);
      expect(t.colorScheme.shadow, p.accent);
      expect(t.scaffoldBackgroundColor, p.ground);
    });

    test('dark lifts green surfaces off a deep green ground', () {
      final t = CairnTheme.dark;
      const p = CairnPalette.dark;

      expect(t.brightness, Brightness.dark);
      expect(t.scaffoldBackgroundColor, p.ground);
      expect(t.colorScheme.surface, p.surface);
      // The translation rule: ground is darker than the cards on it.
      expect(
        p.ground.computeLuminance(),
        lessThan(p.surface.computeLuminance()),
      );
    });
  });

  group('TextTheme carries the type scale', () {
    test('every slot is Manrope', () {
      final text = CairnTheme.light.textTheme;
      final styles = [
        text.displayLarge,
        text.displayMedium,
        text.displaySmall,
        text.headlineLarge,
        text.headlineMedium,
        text.headlineSmall,
        text.titleLarge,
        text.titleMedium,
        text.titleSmall,
        text.bodyLarge,
        text.bodyMedium,
        text.bodySmall,
        text.labelLarge,
        text.labelMedium,
        text.labelSmall,
      ];

      for (final style in styles) {
        expect(style?.fontFamily, CairnType.family);
      }
      expect(CairnTheme.light.textTheme.bodyMedium?.fontSize, 15);
      expect(
        CairnTheme.light.textTheme.bodySmall?.color,
        CairnPalette.light.inkMuted,
      );
      expect(CairnTheme.light.textTheme.labelMedium?.letterSpacing, 1.2);
    });

    test('spec sizes and weights survive the mapping', () {
      expect(CairnType.displayLine1.fontSize, 32);
      expect(CairnType.displayLine1.fontWeight, FontWeight.w300);
      expect(CairnType.displayLine2.fontWeight, FontWeight.w500);
      expect(CairnType.screenTitle.fontSize, 22);
      expect(CairnType.sectionLabel.fontWeight, FontWeight.w600);
      expect(CairnType.statValue.fontSize, 20);
      expect(CairnType.statCaption.fontSize, 10);
      expect(CairnType.button.fontSize, 15);
    });
  });

  group('extensions', () {
    test('both themes register the palette and the type roles', () {
      for (final t in [CairnTheme.light, CairnTheme.dark]) {
        expect(t.extension<CairnColors>(), isNotNull);
        expect(t.extension<CairnTextStyles>(), isNotNull);
      }
      expect(
        CairnTheme.dark.extension<CairnColors>()!.palette,
        CairnPalette.dark,
      );
      expect(
        CairnTheme.light.extension<CairnTextStyles>()!.meta.color,
        CairnPalette.light.inkMuted,
      );
    });

    test('palette swaps whole rather than interpolating role by role', () {
      const light = CairnColors(CairnPalette.light);
      const dark = CairnColors(CairnPalette.dark);

      expect(light.lerp(dark, 0.2).palette, CairnPalette.light);
      expect(light.lerp(dark, 0.8).palette, CairnPalette.dark);
    });
  });

  group('the climbed treatment', () {
    test('unclimbed desaturation stays near a third', () {
      expect(CairnPeak.unclimbedSaturation, closeTo(0.3, 0.001));
    });

    test('a saturation of 1 is a no-op matrix', () {
      final filter = CairnPeak.saturation(1);
      expect(
        filter,
        const ColorFilter.matrix(<double>[
          1, 0, 0, 0, 0, //
          0, 1, 0, 0, 0, //
          0, 0, 1, 0, 0, //
          0, 0, 0, 1, 0, //
        ]),
      );
    });

    test('shadow is soft, wide and accent-tinted', () {
      final shadow = CairnShadow.card(CairnPalette.light.accent).single;
      expect(shadow.blurRadius, 24);
      expect(shadow.offset, const Offset(0, 8));
      expect(shadow.color.a, closeTo(0.08, 0.005));
    });

    test('the reveal is a wait and then a change', () {
      // Both halves are load-bearing. The wait is what lets the pop transition
      // get out of the way before the colour starts moving; without it the whole
      // change happens under a page that is still sliding in.
      expect(CairnPeak.reveal, const Duration(milliseconds: 650));
      expect(CairnPeak.revealCurve.transform(0), 0);
      expect(
        CairnPeak.revealCurve.transform(0.25),
        0,
        reason: 'the first quarter of the reveal is the wait',
      );
      expect(CairnPeak.revealCurve.transform(1), 1);
      expect(CairnPeak.markArrival, inExclusiveRange(0, 1));
    });
  });

  group('route motion', () {
    FadeForwardsPageTransitionsBuilder androidBuilder(ThemeData theme) =>
        theme.pageTransitionsTheme.builders[TargetPlatform.android]!
            as FadeForwardsPageTransitionsBuilder;

    test('a route slides and fades rather than zooming', () {
      // The pane behind a transition is cream, not the white that
      // ColorScheme.surface would have handed it.
      expect(
        androidBuilder(CairnTheme.light).backgroundColor,
        CairnPalette.light.ground,
      );
      expect(
        androidBuilder(CairnTheme.dark).backgroundColor,
        CairnPalette.dark.ground,
      );
    });

    test('a theme built twice is the same theme', () {
      // Not housekeeping. `CairnApp` builds a fresh ThemeData on every build and
      // `MaterialApp` animates into a theme it does not recognise, so a theme
      // that is never equal to itself means a 200ms lerp on every rebuild of the
      // app's root. Both theme extensions and the transitions theme carry the
      // equality that stops it.
      expect(CairnTheme.light, CairnTheme.light);
      expect(CairnTheme.dark, CairnTheme.dark);
      expect(CairnTheme.light, isNot(CairnTheme.dark));
    });
  });
}
