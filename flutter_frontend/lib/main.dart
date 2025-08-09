import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme/dark_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/migration_screen.dart';
import 'screens/login_screen.dart';
import 'screens/initialization_progress_screen.dart';
import 'firebase/firebase_service.dart';
import 'firebase/migration_service.dart';
import 'firebase/auth_service.dart';
import 'repositories/repository_provider.dart';
import 'core/exceptions/initialization_exception.dart';
import 'core/models/initialization_status.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if we're using mock data (for development/testing)
  const bool useMockData = bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);
  
  if (useMockData) {
    // For mock data, skip Firebase initialization and go straight to offline mode
    await RepositoryProvider.instance.switchToOfflineMode();
    runApp(const ModernDashboardApp(startInitialization: false));
  } else {
    // Initialize Firebase for both web and native platforms
    runApp(const ModernDashboardApp(startInitialization: true));
  }
}

class ModernDashboardApp extends StatefulWidget {
  final bool startInitialization;
  
  const ModernDashboardApp({
    super.key,
    this.startInitialization = true,
  });
  
  @override
  State<ModernDashboardApp> createState() => _ModernDashboardAppState();
}

class _ModernDashboardAppState extends State<ModernDashboardApp> {
  @override
  void initState() {
    super.initState();
    if (widget.startInitialization) {
      _startInitialization();
    }
  }
  
  void _startInitialization() {
    // Start Firebase initialization (non-blocking)
    FirebaseService.instance.initializeFirebase().then((_) {
      // Initialize repositories after Firebase
      return RepositoryProvider.instance.initialize();
    }).catchError((error) {
      debugPrint('Initialization failed: $error');
    });
  }
  
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
        home: widget.startInitialization 
          ? StreamBuilder<InitializationStatus>(
              stream: FirebaseService.instance.initializationStatusStream,
              builder: (context, snapshot) {
                final status = snapshot.data;
                
                
                if (status == null || status.isInProgress) {
                  return InitializationProgressScreen(
                    status: status,
                    onCancel: () {
                      FirebaseService.instance.cancelInitialization();
                    },
                    onSkipToOffline: () async {
                      await RepositoryProvider.instance.switchToOfflineMode();
                    },
                  );
                }

                if (status.phase == InitializationPhase.error) {
                  return InitializationErrorScreen(
                    error: status.error,
                    configValidationFailed: status.error?.code == 'invalid-config' ||
                        status.error?.code == 'unsupported-platform',
                    offlineModeActive: RepositoryProvider.instance.offlineModeActive,
                  );
                }
                
                // Check authentication and migration needs
                return StreamBuilder<User?>(
                  stream: AuthService.instance.authStateChanges,
                  builder: (context, authSnapshot) {
                    // Check if authentication flow is needed
                    if (_shouldShowLoginScreen()) {
                      return const LoginScreen();
                    }
                    
                    // Check for migration needs after authentication
                    return FutureBuilder<bool>(
                      future: _checkMigrationNeeded(),
                      builder: (context, migrationSnapshot) {
                        if (migrationSnapshot.connectionState == ConnectionState.waiting) {
                          return const InitializationProgressScreen(
                            status: null, // Will show default loading
                          );
                        }
                        
                        if (migrationSnapshot.data == true) {
                          return const MigrationScreen();
                        }
                        
                        return const DashboardScreen();
                      },
                    );
                  },
                );
              },
            )
          : const DashboardScreen(), // Skip initialization, go straight to dashboard
        debugShowCheckedModeBanner: false,
      ),
    );
  }
  
  /// Check if the login screen should be shown
  bool _shouldShowLoginScreen() {
    // Skip login screen if in offline mode
    if (RepositoryProvider.instance.offlineModeActive) {
      return false;
    }
    
    // For this implementation, we'll use a simple policy:
    // - Show login screen for users who want to authenticate but aren't
    // - Never force authentication - always allow anonymous/guest access
    // - Users can choose to sign in from the login screen or continue as guest
    
    // For now, this will be false to maintain current behavior
    // The login screen can be accessed through the AccountMenu widget
    return false;
  }

  Future<bool> _checkMigrationNeeded() async {
    try {
      // Skip migration check if in offline mode
      if (RepositoryProvider.instance.offlineModeActive) {
        return false;
      }
      return await MigrationService.instance.isMigrationNeeded();
    } catch (e) {
      debugPrint('Migration check failed: $e');
      return false;
    }
  }
}

class InitializationErrorScreen extends StatefulWidget {
  final InitializationException? error;
  final bool configValidationFailed;
  final bool offlineModeActive;
  
  const InitializationErrorScreen({
    super.key, 
    this.error,
    this.configValidationFailed = false,
    this.offlineModeActive = false,
  });
  
  @override
  State<InitializationErrorScreen> createState() => _InitializationErrorScreenState();
}

class _InitializationErrorScreenState extends State<InitializationErrorScreen> {
  bool _isRetrying = false;
  bool _isSwitchingToOffline = false;
  StreamSubscription<InitializationStatus>? _statusSubscription;

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
  
  void _handleRetry() async {
    if (_isRetrying) return;
    
    setState(() {
      _isRetrying = true;
    });
    
    try {
      // Listen to retry progress
      _statusSubscription = FirebaseService.instance.initializationStatusStream.listen(
        (status) {
          if (status.phase == InitializationPhase.success) {
            // Navigate to dashboard on success
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const DashboardScreen(),
                ),
              );
            }
          } else if (status.phase == InitializationPhase.error) {
            // Error will be handled by the parent StreamBuilder
            setState(() {
              _isRetrying = false;
            });
          }
        },
      );
      
      // Start retry process
      await FirebaseService.instance.retryInitialization();
      await RepositoryProvider.instance.initialize();
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _handleSkipToOffline() async {
    if (_isSwitchingToOffline) return;
    
    setState(() {
      _isSwitchingToOffline = true;
    });
    
    try {
      await RepositoryProvider.instance.switchToOfflineMode();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const DashboardScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSwitchingToOffline = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch to offline mode: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.offlineModeActive ? Icons.cloud_off : Icons.error_outline,
              color: widget.offlineModeActive ? Colors.amber : Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              widget.offlineModeActive
                ? 'Running in Offline Mode'
                : widget.configValidationFailed 
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
              widget.offlineModeActive
                ? 'Limited functionality available.\nTodo, Weather, and News features work offline.\nTry reconnecting when network is available.'
                : widget.configValidationFailed
                  ? 'Please check your Firebase configuration files\nand ensure all values are properly set.'
                  : 'Please check your Firebase configuration\nand try restarting the app.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            if (widget.error != null) ...[
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
                      'Error Code: ${widget.error!.code}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.error!.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.error!.details != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Details: ${widget.error!.details}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (widget.error!.code == 'no-network') ...[
                      const SizedBox(height: 12),
                      const Text(
                        '💡 Check your internet connection and try again',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                        ),
                      ),
                    ] else if (widget.error!.code == 'operation-not-allowed') ...[
                      const SizedBox(height: 12),
                      const Text(
                        '💡 Authentication method may not be enabled in Firebase Console',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                        ),
                      ),
                    ] else if (widget.error!.code == 'invalid-config') ...[
                      const SizedBox(height: 12),
                      const Text(
                        '💡 Check firebase_options.dart for placeholder or invalid values',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                        ),
                      ),
                    ] else if (widget.error!.code == 'unsupported-platform') ...[
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
            if (widget.configValidationFailed) ...[
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
            if (widget.offlineModeActive)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      // Navigate to dashboard in offline mode
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const DashboardScreen(),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Continue Offline'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () async {
                      // Try to reconnect
                      try {
                        await RepositoryProvider.instance.switchToOnlineMode();
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
                              content: Text('Reconnection failed: $e'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Try Reconnect'),
                  ),
                ],
              )
            else if (!widget.configValidationFailed) ...[              
              ElevatedButton(
                onPressed: _isRetrying ? null : _handleRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isRetrying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Retry'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSwitchingToOffline ? null : _handleSkipToOffline,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isSwitchingToOffline
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Skip to Offline Mode'),
              ),
            ] else ...[              
              ElevatedButton(
                onPressed: () {
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
          ],
        ),
      ),
    );
  }
}
