import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/dark_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/migration_screen.dart';
import 'firebase/firebase_service.dart';
import 'firebase/migration_service.dart';
import 'repositories/repository_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase services
  bool initialized = false;
  bool needsMigration = false;
  
  try {
    await FirebaseService.instance.initializeFirebase();
    await RepositoryProvider.instance.initialize();
    
    // Check if migration is needed
    needsMigration = await MigrationService.instance.isMigrationNeeded();
    
    initialized = true;
  } catch (e) {
    // Try to retry initialization
    try {
      await FirebaseService.instance.retryInitialization();
      await RepositoryProvider.instance.initialize();
      
      // Check migration after retry
      needsMigration = await MigrationService.instance.isMigrationNeeded();
      
      initialized = true;
    } catch (retryError) {
      debugPrint('Failed to initialize Firebase after retry: $retryError');
      initialized = false;
    }
  }

  runApp(ModernDashboardApp(
    initialized: initialized,
    needsMigration: needsMigration,
  ));
}

class ModernDashboardApp extends StatelessWidget {
  final bool initialized;
  final bool needsMigration;
  
  const ModernDashboardApp({
    super.key, 
    required this.initialized,
    this.needsMigration = false,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RepositoryProvider>.value(
          value: RepositoryProvider.instance,
        ),
      ],
      child: MaterialApp(
        title: 'Modern Dashboard',
        theme: DarkThemeData.theme,
        home: !initialized
            ? const InitializationErrorScreen()
            : needsMigration
                ? const MigrationScreen()
                : const DashboardScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class InitializationErrorScreen extends StatelessWidget {
  const InitializationErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to Initialize Firebase',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your Firebase configuration\nand try restarting the app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                // Try to reinitialize
                try {
                  await FirebaseService.instance.retryInitialization();
                  await RepositoryProvider.instance.reset();
                  
                  // Restart app (this is a simple approach)
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const DashboardScreen(),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Retry failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
