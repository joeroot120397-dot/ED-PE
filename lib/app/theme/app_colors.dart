import 'package:flutter/material.dart';

/// VitalRise brand palette.
///
/// The brand is built on three anchors requested by the product brief:
/// deep navy (trust / clinical), emerald (vitality / progress) and white
/// (clarity). Everything else is derived so light and dark themes stay in
/// lockstep.
abstract final class AppColors {
  // ---- Brand anchors -------------------------------------------------
  static const Color navy = Color(0xFF0B1B2B);
  static const Color navyDeep = Color(0xFF060F19);
  static const Color navySoft = Color(0xFF16324B);
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF047857);
  static const Color emeraldSoft = Color(0xFFD1FAE5);
  static const Color white = Color(0xFFFFFFFF);

  // ---- Neutrals ------------------------------------------------------
  static const Color slate50 = Color(0xFFF7F9FC);
  static const Color slate100 = Color(0xFFEDF1F7);
  static const Color slate200 = Color(0xFFDDE3ED);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate600 = Color(0xFF52627A);
  static const Color slate800 = Color(0xFF1F2C3D);

  // ---- Semantic ------------------------------------------------------
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  /// Secondary text colour that clears WCAG AA against the surface it sits
  /// on. [slate400] is only light enough for dark backgrounds; on the light
  /// theme it lands around 2.6:1, which fails - and the text most often
  /// styled this way is the regulatory disclaimer, which has to be legible.
  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? slate400 : slate600;

  /// Colour ramp used by score rings and risk chips.
  /// [value] is always "higher is better" (0 = poor, 100 = excellent).
  static Color forScore(double value) {
    if (value >= 80) return success;
    if (value >= 60) return const Color(0xFF84CC16);
    if (value >= 40) return warning;
    if (value >= 20) return const Color(0xFFF97316);
    return danger;
  }

  /// Colour ramp for "higher is worse" values such as risk and root-cause
  /// confidence.
  static Color forRisk(double value) => forScore(100 - value);
}
