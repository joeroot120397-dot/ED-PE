import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
        GoogleFonts.interTextTheme(
          isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
        ).apply(
          bodyColor: isDark ? AppColors.slate100 : AppColors.slate800,
          displayColor: isDark ? AppColors.white : AppColors.navy,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
