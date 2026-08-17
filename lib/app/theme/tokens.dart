import 'package:flutter/material.dart';

/// Design tokens for Cairn, transcribed from the design spec.
///
/// This file is the only place a hex value, a spacing step, a radius or a type
/// size may appear. Everything above it reads tokens, either directly or
/// through the `ThemeData` built in `theme.dart`.

/// The full colour set for one brightness.
///
/// Two instances exist, [CairnPalette.light] and [CairnPalette.dark]. Dark is a
/// translation rather than an inversion: the deep green becomes the ground
/// instead of the accent, and green surfaces lift off it.
@immutable
class CairnPalette {
  const CairnPalette({
    required this.brightness,
    required this.ground,
    required this.surface,
    required this.surfaceAlt,
    required this.brand,
    required this.onBrand,
    required this.accent,
    required this.accentSoft,
    required this.ink,
    required this.inkMuted,
    required this.hairline,
    required this.gold,
    required this.error,
    required this.onError,
  });

  final Brightness brightness;

  /// Page background. Warm cream in light, deep green in dark. Never white.
  final Color ground;

  /// Cards and sheets, floating on [ground].
  final Color surface;

  /// Nested tiles and form fields.
  final Color surfaceAlt;

  /// Emphasis fills: nav bar, badge discs, the selected filter pill.
  final Color brand;

  /// Text and glyphs sitting on [brand].
  final Color onBrand;

  /// Buttons, links, active icons. Also tints the card shadow.
  final Color accent;

  /// Progress track fill and other quiet green washes.
  final Color accentSoft;

  /// Primary text.
  final Color ink;

  /// Labels, meta rows, secondary text, and the name of an unclimbed peak.
  final Color inkMuted;

  /// Dividers and 1px card borders.
  final Color hairline;

  /// Unlocked milestone badges only. The one colour that is not green.
  final Color gold;

  /// Not in the design spec, which allows no hue but green and a muted gold.
  /// `ColorScheme` demands an error colour, so the Material 3 baseline is kept
  /// here rather than invented: no screen in E1 shows an error surface, and a
  /// missing value would render as black. Revisit if validation UI arrives.
  final Color error;
  final Color onError;

  /// Four values moved in T22, and every one of them moved because a
  /// measurement said so rather than because it looked better. Before T22 the
  /// palette had been eyeballed in both themes and never computed, which T8's
  /// review said outright at the time. `test/a11y/contrast_test.dart` now holds
  /// every pair the app renders, so the next edit here fails a test instead of
  /// quietly costing somebody a line of text they can no longer read.
  ///
  /// | Token | Was | Now | The pair that forced it |
  /// |---|---|---|---|
  /// | light `inkMuted` | `#6B7268` | `#646A61` | 4.12 on `accentSoft` |
  /// | light `accent` | `#4A7C3F` | `#48783D` | 4.38 on `ground` |
  /// | light `gold` | `#C9A24A` | `#A4843C` | 2.40 on `surface` |
  /// | dark `inkMuted` | `#9AA894` | `#B3BEAF` | 3.56 on `accentSoft` |
  static const light = CairnPalette(
    brightness: Brightness.light,
    ground: Color(0xFFF4F1EA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFAF8F3),
    brand: Color(0xFF1E3A2B),
    onBrand: Color(0xFFF4F1EA),
    // Darkened two steps in T22. The spec gives `accent` to links as well as to
    // buttons and icons, and link-coloured text on the cream ground measured
    // 4.38 against a 4.5 bar. The icon and progress-bar uses only gained.
    accent: Color(0xFF48783D),
    accentSoft: Color(0xFFE4EDDC),
    ink: Color(0xFF1A1F1B),
    // The muted grey-green, darkened in T22. It was failing as body text on
    // three of the four backgrounds it sits on, the emphasised stat tile's
    // `accentSoft` worst at 4.12.
    inkMuted: Color(0xFF646A61),
    hairline: Color(0xFFE2DED4),
    // An antique brass rather than the brighter gold T9 transcribed. A milestone
    // badge is now told apart by the shape of its disc, so that silhouette has
    // to be visible against a white card, and `#C9A24A` on white measured
    // 2.40 against the 3:1 bar for a meaningful graphic. This reads 3.53.
    gold: Color(0xFFA4843C),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
  );

  static const dark = CairnPalette(
    brightness: Brightness.dark,
    ground: Color(0xFF0F2417),
    surface: Color(0xFF1B3B2A),
    surfaceAlt: Color(0xFF224832),
    brand: Color(0xFFEDF2E8),
    onBrand: Color(0xFF0F2417),
    accent: Color(0xFF7CB342),
    accentSoft: Color(0xFF2A5238),
    ink: Color(0xFFEDF2E8),
    // Lifted in T22. Dark's muted text was written against the deep ground and
    // never re-checked against the two surfaces that lift off it, where it read
    // 4.12 and 3.56. Both are the stat caption, which is the smallest type in
    // the app and the least able to afford it.
    inkMuted: Color(0xFFB3BEAF),
    hairline: Color(0xFF2A4534),
    gold: Color(0xFFD9B65E),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
  );

  bool get isDark => brightness == Brightness.dark;

  /// Placeholder fill for an unclimbed peak with no photograph yet.
  ///
  /// Derived, not a new hex: a muted grey-green mixed from [inkMuted] and
  /// [accent] so it stays inside the palette. It leans green on purpose,
  /// because the card then desaturates it and washes it in cream, and a
  /// greyer start would come out fully neutral. E2 replaces the placeholder
  /// with real photography and this stops being drawn.
  Color get peakPlaceholderUnclimbed => Color.lerp(inkMuted, accent, 0.5)!;

  /// Placeholder fill for a climbed peak with no photograph yet. Full-strength
  /// accent green, so the climbed / unclimbed split reads before E2 lands.
  Color get peakPlaceholderClimbed => accent;

  /// The cream wash laid over an unclimbed photo, on top of desaturation.
  Color get unclimbedWash => ground.withValues(alpha: CairnPeak.washOpacity);
}

/// The 4-based spacing scale. No other gap values are allowed.
abstract final class CairnSpace {
  static const double x4 = 4;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x20 = 20;
  static const double x24 = 24;
  static const double x32 = 32;

  /// Horizontal padding on every screen body.
  static const double page = x20;

  /// Vertical gap between stacked cards in a list.
  static const double cardGap = x12;
}

/// Corner radii. Generous throughout; pills are fully round.
abstract final class CairnRadius {
  /// Photo cards, and the top corners of a sheet over a hero.
  static const double photoCard = 24;

  /// Data cards and stat tiles.
  static const double dataCard = 20;

  /// Form fields.
  static const double field = 16;

  /// Large enough to read as fully round at every height used in the app.
  static const double pill = 999;

  static const BorderRadius photoCardAll = BorderRadius.all(
    Radius.circular(photoCard),
  );
  static const BorderRadius dataCardAll = BorderRadius.all(
    Radius.circular(dataCard),
  );
  static const BorderRadius fieldAll = BorderRadius.all(Radius.circular(field));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  /// Top-only rounding, for a sheet that sits over a photo hero.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(photoCard),
  );
}

/// Fixed component sizes that the spec names outright.
abstract final class CairnSize {
  /// The standard icon badge: a circle with a [CairnPalette.brand] fill.
  static const double iconBadge = 44;

  /// Glyph drawn inside [iconBadge].
  static const double iconBadgeGlyph = 22;

  /// The small climbed mark that sits top-right on a [PeakCard]-sized photo.
  /// The spec calls it "small" without giving a number; 28 keeps it clear of
  /// the 44 standard badge while staying tappable-adjacent.
  static const double badgeMark = 28;

  /// Glyph drawn inside [badgeMark].
  static const double badgeMarkGlyph = 16;

  /// Ring around a badge disc that sits over a photograph.
  ///
  /// A `brand` disc has no promised contrast against a picture nobody has taken
  /// yet, and T22 measured it against the placeholder the app draws today: 2.38
  /// to 1 in light and 2.20 in dark, so Cairn's single most important mark was
  /// close to invisible on the card it matters on. A ring in `onBrand` fixes it
  /// for every photograph at once rather than for one placeholder, because the
  /// mark's edge is then two colours 11 to 1 apart and whatever lies behind it
  /// only has to fail against one of them.
  ///
  /// 2dp rather than the 1dp hairline: at 28dp a hairline is a hint, and this
  /// ring has a job.
  static const double markRing = 2;

  /// Hairline borders and dividers.
  static const double hairline = 1;

  /// Height of the progress track on the peaks list. The spec gives `accentSoft`
  /// to a progress track without sizing it; 6 keeps the bar readable at a glance
  /// while staying quieter than anything else on that screen, which is the point
  /// of it. The grid is what shows progress; this only confirms it.
  static const double progressTrack = 6;

  /// Minimum height of a primary button, and of any field you tap rather than
  /// type into. The spec sizes the button's label and not the control, so this
  /// is the smallest comfortable touch target rather than a transcribed number.
  static const double control = 48;

  /// Standard icon in body flow, e.g. a stat tile's leading glyph.
  static const double icon = 18;

  /// Icon in the floating pill nav.
  static const double navIcon = 22;

  /// Height of one destination in the floating pill nav. Fixed rather than left
  /// to its content, so the bar's height is known without measuring text. That
  /// is what lets the nav publish the clearance a scroll view owes it.
  static const double navItem = 44;

  /// Photo aspect ratio inside a peak card.
  ///
  /// **5:3, and the number is grid arithmetic rather than taste.** T9 picked
  /// 4:3 and nothing ever defended it. Measured off the emulator at 411 by 914
  /// dp: a card is 179.7 wide, there is 750 dp between the top of the list and
  /// the floating nav, and three rows plus their gaps have to fit in there
  /// alongside a header. At 4:3 the photo was 135 and the card 217, so three
  /// rows came to 675 and left 75 dp for a header. The greeting alone is 100.
  /// The sixth peak was therefore behind the nav before T20 added a single
  /// pixel, and no header at all would have fixed it.
  ///
  /// At 5:3 the photo is 108 and the card 182, so three rows come to 570 and
  /// the header has 180 to spend. It spends 164, and the last row lands clear
  /// of the nav. Verified by counting readable names on the device, not by
  /// trusting this sum.
  ///
  /// 16:9 was the other candidate and it is the wrong shape: 101 dp of photo on
  /// a 180 dp card reads as a banner over a caption. 5:3 is still a landscape
  /// photograph.
  static const double peakPhotoAspect = 5 / 3;

  /// Photo aspect ratio inside a climb's photo strip.
  ///
  /// Left at 4:3 while [peakPhotoAspect] moved. It looks like the same number
  /// and it is not the same decision: a peak card's photo is shaped by how many
  /// cards have to share one screen, and a photo somebody took on a climb is
  /// shaped by wanting to see it. Nothing on climb detail is competing for the
  /// room, so nothing there had to give any up.
  static const double climbPhotoAspect = 4 / 3;
}

/// The two badge silhouettes, and the numbers that make them tell apart.
///
/// **A badge's type is carried by its outline, not by its fill.** Until T22 a
/// milestone and a peak badge were the same 44dp circle and differed only in
/// colour, gold against green. Around one man in twelve has some form of
/// red-green colour blindness and loses that distinction completely, and a
/// palette edit could have erased it for everybody without a test noticing.
///
/// So a peak badge keeps the plain circle the spec names, and a milestone takes
/// a scalloped seal. `test/a11y/badge_greyscale_test.dart` renders the grid,
/// throws the colour away, and measures the two silhouettes against each other.
abstract final class CairnBadge {
  /// Bumps around a milestone seal. Ten puts roughly 14dp of perimeter in each
  /// one at the 44dp badge size, which is wide enough to read as a scallop
  /// rather than as a rough edge.
  static const int sealLobes = 10;

  /// How deep a valley cuts, as a fraction of the radius. At 0.16 a 44dp seal
  /// wobbles between 22 and 18.5dp, so the silhouette differs from a circle
  /// over about a sixth of the disc's area.
  static const double sealDepth = 0.16;
}

/// The soft, wide, green-tinted card shadow. No hard drop shadows anywhere.
abstract final class CairnShadow {
  static const double blur = 24;
  static const double dy = 8;
  static const double opacity = 0.08;

  /// Tinted with the theme's accent, per the spec.
  static List<BoxShadow> card(Color accent) => [
    BoxShadow(
      color: accent.withValues(alpha: opacity),
      blurRadius: blur,
      offset: const Offset(0, dy),
    ),
  ];
}

/// The climbed / unclimbed treatment. Cairn's whole point, so its numbers are
/// tokens rather than literals buried in a widget.
abstract final class CairnPeak {
  /// Unclimbed photos drop to roughly a third of their saturation.
  static const double unclimbedSaturation = 0.3;

  /// Strength of the cream wash over a desaturated photo. The spec says "a
  /// cream wash" without a number; 0.35 mutes the photo while leaving the
  /// subject readable.
  static const double washOpacity = 0.35;

  /// Luma weights used to build the desaturation matrix (Rec. 709).
  static const double _lumaR = 0.2126;
  static const double _lumaG = 0.7152;
  static const double _lumaB = 0.0722;

  /// A saturation [ColorFilter], where 1 is untouched and 0 is greyscale.
  ///
  /// Applied through `ColorFiltered`, so it works on the placeholder today and
  /// on real photography once E2 supplies it, with no widget change.
  static ColorFilter saturation(double s) {
    final r = _lumaR * (1 - s);
    final g = _lumaG * (1 - s);
    final b = _lumaB * (1 - s);
    return ColorFilter.matrix(<double>[
      r + s, g, b, 0, 0, //
      r, g + s, b, 0, 0, //
      r, g, b + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
  }
}

/// Blur strength for a sheet that sits over a photo hero.
abstract final class CairnFrost {
  static const double blur = 24;

  /// How opaque the sheet's surface fill is over the blur. Enough to keep text
  /// legible over any photograph.
  static const double surfaceOpacity = 0.82;
}

/// The type scale, as colourless styles.
///
/// Colour is bound per theme in `theme.dart`, because three of these roles are
/// specified as [CairnPalette.inkMuted] and that differs by brightness.
abstract final class CairnType {
  static const String family = 'Manrope';

  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;

  /// A greeting's first line. 32 / 38, Light, tracking -0.5.
  static const TextStyle displayLine1 = TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 38 / 32,
    fontWeight: light,
    letterSpacing: -0.5,
  );

  /// A greeting's second line. Same size, heavier weight.
  static const TextStyle displayLine2 = TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 38 / 32,
    fontWeight: medium,
    letterSpacing: -0.5,
  );

  /// 22 / 28, Medium. Screen titles, and a peak's name on its card.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: medium,
  );

  /// 11, SemiBold, uppercase, tracking +1.2. Sits above every group.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: semiBold,
    letterSpacing: 1.2,
  );

  /// 15 / 22, Regular.
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: regular,
  );

  /// 13 / 18, Regular. Dot-separated meta rows.
  static const TextStyle meta = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: regular,
  );

  /// 20 / 24, SemiBold.
  static const TextStyle statValue = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 24 / 20,
    fontWeight: semiBold,
  );

  /// 10, SemiBold, uppercase, tracking +1.0.
  static const TextStyle statCaption = TextStyle(
    fontFamily: family,
    fontSize: 10,
    fontWeight: semiBold,
    letterSpacing: 1,
  );

  /// 15, Medium.
  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: medium,
  );
}

/// The separator used in every meta row.
abstract final class CairnGlyph {
  static const String metaSeparator = '·';
}
