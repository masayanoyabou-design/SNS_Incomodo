import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The palette from the landing page (index.html), so the app feels like
/// the same thing people signed up for: ecru paper, sepia ink, postmark
/// red and antique gold (PRD §3).
///
/// Screens should not use these directly — they read the theme, so the
/// whole look can be swapped by changing this one file.
abstract final class IncomodoColors {
  /// エクリュ — the page itself.
  static const paper = Color(0xFFF7F4EB);

  /// Fields and quieter surfaces.
  static const paperAlt = Color(0xFFEFE7D6);

  /// Tonal fills, pressed states.
  static const paperDeep = Color(0xFFE4D9C2);

  /// Envelopes, cards, letter paper.
  static const card = Color(0xFFFBF9F2);

  static const ink = Color(0xFF2C2523);

  /// セピア — headings.
  static const inkSoft = Color(0xFF3E2723);

  /// Secondary text. Darker than the landing page's 58%: small text on a
  /// phone needs to clear 4.5:1 against the paper (checked in theme_test).
  static const inkFaint = Color(0xB82C2523);

  /// Hairlines and borders only — never text.
  static const inkFaintest = Color(0x472C2523);

  /// 消印の赤 — postmarks and errors.
  static const red = Color(0xFFC0392B);

  /// Primary actions.
  static const redDeep = Color(0xFF9C3327);

  /// アンティークゴールド, for decoration.
  static const gold = Color(0xFFB7950B);

  /// The same gold, darkened far enough to be read as text.
  static const goldInk = Color(0xFF7D6206);

  /// "You can open it here." A quiet green that belongs on paper, rather
  /// than a traffic-light one.
  static const moss = Color(0xFF5B6B3A);
}

abstract final class IncomodoFonts {
  /// Mincho, from the phone itself: Hiragino Mincho on iOS, Noto Serif CJK
  /// on Android. Bundling Noto Serif JP would add about 5MB per weight for
  /// a typeface the device already has.
  static String get serif =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'Hiragino Mincho ProN' : 'serif';

  static const serifFallback = [
    'Hiragino Mincho ProN',
    'Noto Serif CJK JP',
    'Noto Serif JP',
  ];

  /// Typewriter, for small stamped labels like "INCOMODO POST".
  static const typewriter = 'monospace';
}

ThemeData buildIncomodoTheme() {
  const radius = BorderRadius.all(Radius.circular(2));
  const shape = RoundedRectangleBorder(borderRadius: radius);
  const hairline = BorderSide(color: IncomodoColors.inkFaintest);

  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: IncomodoColors.redDeep,
    onPrimary: IncomodoColors.paper,
    primaryContainer: IncomodoColors.paperDeep,
    onPrimaryContainer: IncomodoColors.inkSoft,
    secondary: IncomodoColors.goldInk,
    onSecondary: IncomodoColors.paper,
    secondaryContainer: IncomodoColors.paperDeep,
    onSecondaryContainer: IncomodoColors.inkSoft,
    tertiary: IncomodoColors.moss,
    onTertiary: IncomodoColors.paper,
    error: IncomodoColors.red,
    onError: IncomodoColors.paper,
    surface: IncomodoColors.paper,
    onSurface: IncomodoColors.ink,
    onSurfaceVariant: IncomodoColors.inkFaint,
    surfaceContainerLowest: IncomodoColors.card,
    surfaceContainerLow: IncomodoColors.card,
    surfaceContainer: IncomodoColors.paperAlt,
    surfaceContainerHigh: IncomodoColors.paperAlt,
    surfaceContainerHighest: IncomodoColors.paperDeep,
    outline: IncomodoColors.inkFaint,
    outlineVariant: IncomodoColors.inkFaintest,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: IncomodoFonts.serif,
    fontFamilyFallback: IncomodoFonts.serifFallback,
  );
  final text = base.textTheme.apply(
    bodyColor: IncomodoColors.ink,
    displayColor: IncomodoColors.inkSoft,
  );

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: IncomodoColors.paper,
    appBarTheme: AppBarTheme(
      backgroundColor: IncomodoColors.paper,
      foregroundColor: IncomodoColors.inkSoft,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(
        color: IncomodoColors.inkSoft,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: const CardThemeData(
      color: IncomodoColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radius, side: hairline),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: IncomodoColors.inkSoft,
        side: const BorderSide(color: IncomodoColors.inkFaint),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: IncomodoColors.redDeep),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: IncomodoColors.redDeep,
      foregroundColor: IncomodoColors.paper,
      shape: shape,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: IncomodoColors.paperAlt,
      border: OutlineInputBorder(borderRadius: radius, borderSide: hairline),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: hairline),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: IncomodoColors.red, width: 1.2),
      ),
      labelStyle: TextStyle(color: IncomodoColors.inkFaint),
    ),
    dividerTheme: const DividerThemeData(color: IncomodoColors.inkFaintest),
    tabBarTheme: const TabBarThemeData(
      labelColor: IncomodoColors.redDeep,
      unselectedLabelColor: IncomodoColors.inkFaint,
      indicatorColor: IncomodoColors.redDeep,
      dividerColor: IncomodoColors.inkFaintest,
    ),
    badgeTheme: const BadgeThemeData(
      backgroundColor: IncomodoColors.red,
      textColor: IncomodoColors.paper,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: IncomodoColors.inkSoft,
      contentTextStyle: TextStyle(color: IncomodoColors.paper),
      behavior: SnackBarBehavior.floating,
      shape: shape,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: IncomodoColors.card,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: IncomodoColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: hairline),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: IncomodoColors.redDeep),
  );
}
