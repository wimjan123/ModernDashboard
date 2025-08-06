import 'package:flutter/material.dart';
import 'core/theme/dark_theme.dart';
import 'screens/dashboard_screen.dart';
import 'services/ffi_bridge.dart';
import 'services/cpp_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize backend engine once at app startup.
  bool inited = false;
  try {
    if (FfiBridge.isSupported) {
      inited = FfiBridge.initializeEngine();
    } else {
      inited = CppBridge.initializeEngine();
    }
  } catch (_) {
    // Fallback to mock bridge if FFI loading fails
    inited = CppBridge.initializeEngine();
  }

  runApp(ModernDashboardApp(initialized: inited));
}

class ModernDashboardApp extends StatelessWidget {
  final bool initialized;
  const ModernDashboardApp({super.key, required this.initialized});

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
