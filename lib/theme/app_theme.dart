import 'package:flutter/material.dart';

/// Design tokens ported 1:1 from the interactive HTML mockup
/// (esg-app-mockup.html) so the real app matches the approved prototype.
class AppColors {
  AppColors._();

  static const bg = Color(0xFFFAFAF7);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1D2220);
  static const inkSoft = Color(0xFF6B7169);
  static const border = Color(0xFFE7E5DC);

  static const teal = Color(0xFF2F6F5E);
  static const tealDeep = Color(0xFF1E4E41);
  static const amber = Color(0xFFB96A2E);
  static const amberDeep = Color(0xFF8A4A1E);

  static const success = Color(0xFF2E7D46);
  static const successSoft = Color(0xFFE4F1E7);
  static const danger = Color(0xFFB23A2E);
  static const dangerSoft = Color(0xFFF7E4E1);
  static const accentSoft = Color(0xFFE1EBE5);
  static const amberSoft = Color(0xFFF2E1CD);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        primary: AppColors.teal,
        secondary: AppColors.amber,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
        bodyMedium: TextStyle(color: AppColors.ink),
        bodySmall: TextStyle(color: AppColors.inkSoft),
        labelSmall: TextStyle(color: AppColors.inkSoft, letterSpacing: 0.4),
      ),
      dividerColor: AppColors.border,
    );
  }
}
