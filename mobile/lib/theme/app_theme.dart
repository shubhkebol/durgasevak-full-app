import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'Mukta';
  static const Color brandColor = Colors.deepOrange;

  /// Dark theme - Heritage Bhagwa look with deep black backdrop
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF161618),
      onSurface: Colors.white,
      onSurfaceVariant: const Color(0xFFB0B0B0),
      outline: const Color(0xFF38383A),
      outlineVariant: const Color(0xFF262628),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF161618),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFF262628), width: 1),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF1C1C1E),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1C1C1E),
        modalBackgroundColor: Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerColor: const Color(0xFF262628),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF171717),
        labelStyle: TextStyle(color: Colors.white70),
        hintStyle: TextStyle(color: Colors.white54),
        prefixIconColor: Colors.white70,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white38),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: brandColor, width: 2),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  /// Light theme - High contrast, crisp modern daylight mode
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: Brightness.light,
    ).copyWith(
      surface: Colors.white,
      onSurface: const Color(0xFF191C1E),
      onSurfaceVariant: const Color(0xFF555B62),
      outline: const Color(0xFFB2B6BC),
      outlineVariant: const Color(0xFFE2E4E8),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F7F9),
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F7F9),
        foregroundColor: Color(0xFF191C1E),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerColor: const Color(0xFFE5E7EB),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF0F2F5),
        labelStyle: TextStyle(color: Color(0xFF555B62)),
        hintStyle: TextStyle(color: Color(0xFF8B929A)),
        prefixIconColor: Color(0xFF555B62),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: brandColor, width: 2),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}
