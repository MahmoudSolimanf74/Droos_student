import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final baseFont = GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.red,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: baseFont.copyWith(
        displayLarge: baseFont.displayLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        displayMedium: baseFont.displayMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        titleLarge: baseFont.titleLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        titleMedium: baseFont.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleSmall: baseFont.titleSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: baseFont.bodyLarge?.copyWith(color: AppColors.textPrimary),
        bodyMedium: baseFont.bodyMedium?.copyWith(color: AppColors.textPrimary),
        bodySmall: baseFont.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.cairo(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get displayLarge => GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary);
  static TextStyle get displayMedium => GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static TextStyle get titleLarge => GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static TextStyle get titleMedium => GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle get titleSmall => GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle get bodyLarge => GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.normal, color: AppColors.textPrimary);
  static TextStyle get bodyMedium => GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.normal, color: AppColors.textPrimary);
  static TextStyle get bodySmall => GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.normal, color: AppColors.textSecondary);
  static TextStyle get labelMedium => GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary);
}
