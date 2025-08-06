import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/theme/dark_theme.dart';
import 'screens/dashboard_screen.dart';
import 'services/cpp_bridge.dart';

// Conditional imports for FFI (web uses stub)
import 'services/ffi_bridge.dart' if (dart.library.html) 'services/ffi_bridge_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize backend engine once at app startup.
  bool inited = false;
  try {
    if (kIsWeb) {
      // Web platform - use CppBridge mock data
      inited = CppBridge.initializeEngine();
    } else {
      // Native platform - try FFI first, fallback to CppBridge
      try {
        inited = FfiBridge.initializeEngine();
      } catch (_) {
        inited = CppBridge.initializeEngine();
      }
    }
  } catch (_) {
    // Final fallback to mock bridge
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
