import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/dark_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/migration_screen.dart';
import 'firebase/firebase_service.dart';
import 'firebase/migration_service.dart';
import 'repositories/repository_provider.dart';
import 'core/exceptions/initialization_exception.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase services
  bool initialized = false;
  bool needsMigration = false;
  InitializationException? initError;
  
  try {
    await FirebaseService.instance.initializeFirebase();
    await RepositoryProvider.instance.initialize();
    
    // Check if migration is needed
    needsMigration = await MigrationService.instance.isMigrationNeeded();
    
    initialized = true;
  } catch (e) {
    if (e is InitializationException) {
      initError = e;
    }
    
    // Try to retry initialization
    try {
      await FirebaseService.instance.retryInitialization();
      await RepositoryProvider.instance.initialize();
      
      // Check migration after retry
      needsMigration = await MigrationService.instance.isMigrationNeeded();
      
      initialized = true;
      initError = null; // Clear error on successful retry
    } catch (retryError) {
      debugPrint('Failed to initialize Firebase after retry: $retryError');
      if (retryError is InitializationException) {
        initError = retryError;
      }
      initialized = false;
    }
  }

  runApp(ModernDashboardApp(
    initialized: initialized,
    needsMigration: needsMigration,
    initError: initError,
  ));
}

class ModernDashboardApp extends StatelessWidget {
  final bool initialized;
  final bool needsMigration;
  final InitializationException? initError;
  
  const ModernDashboardApp({
    super.key, 
    required this.initialized,
    this.needsMigration = false,
    this.initError,
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
            ? InitializationErrorScreen(error: initError)
            : needsMigration
                ? const MigrationScreen()
                : const DashboardScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class InitializationErrorScreen extends StatelessWidget {
  final InitializationException? error;
  
  const InitializationErrorScreen({super.key, this.error});

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
            if (error != null) ..[
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Error Code: ${error!.code}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error!.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    if (error!.details != null) ..[
                      const SizedBox(height: 8),
                      Text(
                        'Details: ${error!.details}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (error!.code == 'no-network') ..[
                      const SizedBox(height: 12),
                      const Text(
                        '💡 Check your internet connection and try again',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                        ),
                      ),
                    ] else if (error!.code == 'operation-not-allowed') ..[
                      const SizedBox(height: 12),
                      const Text(
                        '💡 Authentication method may not be enabled in Firebase Console',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
                } on InitializationException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Retry failed: ${e.message}'),
                        backgroundColor: Colors.red,
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
