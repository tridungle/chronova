import 'package:flutter/material.dart';

/// Premium Material 3 theme for Chronova
class AppTheme {
  AppTheme._();

  // Brand colors
  static const Color _primaryLight = Color(0xFF1A73E8);
  static const Color _primaryDark = Color(0xFF8AB4F8);
  static const Color _seedColor = Color(0xFF1A73E8);

  // Surface colors for cards/timeline
  static const Color surfaceLight = Color(0xFFF8F9FA);
  static const Color surfaceDark = Color(0xFF1E1E2E);

  // Accent gradient colors
  static const List<Color> gradientPrimary = [
    Color(0xFF1A73E8),
    Color(0xFF6C63FF),
  ];

  static const List<Color> gradientSunset = [
    Color(0xFFFF6B6B),
    Color(0xFFFFE66D),
  ];

  static const List<Color> gradientOcean = [
    Color(0xFF667EEA),
    Color(0xFF764BA2),
  ];

  // Polyline colors
  static const List<Color> polylineColors = [
    Color(0xFF1A73E8),
    Color(0xFFFF6B6B),
    Color(0xFF4ECB71),
    Color(0xFFFFB74D),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
  ];

  /// Light theme
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      primary: _primaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: const Color(0xFFF5F5F7),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F0F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: Colors.white,
          backgroundColor: colorScheme.primary,
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
      ),
    );
  }

  /// Dark theme
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
      primary: _primaryDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: const Color(0xFF0F0F1A).withValues(alpha: 0.95),
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF1E1E2E),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.black,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A3E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: Colors.black,
          backgroundColor: colorScheme.primary,
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1E1E2E),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        backgroundColor: Color(0xFF1E1E2E),
      ),
    );
  }
}
