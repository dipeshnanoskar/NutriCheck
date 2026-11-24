import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens ported 1:1 from the original NutriCheck Figma spec
/// (src/index.css --color-* variables).
class AppColors {
  AppColors._();

  static const greenPrimary = Color(0xFF176B45);
  static const greenLight = Color(0xFFE8F5EE);
  static const greenMid = Color(0xFF2D9264);
   static const amber = Color(0xFFF59E0B);
  static const amberLight = Color(0xFFFEF3C7);
  static const orange = Color(0xFFF97316);
  static const orangeLight = Color(0xFFFFEDD5);
  static const red = Color(0xFFEF4444);
  static const redLight = Color(0xFFFEE2E2);
  static const bg = Color(0xFFF7F9F7);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const outerBg = Color(0xFFE8EAE8);
}

const double kCardRadius = 16.0;

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final displayFont = GoogleFonts.outfitTextTheme();
    final bodyFont = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.greenPrimary,
        primary: AppColors.greenPrimary,
        secondary: AppColors.greenMid,
        error: AppColors.red,
        surface: AppColors.surface,
      ),
      fontFamily: bodyFont.bodyMedium?.fontFamily,
      textTheme: bodyFont.copyWith(
        displayLarge: displayFont.displayLarge,
        displayMedium: displayFont.displayMedium,
        displaySmall: displayFont.displaySmall,
        headlineLarge: displayFont.headlineLarge,
        headlineMedium: displayFont.headlineMedium,
        headlineSmall: displayFont.headlineSmall,
        titleLarge: displayFont.titleLarge,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kCardRadius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.greenPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.greenPrimary, width: 1.5),
        ),
      ),
    );
  }
}

/// Status colors for suitability badges (suitable / caution / avoid).
class StatusStyle {
  final Color bg;
  final Color fg;
  const StatusStyle(this.bg, this.fg);

  static StatusStyle forStatus(String status) {
    switch (status.toLowerCase()) {
      case 'suitable':
      case 'generally suitable':
        return const StatusStyle(AppColors.greenLight, AppColors.greenPrimary);
      case 'caution':
      case 'use caution':
        return const StatusStyle(AppColors.amberLight, AppColors.amber);
      case 'limit':
        return const StatusStyle(AppColors.orangeLight, AppColors.orange);
      case 'avoid':
        return const StatusStyle(AppColors.redLight, AppColors.red);
      default:
        return const StatusStyle(AppColors.border, AppColors.muted);
    }
  }
}
