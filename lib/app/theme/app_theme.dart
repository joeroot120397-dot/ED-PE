import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Radius / spacing scale shared by every surface in the app.
abstract final class AppRadii {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double pill = 999;
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Builds the light / dark [ThemeData] used by the app.
///
/// [highContrast] and [textScaleBoost] are driven by the accessibility
/// settings screen so users can opt into stronger contrast and larger type
/// without leaving the app.
abstract final class AppTheme {
  /// Inter, bundled in `assets/fonts` and declared in `pubspec.yaml`.
  ///
  /// It is bundled rather than fetched through `google_fonts` for three
  /// reasons, in increasing order of importance:
  ///
  /// 1. First launch does not wait on a font download.
  /// 2. The app claims to work offline. A runtime font fetch makes that
  ///    false in a way nobody notices until they are on a train.
  /// 3. On the web build the failure mode is total: CanvasKit has no system
  ///    font to fall back on, so a blocked or slow fetch renders the entire
  ///    app with **no text at all** - correct layout, correct colours, and
  ///    not one readable word. That was the actual observed behaviour
  ///    before this changed.
  ///
  /// There is also a privacy argument: a men's sexual health app should not
  /// announce every cold start to a Google CDN.
  static const String _fontFamily = 'Inter';

  static ThemeData light({bool highContrast = false}) =>
      _build(Brightness.light, highContrast);

  static ThemeData dark({bool highContrast = false}) =>
      _build(Brightness.dark, highContrast);

  static ThemeData _build(Brightness brightness, bool highContrast) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.emerald,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? AppColors.emerald : AppColors.emeraldDark,
          onPrimary: AppColors.white,
          secondary: isDark ? AppColors.white : AppColors.navy,
          surface: isDark ? AppColors.navy : AppColors.white,
          onSurface: isDark ? AppColors.slate100 : AppColors.slate800,
          error: AppColors.danger,
        );

    final Color scaffold = isDark ? AppColors.navyDeep : AppColors.slate50;
    final Color outline = highContrast
        ? (isDark ? AppColors.white : AppColors.navy)
        : (isDark ? AppColors.navySoft : AppColors.slate200);

    final TextTheme baseText =
        (isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme)
            .apply(
              fontFamily: _fontFamily,
              bodyColor: isDark ? AppColors.slate100 : AppColors.slate800,
              displayColor: isDark ? AppColors.white : AppColors.navy,
            );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      // Set on ThemeData, not just on textTheme. Component themes build
      // raw TextStyles that do not inherit from textTheme - the filled
      // button's label is one - and on CanvasKit a style with no resolvable
      // family renders as nothing at all. Every button in the app was
      // shipping with an invisible label before this line existed.
      fontFamily: _fontFamily,
      textTheme: baseText.copyWith(
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: isDark ? AppColors.white : AppColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: baseText.titleLarge?.copyWith(
          color: isDark ? AppColors.white : AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.navy : AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: outline, width: highContrast ? 1.6 : 1),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, space: 1, thickness: 1),
      // dividerTheme only styles the Divider *widget*. Everything that
      // reads `theme.dividerColor` directly - card borders, score-ring
      // tracks, progress backgrounds - falls back to the seeded
      // outlineVariant, which came out a muddy olive against this palette.
      // Both have to be set.
      dividerColor: outline,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          // Derived from the text theme rather than written fresh: a raw
          // TextStyle here carries no font family, and on CanvasKit that
          // renders the label as nothing at all.
          textStyle: baseText.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: outline, width: highContrast ? 1.6 : 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.navySoft.withValues(alpha: 0.35)
            : AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          side: BorderSide(color: outline),
        ),
        side: BorderSide(color: outline),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.navy : AppColors.white,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.14),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: outline,
      ),
    );
  }
}
