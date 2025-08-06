import 'package:flutter/material.dart';
import 'core/theme/dark_theme.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const ModernDashboardApp());
}

class ModernDashboardApp extends StatelessWidget {
  const ModernDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Modern Dashboard',
      theme: DarkThemeData.theme,
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
