import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds the light and dark [ThemeData] from the tokens.
///
/// Two theme extensions ride along:
///
/// * [CairnColors] carries the palette roles Material has no slot for
///   (`brand`, `onBrand`, `accentSoft`, `gold`, `ground`).
/// * [CairnTextStyles] carries the named type roles with their colours already
///   bound, so a widget writes `context.cairnText.sectionLabel` instead of
///   guessing which Material slot the section label landed in.
///
/// Reach for those through the `BuildContext` getters in
/// `lib/shared/extensions/theme_context.dart`.
abstract final class CairnTheme {
  static ThemeData get light => _build(CairnPalette.light);
  static ThemeData get dark => _build(CairnPalette.dark);

  static ThemeData _build(CairnPalette p) {
    final scheme = _scheme(p);
    final text = _textTheme(p);

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      fontFamily: CairnType.family,
      textTheme: text,
      scaffoldBackgroundColor: p.ground,
      canvasColor: p.ground,
      shadowColor: p.accent,
      splashColor: p.accentSoft.withValues(alpha: 0.4),
      highlightColor: p.accentSoft.withValues(alpha: 0.25),
      extensions: <ThemeExtension<dynamic>>[
        CairnColors(p),
        CairnTextStyles.fromPalette(p),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: p.ground,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: CairnType.screenTitle.copyWith(color: p.ink),
        iconTheme: IconThemeData(color: p.ink, size: CairnSize.navIcon),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        shadowColor: p.accent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: CairnRadius.dataCardAll,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.hairline,
        thickness: CairnSize.hairline,
        space: CairnSize.hairline,
      ),
      iconTheme: IconThemeData(color: p.ink, size: CairnSize.icon),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.accentSoft,
        circularTrackColor: p.accentSoft,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CairnSpace.x16,
          vertical: CairnSpace.x12,
        ),
        hintStyle: CairnType.body.copyWith(color: p.inkMuted),
        labelStyle: CairnType.body.copyWith(color: p.inkMuted),
        border: const OutlineInputBorder(
          borderRadius: CairnRadius.fieldAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: CairnRadius.fieldAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: CairnRadius.fieldAll,
          borderSide: BorderSide(color: p.accent, width: CairnSize.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: p.onBrand,
          textStyle: CairnType.button,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: CairnSpace.x24,
            vertical: CairnSpace.x12,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          textStyle: CairnType.button,
          side: BorderSide(color: p.hairline, width: CairnSize.hairline),
          padding: const EdgeInsets.symmetric(
            horizontal: CairnSpace.x24,
            vertical: CairnSpace.x12,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: CairnType.button,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.brand,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: p.hairline, width: CairnSize.hairline),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: CairnType.button.copyWith(color: p.inkMuted),
        secondaryLabelStyle: CairnType.button.copyWith(color: p.onBrand),
        padding: const EdgeInsets.symmetric(
          horizontal: CairnSpace.x16,
          vertical: CairnSpace.x8,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: p.hairline,
        shape: const RoundedRectangleBorder(borderRadius: CairnRadius.sheetTop),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.brand,
        contentTextStyle: CairnType.body.copyWith(color: p.onBrand),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: CairnRadius.fieldAll),
      ),
    );
  }

  static ColorScheme _scheme(CairnPalette p) => ColorScheme(
    brightness: p.brightness,
    primary: p.accent,
    onPrimary: p.onBrand,
    primaryContainer: p.accentSoft,
    onPrimaryContainer: p.brand,
    secondary: p.brand,
    onSecondary: p.onBrand,
    secondaryContainer: p.accentSoft,
    onSecondaryContainer: p.brand,
    tertiary: p.gold,
    onTertiary: p.isDark ? p.ground : p.ink,
    tertiaryContainer: p.accentSoft,
    onTertiaryContainer: p.brand,
    surface: p.surface,
    onSurface: p.ink,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.surfaceAlt,
    surfaceContainer: p.surfaceAlt,
    surfaceContainerHigh: p.surfaceAlt,
    surfaceContainerHighest: p.surfaceAlt,
    surfaceTint: p.accent,
    onSurfaceVariant: p.inkMuted,
    outline: p.hairline,
    outlineVariant: p.hairline,
    shadow: p.accent,
    scrim: p.ink,
    inverseSurface: p.brand,
    onInverseSurface: p.onBrand,
    inversePrimary: p.accentSoft,
    error: p.error,
    onError: p.onError,
  );

  /// Maps the nine spec roles onto Material's thirteen slots so an unstyled
  /// `Text`, `AppBar` or button picks up Cairn type with no override.
  ///
  /// The scale only has four sizes above body, so the display and headline
  /// families repeat rather than inventing sizes the spec does not list.
  static TextTheme _textTheme(CairnPalette p) {
    final ink = p.ink;
    final muted = p.inkMuted;
    return TextTheme(
      displayLarge: CairnType.displayLine1.copyWith(color: ink),
      displayMedium: CairnType.displayLine2.copyWith(color: ink),
      displaySmall: CairnType.screenTitle.copyWith(color: ink),
      headlineLarge: CairnType.displayLine1.copyWith(color: ink),
      headlineMedium: CairnType.displayLine2.copyWith(color: ink),
      headlineSmall: CairnType.screenTitle.copyWith(color: ink),
      titleLarge: CairnType.screenTitle.copyWith(color: ink),
      titleMedium: CairnType.statValue.copyWith(color: ink),
      titleSmall: CairnType.button.copyWith(color: ink),
      bodyLarge: CairnType.body.copyWith(color: ink),
      bodyMedium: CairnType.body.copyWith(color: ink),
      bodySmall: CairnType.meta.copyWith(color: muted),
      labelLarge: CairnType.button.copyWith(color: ink),
      labelMedium: CairnType.sectionLabel.copyWith(color: muted),
      labelSmall: CairnType.statCaption.copyWith(color: muted),
    );
  }
}

/// The palette, carried on [ThemeData.extensions].
@immutable
class CairnColors extends ThemeExtension<CairnColors> {
  const CairnColors(this.palette);

  final CairnPalette palette;

  @override
  CairnColors copyWith({CairnPalette? palette}) =>
      CairnColors(palette ?? this.palette);

  /// The palette is a coherent set, so it swaps whole rather than
  /// interpolating role by role. Crossing the halfway point flips it.
  @override
  CairnColors lerp(ThemeExtension<CairnColors>? other, double t) {
    if (other is! CairnColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// The named type roles, colours already bound.
@immutable
class CairnTextStyles extends ThemeExtension<CairnTextStyles> {
  const CairnTextStyles({
    required this.displayLine1,
    required this.displayLine2,
    required this.screenTitle,
    required this.sectionLabel,
    required this.body,
    required this.meta,
    required this.statValue,
    required this.statCaption,
    required this.button,
  });

  factory CairnTextStyles.fromPalette(CairnPalette p) => CairnTextStyles(
    displayLine1: CairnType.displayLine1.copyWith(color: p.ink),
    displayLine2: CairnType.displayLine2.copyWith(color: p.ink),
    screenTitle: CairnType.screenTitle.copyWith(color: p.ink),
    sectionLabel: CairnType.sectionLabel.copyWith(color: p.inkMuted),
    body: CairnType.body.copyWith(color: p.ink),
    meta: CairnType.meta.copyWith(color: p.inkMuted),
    statValue: CairnType.statValue.copyWith(color: p.ink),
    statCaption: CairnType.statCaption.copyWith(color: p.inkMuted),
    button: CairnType.button.copyWith(color: p.ink),
  );

  final TextStyle displayLine1;
  final TextStyle displayLine2;
  final TextStyle screenTitle;
  final TextStyle sectionLabel;
  final TextStyle body;
  final TextStyle meta;
  final TextStyle statValue;
  final TextStyle statCaption;
  final TextStyle button;

  @override
  CairnTextStyles copyWith({
    TextStyle? displayLine1,
    TextStyle? displayLine2,
    TextStyle? screenTitle,
    TextStyle? sectionLabel,
    TextStyle? body,
    TextStyle? meta,
    TextStyle? statValue,
    TextStyle? statCaption,
    TextStyle? button,
  }) => CairnTextStyles(
    displayLine1: displayLine1 ?? this.displayLine1,
    displayLine2: displayLine2 ?? this.displayLine2,
    screenTitle: screenTitle ?? this.screenTitle,
    sectionLabel: sectionLabel ?? this.sectionLabel,
    body: body ?? this.body,
    meta: meta ?? this.meta,
    statValue: statValue ?? this.statValue,
    statCaption: statCaption ?? this.statCaption,
    button: button ?? this.button,
  );

  @override
  CairnTextStyles lerp(ThemeExtension<CairnTextStyles>? other, double t) {
    if (other is! CairnTextStyles) return this;
    return CairnTextStyles(
      displayLine1: TextStyle.lerp(displayLine1, other.displayLine1, t)!,
      displayLine2: TextStyle.lerp(displayLine2, other.displayLine2, t)!,
      screenTitle: TextStyle.lerp(screenTitle, other.screenTitle, t)!,
      sectionLabel: TextStyle.lerp(sectionLabel, other.sectionLabel, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      meta: TextStyle.lerp(meta, other.meta, t)!,
      statValue: TextStyle.lerp(statValue, other.statValue, t)!,
      statCaption: TextStyle.lerp(statCaption, other.statCaption, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
    );
  }
}
