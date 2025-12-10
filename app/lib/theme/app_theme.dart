import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryOrange = Color(0xFFFF8412);
  static const Color primaryDark = Color(0xFFE6750F);
  static const Color primaryLight = Color(0xFFFF9A3D);

  static const Color secondaryBlack = Color(0xFF212121);
  static const Color secondaryLight = Color(0xFF484848);
  static const Color secondaryDark = Color(0xFF000000);

  // Neutrals / Surfaces
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFFAFAFA);
  
  static const Color surfaceDark = Color(0xFF212121);
  static const Color backgroundDark = Color(0xFF181818);
  
  static const Color accent = Color(0xFFFFF3E0);

  // Status
  static const Color success = Color(0xFF43A047);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFB366);
  static const Color info = Color(0xFF2196F3);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryOrange,
        primary: primaryOrange,
        secondary: secondaryBlack,
        surface: surfaceLight,
        // background: backgroundLight, // Background is deprecated in ColorScheme, part of surface/scaffold
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: secondaryBlack,
        error: error,
      ),
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: surfaceLight,
        elevation: 2,
        margin: EdgeInsets.all(8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Compact Inputs
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      visualDensity: VisualDensity.compact, // Compact overall UI
      // No fontFamily specified -> system default
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryOrange,
        brightness: Brightness.dark,
        primary: primaryOrange,
        secondary: secondaryLight,
        surface: surfaceDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        error: error,
      ),
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark, // Using slightly darker for dark mode appbar if desired, or keep primaryOrange
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: surfaceDark,
        elevation: 2,
        margin: EdgeInsets.all(8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF303030), // Lighter than card (212121) for contrast
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: secondaryLight),
          borderRadius: BorderRadius.circular(4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Compact Inputs
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: secondaryLight),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      visualDensity: VisualDensity.compact, // Compact overall UI
      // No fontFamily specified -> system default
    );
  }
}
