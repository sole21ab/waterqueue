import 'package:flutter/material.dart';

/// Water-inspired colour palette shared by every screen.
///
/// The palette is intentionally small: [primary] for interactive accents,
/// [primaryDeep] for stronger emphasis (app bar, headings) and [surfacePale]
/// for subtle backgrounds.
class AppColors {
  const AppColors._();

  /// Primary blue used for interactive elements.
  static const Color primary = Color(0xFF087EAD);

  /// Deep blue used where a stronger emphasis is needed.
  static const Color primaryDeep = Color(0xFF075985);

  /// Pale blue used for subtle backgrounds and containers.
  static const Color surfacePale = Color(0xFFEAF6FB);

  /// Slightly deeper pale blue for layered containers.
  static const Color surfacePaleStrong = Color(0xFFD6EAF5);

  /// Muted body text that stays readable on white and pale blue surfaces.
  static const Color textMuted = Color(0xFF4F5D66);

  /// Main body text colour.
  static const Color textStrong = Color(0xFF102A36);

  /// Soft border colour for cards and inputs.
  static const Color outlineSoft = Color(0xFFD7E3EA);

  /// Outline colour for interactive borders.
  static const Color outline = Color(0xFF9FB3BD);

  /// Error colour used for failures and the "unavailable" status.
  static const Color danger = Color(0xFFA3231B);

  /// Pale container matching [danger].
  static const Color dangerSurface = Color(0xFFFCE9E7);

  /// Amber foreground used for the "uncertain" status.
  static const Color warning = Color(0xFF8A5300);

  /// Pale amber container matching [warning].
  static const Color warningSurface = Color(0xFFFFF4E1);

  /// Neutral foreground used for the "unknown" status.
  static const Color neutral = Color(0xFF4F5D66);

  /// Neutral container matching [neutral].
  static const Color neutralSurface = Color(0xFFEDF1F4);
}

/// Builds the app theme from the shared [AppColors] palette.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.surfacePale,
      onPrimaryContainer: AppColors.primaryDeep,
      secondary: AppColors.primaryDeep,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.surfacePaleStrong,
      onSecondaryContainer: AppColors.primaryDeep,
      surface: Colors.white,
      onSurface: AppColors.textStrong,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineSoft,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerSurface,
      onErrorContainer: Color(0xFF6E1810),
    );

    const OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.outline),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarThemeData(
        backgroundColor: AppColors.primaryDeep,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.outlineSoft),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: const Color(0xFFF7FBFD),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDeep,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryDeep),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primaryDeep,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineSoft,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
