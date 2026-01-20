import 'package:flutter/material.dart';

ThemeData buildDarkTheme() {
  // Fanvue Inspired Palette
  const fanvueGreen = Color(0xFF00F0C0); // Vibrant Green/Teal
  const fanvueDarkBg = Color(0xFF0F0F0F); // Very Dark Grey/Black
  const fanvueSurface = Color(0xFF1A1A1A); // Slightly lighter for cards
  const textPrimary = Color(0xFFFFFFFF);
  const textSecondary = Color(0xFFB0B0B0);
  const errorColor = Color(0xFFFF4B4B);

  final colorScheme = ColorScheme.dark(
    primary: fanvueGreen,
    onPrimary: Colors.black, // Text on primary should be black for contrast
    secondary: fanvueGreen,
    onSecondary: Colors.black,
    surface: fanvueSurface,
    onSurface: textPrimary,
    background: fanvueDarkBg,
    onBackground: textPrimary,
    error: errorColor,
    onError: Colors.white,
  );

  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: fanvueDarkBg,
    useMaterial3: true,
    fontFamily: 'Inter', // Suggesting a clean font if available, or falls back
    // AppBar Styling
    appBarTheme: const AppBarTheme(
      backgroundColor: fanvueDarkBg,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),

    // Card Styling
    cardTheme: CardThemeData(
      color: fanvueSurface,
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
      ),
    ),

    // Input Decoration (TextFields)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF252525),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: fanvueGreen, width: 2),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: Colors.white38),
    ),

    // ElevatedButton (Primary Actions)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: fanvueGreen,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // TextButton
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: fanvueGreen,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: fanvueGreen,
      foregroundColor: Colors.black,
    ),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF252525),
      selectedColor: fanvueGreen.withOpacity(0.2),
      labelStyle: const TextStyle(color: Colors.white),
      secondaryLabelStyle: const TextStyle(color: fanvueGreen),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
    ),

    // Bottom Navigation Bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: fanvueSurface,
      selectedItemColor: fanvueGreen,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      elevation: 8,
    ),
  );
}
