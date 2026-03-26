import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The "Digital Atelier" design system for RemitFlow.
///
/// Adapted from the Stitch design with:
/// - Newsreader (serif) for headlines & balances
/// - Plus Jakarta Sans for body & labels
/// - Lime green #D9F542 accent ("primary container")
/// - Dark vault green #1A3C2E for hero balance text
/// - Surface hierarchy: white → off-white tonal transitions (no borders)
class AppTheme {
  AppTheme._();

  // ─── Brand Colors ───────────────────────────────────────────────
  static const Color primary = Color(0xFF576500);
  static const Color primaryContainer = Color(0xFFD9F542);
  static const Color onPrimaryContainer = Color(0xFF5F6F00);

  static const Color secondary = Color(0xFF476556);
  static const Color secondaryContainer = Color(0xFFC6E7D5);
  static const Color onSecondaryContainer = Color(0xFF4B695A);

  static const Color tertiary = Color(0xFF4C6076);
  static const Color tertiaryContainer = Color(0xFFD9EAFF);

  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);

  // ─── Surface Hierarchy (The "Vellum Paper" layers) ──────────────
  static const Color surface = Color(0xFFF9F9F9);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F3F4);
  static const Color surfaceContainer = Color(0xFFEEEEEE);
  static const Color surfaceContainerHigh = Color(0xFFE8E8E8);
  static const Color surfaceContainerHighest = Color(0xFFE2E2E2);
  static const Color surfaceVariant = Color(0xFFE2E2E2);

  // ─── Text Colors ────────────────────────────────────────────────
  static const Color onSurface = Color(0xFF1A1C1C);
  static const Color onSurfaceVariant = Color(0xFF464834);
  static const Color vaultGreen = Color(0xFF1A3C2E);  // Hero balance color

  // ─── Outline (Ghost Border only) ────────────────────────────────
  static const Color outline = Color(0xFF767962);
  static const Color outlineVariant = Color(0xFFC6C9AE);

  // ─── Gradient Colors for Transaction Icons ──────────────────────
  static const Color depositGradientStart = Color(0xFF8FB89A);
  static const Color depositGradientEnd = Color(0xFF476556);
  static const Color withdrawGradientStart = Color(0xFFE8A5A5);
  static const Color withdrawGradientEnd = Color(0xFFBA1A1A);

  /// Build the full Material 3 theme.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: surfaceContainerLowest,
      colorScheme: const ColorScheme.light(
        primary: primary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        tertiaryContainer: tertiaryContainer,
        error: error,
        errorContainer: errorContainer,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      textTheme: _buildTextTheme(),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }

  static TextTheme _buildTextTheme() {
    // Headline / Display — Newsreader (serif, editorial elegance)
    final headlineStyle = GoogleFonts.newsreader(
      color: onSurface,
    );
    // Body / Label — Plus Jakarta Sans (clean, humanist)
    final bodyStyle = GoogleFonts.plusJakartaSans(
      color: onSurface,
    );

    return TextTheme(
      // Display — for hero balance
      displayLarge: headlineStyle.copyWith(
        fontSize: 56,
        fontWeight: FontWeight.w400,
        letterSpacing: -1.5,
        height: 1.0,
      ),
      displayMedium: headlineStyle.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.5,
      ),
      displaySmall: headlineStyle.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w400,
      ),

      // Headlines
      headlineLarge: headlineStyle.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
      ),
      headlineMedium: headlineStyle.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
      ),
      headlineSmall: headlineStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w400,
      ),

      // Titles
      titleLarge: headlineStyle.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
      ),
      titleMedium: bodyStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: bodyStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),

      // Body
      bodyLarge: bodyStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: bodyStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: bodyStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),

      // Labels
      labelLarge: bodyStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: bodyStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: bodyStyle.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
      ),
    );
  }
}
