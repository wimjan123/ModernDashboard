import 'package:flutter/material.dart';

class DarkThemeData {
  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: const MaterialColor(0xFF0f3460, {
      50: Color(0xFFe3f2fd),
      100: Color(0xFFbbdefb),
      200: Color(0xFF90caf9),
      300: Color(0xFF64b5f6),
      400: Color(0xFF42a5f5),
      500: Color(0xFF0f3460),
      600: Color(0xFF1e88e5),
      700: Color(0xFF1976d2),
      800: Color(0xFF1565c0),
      900: Color(0xFF0d47a1),
    }),
    scaffoldBackgroundColor: const Color(0xFF1a1a2e),
    cardColor: const Color(0xFF16213e),
    dividerColor: Colors.white24,
    textTheme: _textTheme,
    elevatedButtonTheme: _elevatedButtonTheme,
    cardTheme: _cardTheme,
  );

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(color: Colors.white),
    displayMedium: TextStyle(color: Colors.white),
    bodyLarge: TextStyle(color: Colors.white70),
    bodyMedium: TextStyle(color: Colors.white60),
  );

  static final ElevatedButtonThemeData _elevatedButtonTheme = 
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFe94560),
      foregroundColor: Colors.white,
    ),
  );

  static const CardThemeData _cardTheme = CardThemeData(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  );
}
