import 'dart:math' as math;

import 'package:cairn/app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every foreground and background the app actually puts on screen, measured
/// against WCAG AA in both themes.
///
/// **T8's review said outright that it eyeballed both themes and never computed
/// a number, and nobody did until T22.** Four tokens moved as a result. This
/// file is what stops that being a one-off: the pairs live here, so a palette
/// edit that costs somebody a line of text fails a test instead of shipping.
///
/// Run it with `--reporter expanded` and the test names are the table. Each
/// pair's measured ratio is in its own name, because a number that only exists
/// inside an assertion is a number nobody reads.
///
/// **The list is of pairs that occur, not of tokens that exist.** Checking a
/// palette in the abstract answers a question nobody asked: `inkMuted` is fine
/// on white and was failing on the emphasised stat tile, and only one of those
/// is a screen.
void main() {
  for (final palette in <CairnPalette>[CairnPalette.light, CairnPalette.dark]) {
    final theme = palette.isDark ? 'dark' : 'light';

    group(theme, () {
      for (final pair in renderedPairs(palette)) {
        final ratio = pair.ratio;
        final rounded = ratio.toStringAsFixed(2);

        test('${pair.where}: ${pair.pair} is $rounded to 1', () {
          final bar = pair.rule.minimum;

          if (bar == null) {
            // A pair with no bar has to say why in its own words. That is the
            // whole guard: an exemption cannot be added silently, and reading
            // the list tells you which parts of the design are carrying
            // information and which are carrying atmosphere.
            expect(
              pair.why,
              isNotEmpty,
              reason:
                  '${pair.where} claims no contrast bar and gives no reason '
                  'for it. Say why the pair carries no information, or give it '
                  'a rule.',
            );
            return;
          }

          expect(
            ratio,
            greaterThanOrEqualTo(bar),
            reason:
                '${pair.where} in $theme: ${pair.pair} measures $rounded to 1 '
                'and ${pair.rule.name} needs $bar to 1.',
          );
        });
      }
    });
  }

  test('every pair names where it happens', () {
    for (final pair in renderedPairs(CairnPalette.light)) {
      expect(pair.where, isNotEmpty);
      expect(pair.pair, isNotEmpty);
    }
  });

  test('the ratio is the WCAG one, both ways round', () {
    // Contrast has no direction, and the formula is the framework's own
    // relative luminance rather than one written here, so the numbers above are
    // not resting on arithmetic invented for this file.
    const white = Color(0xFFFFFFFF);
    const black = Color(0xFF000000);
    expect(contrastRatio(white, black), closeTo(21, 0.01));
    expect(contrastRatio(black, white), closeTo(21, 0.01));
    expect(contrastRatio(white, white), closeTo(1, 0.001));
  });
}

/// What a pair has to reach, and why that is the number.
enum ContrastRule {
  /// 1.4.3. Anything under 18pt, or under 14pt bold, which is every text role
  /// in the app except the 32pt greeting.
  bodyText(4.5),

  /// 1.4.3. 18pt and up. Only the greeting qualifies.
  largeText(3),

  /// 1.4.11. A shape or a glyph a reader has to make out to understand the
  /// screen: a badge silhouette, an icon, the filled part of a progress bar.
  meaningfulGraphic(3),

  /// No bar, and the pair has to say why. Decoration, or information that is
  /// also written out in words within a glance of it.
  decorative(null);

  const ContrastRule(this.minimum);

  final double? minimum;
}

/// One pair, at one place on one screen.
@immutable
class ContrastPair {
  const ContrastPair({
    required this.where,
    required this.pair,
    required this.foreground,
    required this.background,
    required this.rule,
    this.why = '',
  });

  /// The screen and the element, in the words somebody would use out loud.
  final String where;

  /// The two token names, for the table.
  final String pair;

  final Color foreground;
  final Color background;
  final ContrastRule rule;

  /// Required when [rule] is [ContrastRule.decorative].
  final String why;

  double get ratio => contrastRatio(foreground, background);
}

/// The WCAG 2.1 contrast ratio between two opaque colours.
///
/// Composite anything translucent with [Color.alphaBlend] before it gets here.
/// A ratio against a colour that is partly see-through is a ratio against a
/// background that was never named.
double contrastRatio(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

/// Every pair the app renders, in [palette].
///
/// Grouped by the screen it happens on rather than by token, because that is
/// how a failure is found and fixed.
List<ContrastPair> renderedPairs(CairnPalette p) {
  // Two translucent foregrounds are laid onto their background first, so the
  // number below is the colour a reader's eye actually receives.
  final navInactive = Color.alphaBlend(
    p.onBrand.withValues(alpha: 0.7),
    p.brand,
  );

  return <ContrastPair>[
    // ---- Type on the page ----
    ContrastPair(
      where: 'Greeting on the peaks and badges screens',
      pair: 'ink on ground',
      foreground: p.ink,
      background: p.ground,
      rule: ContrastRule.largeText,
    ),
    ContrastPair(
      where: 'Section label above a group',
      pair: 'inkMuted on ground',
      foreground: p.inkMuted,
      background: p.ground,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Progress tally beside the greeting',
      pair: 'inkMuted on ground',
      foreground: p.inkMuted,
      background: p.ground,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Text button label',
      pair: 'accent on ground',
      foreground: p.accent,
      background: p.ground,
      rule: ContrastRule.bodyText,
    ),

    // ---- Type on a card ----
    ContrastPair(
      where: 'Climbed peak name on its card footer',
      pair: 'ink on surface',
      foreground: p.ink,
      background: p.surface,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Unclimbed peak name on its card footer',
      pair: 'inkMuted on surface',
      foreground: p.inkMuted,
      background: p.surface,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Meta row under a peak name',
      pair: 'inkMuted on surface',
      foreground: p.inkMuted,
      background: p.surface,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Badge tile label, earned',
      pair: 'ink on surface',
      foreground: p.ink,
      background: p.surface,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Badge tile label and condition, locked',
      pair: 'inkMuted on surface',
      foreground: p.inkMuted,
      background: p.surface,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Empty-state message',
      pair: 'inkMuted on surface',
      foreground: p.inkMuted,
      background: p.surface,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Unselected filter pill label',
      pair: 'inkMuted on surface',
      foreground: p.inkMuted,
      background: p.surface,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Failure line in a sheet',
      pair: 'error on surface',
      foreground: p.error,
      background: p.surface,
      rule: ContrastRule.bodyText,
    ),

    // ---- Type in a tile or a field ----
    ContrastPair(
      where: 'Stat value in a tile',
      pair: 'ink on surfaceAlt',
      foreground: p.ink,
      background: p.surfaceAlt,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Stat caption in a tile',
      pair: 'inkMuted on surfaceAlt',
      foreground: p.inkMuted,
      background: p.surfaceAlt,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Stat value in the emphasised tile',
      pair: 'ink on accentSoft',
      foreground: p.ink,
      background: p.accentSoft,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Stat caption in the emphasised tile',
      pair: 'inkMuted on accentSoft',
      foreground: p.inkMuted,
      background: p.accentSoft,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Tap field label',
      pair: 'ink on surfaceAlt',
      foreground: p.ink,
      background: p.surfaceAlt,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Text field hint',
      pair: 'inkMuted on surfaceAlt',
      foreground: p.inkMuted,
      background: p.surfaceAlt,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Climb date in the history list',
      pair: 'ink on surfaceAlt',
      foreground: p.ink,
      background: p.surfaceAlt,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Missing-photo message',
      pair: 'inkMuted on surfaceAlt',
      foreground: p.inkMuted,
      background: p.surfaceAlt,
      rule: ContrastRule.bodyText,
    ),

    // ---- Type on a brand fill ----
    ContrastPair(
      where: 'Selected filter pill label',
      pair: 'onBrand on brand',
      foreground: p.onBrand,
      background: p.brand,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Primary button label',
      pair: 'onBrand on brand',
      foreground: p.onBrand,
      background: p.brand,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Snack bar message',
      pair: 'onBrand on brand',
      foreground: p.onBrand,
      background: p.brand,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Active nav item label',
      pair: 'brand on onBrand',
      foreground: p.brand,
      background: p.onBrand,
      rule: ContrastRule.bodyText,
    ),
    ContrastPair(
      where: 'Inactive nav item label',
      pair: 'onBrand at 70% on brand',
      foreground: navInactive,
      background: p.brand,
      rule: ContrastRule.bodyText,
    ),

    // ---- Badges, where the shape is the information ----
    ContrastPair(
      where: 'Earned peak badge disc against its card',
      pair: 'brand on surface',
      foreground: p.brand,
      background: p.surface,
      rule: ContrastRule.meaningfulGraphic,
    ),
    ContrastPair(
      where: 'Earned milestone seal against its card',
      pair: 'gold on surface',
      foreground: p.gold,
      background: p.surface,
      rule: ContrastRule.meaningfulGraphic,
    ),
    ContrastPair(
      where: 'Locked badge outline and glyph',
      pair: 'inkMuted on surface',
      foreground: p.inkMuted,
      background: p.surface,
      rule: ContrastRule.meaningfulGraphic,
    ),
    ContrastPair(
      where: 'Glyph inside an earned peak badge',
      pair: 'onBrand on brand',
      foreground: p.onBrand,
      background: p.brand,
      rule: ContrastRule.meaningfulGraphic,
    ),
    ContrastPair(
      where: 'Glyph inside an earned milestone seal',
      pair: p.isDark ? 'ground on gold' : 'ink on gold',
      foreground: p.isDark ? p.ground : p.ink,
      background: p.gold,
      rule: ContrastRule.meaningfulGraphic,
    ),
    // The climbed mark is the app's most important graphic and the only one
    // that lands on a photograph, where there is no background to measure
    // against. Its ring is the answer: the mark's edge is two colours far apart,
    // so a picture would have to fail against both to hide it. Both pairs are
    // measured, the ring against its own disc and the ring against what the app
    // draws behind it today.
    ContrastPair(
      where: 'Climbed mark ring against its own disc',
      pair: 'onBrand on brand',
      foreground: p.onBrand,
      background: p.brand,
      rule: ContrastRule.meaningfulGraphic,
    ),
    ContrastPair(
      where: 'Climbed mark ring against the photo placeholder',
      pair: 'onBrand on peakPlaceholderClimbed',
      foreground: p.onBrand,
      background: p.peakPlaceholderClimbed,
      rule: ContrastRule.meaningfulGraphic,
    ),

    // ---- Other glyphs and bars ----
    ContrastPair(
      where: 'Leading glyph in a stat tile or a tap field',
      pair: 'accent on surfaceAlt',
      foreground: p.accent,
      background: p.surfaceAlt,
      rule: ContrastRule.meaningfulGraphic,
    ),
    ContrastPair(
      where: 'Trailing chevron in a tap field',
      pair: 'inkMuted on surfaceAlt',
      foreground: p.inkMuted,
      background: p.surfaceAlt,
      rule: ContrastRule.meaningfulGraphic,
    ),
    ContrastPair(
      where: 'Filled part of the progress bar against its track',
      pair: 'accent on accentSoft',
      foreground: p.accent,
      background: p.accentSoft,
      rule: ContrastRule.meaningfulGraphic,
    ),
    ContrastPair(
      where: 'Active nav glyph',
      pair: 'brand on onBrand',
      foreground: p.brand,
      background: p.onBrand,
      rule: ContrastRule.meaningfulGraphic,
    ),
    ContrastPair(
      where: 'Back arrow on a detail screen',
      pair: 'ink on ground',
      foreground: p.ink,
      background: p.ground,
      rule: ContrastRule.meaningfulGraphic,
    ),
    ContrastPair(
      where: 'Focused text field border',
      pair: 'accent on surfaceAlt',
      foreground: p.accent,
      background: p.surfaceAlt,
      rule: ContrastRule.meaningfulGraphic,
    ),
    ContrastPair(
      where: 'Text on an error fill',
      pair: 'onError on error',
      foreground: p.onError,
      background: p.error,
      rule: ContrastRule.bodyText,
    ),

    // ---- Declared decorative, with the reason attached ----
    ContrastPair(
      where: 'Hairline border around a card',
      pair: 'hairline on ground',
      foreground: p.hairline,
      background: p.ground,
      rule: ContrastRule.decorative,
      why:
          'A card is found by its fill, its shadow and the gap around it, and '
          'the hairline only softens the join. Taking it to 3 to 1 against the '
          'cream would put a mid-grey rule around every card, which is a '
          'different design rather than the same one measured: the spec asks '
          'for cards that float on the ground, not cards that are outlined on '
          'it. Nothing is lost when it is not seen.',
    ),
    ContrastPair(
      where: 'Divider inside a card, and the sheet drag handle',
      pair: 'hairline on surface',
      foreground: p.hairline,
      background: p.surface,
      rule: ContrastRule.decorative,
      why:
          'Same rule as the card border. A divider groups what the spacing and '
          'the section labels have already grouped, so it repeats an answer '
          'rather than being the only one.',
    ),
    ContrastPair(
      where: 'Progress track behind the bar',
      pair: 'accentSoft on ground',
      foreground: p.accentSoft,
      background: p.ground,
      rule: ContrastRule.decorative,
      why:
          'How far along the bar is has to be readable and it is: the filled '
          'part against the track is measured above. The track edge would only '
          'matter if it were the sole way to read the count, and it is not. '
          '"2 of 6 climbed" is written in words on the same line.',
    ),
    ContrastPair(
      where: 'Emphasised stat tile against the page',
      pair: 'accentSoft on ground',
      foreground: p.accentSoft,
      background: p.ground,
      rule: ContrastRule.decorative,
      why:
          'The wash says which number is the headline. The number itself is '
          'read from its own text, which is measured above, so a reader who '
          'cannot see the wash loses an emphasis and no fact.',
    ),
    ContrastPair(
      where: 'A card against the page',
      pair: 'surface on ground',
      foreground: p.surface,
      background: p.ground,
      rule: ContrastRule.decorative,
      why:
          'Warm cream under near-white is the design in one line, and the card '
          'is found by its shadow and its rounding. Nothing about a card has to '
          'be read off its edge.',
    ),
    ContrastPair(
      where: 'A stat tile against the page',
      pair: 'surfaceAlt on ground',
      foreground: p.surfaceAlt,
      background: p.ground,
      rule: ContrastRule.decorative,
      why: 'Same as the card. The tile is a container, not a fact.',
    ),
    ContrastPair(
      where: 'A disabled primary button',
      pair: 'onBrand at 38% on brand at 38%',
      foreground: p.onBrand,
      background: p.brand,
      rule: ContrastRule.decorative,
      why:
          'WCAG exempts an inactive control by name, and fading it is how the '
          'app says it is inactive. The button only reaches this state while a '
          'save is impossible, and the sheet says why in full-strength text.',
    ),
  ];
}
