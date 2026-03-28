import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const softPink = Color(0xFFF9C5D1);
  static const pink = Color(0xFFF4A7B9);
  static const deepPink = Color(0xFFE87FA0);
  static const beige = Color(0xFFF5ECD7);
  static const cream = Color(0xFFFDF6EE);
  static const lavender = Color(0xFFC9B8E8);
  static const lavenderLight = Color(0xFFE8E0F5);
  static const lavenderDeep = Color(0xFF9B85D4);
  static const white = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF4A3F5C);
  static const textMed = Color(0xFF7B6E8D);
  static const textLight = Color(0xFFB0A3C2);
  static const cardBg = Color(0xFFFFF9F5);
  static const moodHappy = Color(0xFFFFC85A);
  static const moodSad = Color(0xFF90CAF9);
  static const moodAngry = Color(0xFFFF8A80);
  static const moodCalm = Color(0xFFA5D6A7);
  static const moodAnxious = Color(0xFFCE93D8);
  static const moodTired = Color(0xFFBCAAA4);
}

class AppTheme {
  static const List<String> _fontFallback = [
    'Noto Sans Arabic',
    'Noto Nastaliq Urdu',
    'sans-serif',
  ];

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.cream,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.deepPink,
      onPrimary: AppColors.white,
      secondary: AppColors.lavender,
      onSecondary: AppColors.textDark,
      error: Color(0xFFB00020),
      onError: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.textDark,
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ).copyWith(fontFamilyFallback: _fontFallback),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ).copyWith(fontFamilyFallback: _fontFallback),
      headlineLarge: GoogleFonts.nunito(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ).copyWith(fontFamilyFallback: _fontFallback),
      headlineMedium: GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ).copyWith(fontFamilyFallback: _fontFallback),
      bodyLarge: GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
      ).copyWith(fontFamilyFallback: _fontFallback),
      bodyMedium: GoogleFonts.nunito(
        fontSize: 14,
        color: AppColors.textMed,
      ).copyWith(fontFamilyFallback: _fontFallback),
      labelLarge: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
      ).copyWith(fontFamilyFallback: _fontFallback),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.softPink, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.softPink, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.deepPink, width: 2)),
      hintStyle: GoogleFonts.nunito(
        color: AppColors.textLight,
      ).copyWith(fontFamilyFallback: _fontFallback),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.deepPink,
        foregroundColor: AppColors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ).copyWith(fontFamilyFallback: _fontFallback),
      ),
    ),
  );
}
