import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.light(
        primary: AppColors.accent,
        onPrimary: AppColors.text,
        secondary: AppColors.accentDark,
        surface: AppColors.panel,
        onSurface: AppColors.text,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.panel,
        foregroundColor: AppColors.text,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.panel,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accentDark, width: 1.5),
        ),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(
        base.textTheme,
      ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    );
  }

  static TextStyle get display =>
      GoogleFonts.oswald(fontWeight: FontWeight.w600, color: AppColors.text);

  static TextStyle get displayBold =>
      GoogleFonts.oswald(fontWeight: FontWeight.w700, color: AppColors.text);

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );

  static TextStyle get monoBold => GoogleFonts.jetBrainsMono(
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
}
