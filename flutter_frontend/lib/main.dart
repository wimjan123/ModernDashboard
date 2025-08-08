import 'package:flutter/foundation.dart';
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
  bool configValidationFailed = false;
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
      // Check if this is a configuration validation error
      if (e.code == 'invalid-config' || e.code == 'unsupported-platform') {
        configValidationFailed = true;
      }
    }
    
    // Skip retry for configuration errors since they won't resolve with retries
    if (!configValidationFailed) {
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
    } else {
      // For config errors, try fallback initialization without anonymous auth
      try {
        await FirebaseService.instance.initializeFirebase(enableAnonymousAuth: false);
        await RepositoryProvider.instance.initialize();
        
        debugPrint('Firebase initialized in fallback mode without anonymous authentication');
        initialized = true;
        initError = null;
      } catch (fallbackError) {
        debugPrint('Fallback initialization also failed: $fallbackError');
        initialized = false;
      }
    }
  }

  runApp(ModernDashboardApp(
    initialized: initialized,
    needsMigration: needsMigration,
    initError: initError,
    configValidationFailed: configValidationFailed,
  ));
}

class ModernDashboardApp extends StatelessWidget {
  final bool initialized;
  final bool needsMigration;
  final InitializationException? initError;
  final bool configValidationFailed;
  
  const ModernDashboardApp({
    super.key, 
    required this.initialized,
    this.needsMigration = false,
    this.initError,
    this.configValidationFailed = false,
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
            ? InitializationErrorScreen(
                error: initError,
                configValidationFailed: configValidationFailed,
              )
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
  final bool configValidationFailed;
  
  const InitializationErrorScreen({
    super.key, 
    this.error,
    this.configValidationFailed = false,
  });

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
            Text(
              configValidationFailed 
                ? 'Firebase Configuration Error'
                : 'Failed to Initialize Firebase',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              configValidationFailed
                ? 'Please check your Firebase configuration files\nand ensure all values are properly set.'
                : 'Please check your Firebase configuration\nand try restarting the app.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            if (error != null) ...[
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
                    if (error!.details != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Details: ${error!.details}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (error!.code == 'no-network') ...[
                      const SizedBox(height: 12),
                      const Text(
                        '💡 Check your internet connection and try again',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                        ),
                      ),
                    ] else if (error!.code == 'operation-not-allowed') ...[
                      const SizedBox(height: 12),
                      const Text(
                        '💡 Authentication method may not be enabled in Firebase Console',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                        ),
                      ),
                    ] else if (error!.code == 'invalid-config') ...[
                      const SizedBox(height: 12),
                      const Text(
                        '💡 Check firebase_options.dart for placeholder or invalid values',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                        ),
                      ),
                    ] else if (error!.code == 'unsupported-platform') ...[
                      const SizedBox(height: 12),
                      const Text(
                        '💡 Run FlutterFire CLI to configure this platform',
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
            if (configValidationFailed) ...[
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuration Diagnostics',
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Platform: ${defaultTargetPlatform.name}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Expected: firebase_options.dart with valid configuration values',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'To fix: Run "flutterfire configure" or check for placeholder values',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (!configValidationFailed)
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
            )
            else
              ElevatedButton(
                onPressed: () {
                  // For config errors, provide guidance instead of retry
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: const Text(
                        'Configuration Help',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'To fix Firebase configuration:\n\n'
                        '1. Run: flutterfire configure\n'
                        '2. Select your Firebase project\n'
                        '3. Choose platforms to support\n'
                        '4. Restart the application\n\n'
                        'Or manually check firebase_options.dart for placeholder values.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Configuration Help'),
              ),
          ],
        ),
      ),
    );
  }
}
