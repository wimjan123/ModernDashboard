import 'package:flutter/material.dart';

class DarkThemeData {
  // Modern color palette
  static const Color _primaryBlue = Color(0xFF4F46E5);
  static const Color _accentPurple = Color(0xFF7C3AED);
  static const Color _backgroundDark = Color(0xFF0F0F23);
  static const Color _surfaceDark = Color(0xFF1A1B3A);
  static const Color _cardGlass = Color(0xFF232447);
  static const Color _textPrimary = Color(0xFFF8FAFC);
  static const Color _textSecondary = Color(0xFFCBD5E1);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _success = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _error = Color(0xFFEF4444);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    colorScheme: const ColorScheme.dark(
      primary: _primaryBlue,
      secondary: _accentPurple,
      surface: _surfaceDark,
      background: _backgroundDark,
      error: _error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: _textPrimary,
      onBackground: _textPrimary,
      onError: Colors.white,
      outline: Color(0xFF475569),
      outlineVariant: Color(0xFF334155),
    ),
    
    scaffoldBackgroundColor: _backgroundDark,
    cardColor: _cardGlass,
    dividerColor: const Color(0xFF334155),
    
    textTheme: _textTheme,
    elevatedButtonTheme: _elevatedButtonTheme,
    cardTheme: _cardTheme,
    appBarTheme: _appBarTheme,
    iconTheme: const IconThemeData(
      color: _textSecondary,
      size: 20,
    ),
    
    // Enhanced visual density
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      color: _textPrimary,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      color: _textPrimary,
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
    ),
    headlineLarge: TextStyle(
      color: _textPrimary,
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: TextStyle(
      color: _textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    ),
    titleLarge: TextStyle(
      color: _textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      color: _textSecondary,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: TextStyle(
      color: _textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      color: _textSecondary,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      color: _textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    bodySmall: TextStyle(
      color: _textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.3,
    ),
    labelLarge: TextStyle(
      color: _textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: TextStyle(
      color: _textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: TextStyle(
      color: _textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
  );

  static final ElevatedButtonThemeData _elevatedButtonTheme = 
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _primaryBlue,
      foregroundColor: Colors.white,
      elevation: 4,
      shadowColor: _primaryBlue.withOpacity(0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
  );

  static const CardThemeData _cardTheme = CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
    color: _cardGlass,
    shadowColor: Colors.transparent,
  );

  static const AppBarTheme _appBarTheme = AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: _textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(
      color: _textSecondary,
      size: 22,
    ),
  );

  // Custom colors for specific use cases
  static const Color successColor = _success;
  static const Color warningColor = _warning;
  static const Color errorColor = _error;
  static const Color accentColor = _accent;
  static const Color cardColor = _cardGlass;
  static const Color glassBorder = Color(0xFF475569);
  static const Color glassBackground = Color(0x1A4F46E5);
}
