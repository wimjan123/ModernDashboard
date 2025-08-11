import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'core/theme/dark_theme.dart';
import 'core/utils/safe_json_converter.dart';
import 'widgets/common/error_boundary.dart';
import 'screens/dashboard_screen.dart';
import 'screens/migration_screen.dart';
import 'screens/login_screen.dart';
import 'screens/initialization_progress_screen.dart';
import 'screens/splash_screen.dart';
import 'firebase/firebase_service.dart';
import 'firebase/migration_service.dart';
import 'firebase/auth_service.dart';
import 'repositories/repository_provider.dart';
import 'core/exceptions/initialization_exception.dart';
import 'core/models/initialization_status.dart';
import 'core/services/web_compatibility_service.dart';
import 'core/services/web_performance_debugger.dart';
import 'services/rss_service.dart';

Future<void> main() async {
  // Initialize web performance debugging
  WebPerformanceDebugger.instance.initialize();

  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    log(
      'Flutter Error: ${details.exception}',
      error: details.exception,
      stackTrace: kDebugMode ? details.stack : null,
    );
    
    // Initialize WebCompatibilityService if not already done (for web-specific error handling)
    if (kIsWeb) {
      WebCompatibilityService.instance.initialize().catchError((e) {
        log('Failed to initialize WebCompatibilityService: $e');
      });
    }
    
    // Check for web-specific JavaScript interop errors using WebCompatibilityService
    final isWebCompatibilityIssue = kIsWeb 
        ? WebCompatibilityService.instance.isKnownFirebaseInteropIssue(details.exception)
        : SafeJsonConverter.hasWebCompatibilityIssue(details.exception);
        
    if (isWebCompatibilityIssue) {
      log('Detected web compatibility issue - attempting fallback to offline mode');
      
      // Get specific recommendations from WebCompatibilityService
      if (kIsWeb) {
        final recommendations = WebCompatibilityService.instance.getRecommendedFixes();
        if (recommendations.isNotEmpty) {
          log('WebCompatibilityService recommendations: ${recommendations.keys.join(', ')}');
        }
      }
      
      // Try to switch to offline mode automatically
      RepositoryProvider.instance.switchToOfflineMode().catchError((e) {
        log('Failed to auto-switch to offline mode: $e');
      });
    }
    
    // Log error details with context
    _logErrorDetails(details.exception, details.stack, 'Flutter Widget Error');
  };

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      
      // Initialize MCP Toolkit
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit();
      
      // Initialize WebCompatibilityService early for web platform
      if (kIsWeb) {
        await WebCompatibilityService.instance.initialize();
        log('WebCompatibilityService initialized successfully');
      }

      // Check if we're using mock data (for development/testing)
      const bool useMockData = bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);
      
      if (useMockData) {
        // For mock data, skip Firebase initialization and go straight to offline mode
        await RSSService.initialize(); // Initialize RSS service even in offline mode
        await RepositoryProvider.instance.switchToOfflineMode();
        runApp(const ModernDashboardApp(startInitialization: false));
      } else {
        // Initialize Firebase for both web and native platforms
        // For web, we'll handle the Firebase initialization more gracefully
        runApp(const ModernDashboardApp(startInitialization: true));
      }
    },
    (error, stack) {
      // Handle zone errors for MCP server and general app errors
      MCPToolkitBinding.instance.handleZoneError(error, stack);
      
      // Additional error handling for Firebase/Firestore issues
      _logErrorDetails(error, stack, 'Zone Error');
      
      // Check for web-specific errors and attempt recovery using WebCompatibilityService
      if (kIsWeb) {
        final isWebCompatibilityIssue = WebCompatibilityService.instance.isKnownFirebaseInteropIssue(error);
        if (isWebCompatibilityIssue) {
          log('Zone error: Detected web compatibility issue - attempting offline mode switch');
          
          // Get specific recommendations
          final recommendations = WebCompatibilityService.instance.getRecommendedFixes();
          if (recommendations.isNotEmpty) {
            log('WebCompatibilityService zone error recommendations: ${recommendations.keys.join(', ')}');
          }
          
          RepositoryProvider.instance.switchToOfflineMode().catchError((e) {
            log('Failed to switch to offline mode from zone error: $e');
          });
        }
      } else if (SafeJsonConverter.hasWebCompatibilityIssue(error)) {
        // Fallback for non-web platforms
        log('Zone error: Detected compatibility issue - attempting offline mode switch');
        RepositoryProvider.instance.switchToOfflineMode().catchError((e) {
          log('Failed to switch to offline mode from zone error: $e');
        });
      }
    },
  );
}

void _logErrorDetails(dynamic error, StackTrace? stackTrace, String context) {
  final errorString = error.toString();
  
  log('$context: $error', error: error, stackTrace: kDebugMode ? stackTrace : null);
  
  // Platform-specific logging
  if (kIsWeb) {
    log('Platform: Web');
    if (errorString.contains('JavaScriptObject') || errorString.contains('TypeError')) {
      log('Web Error Type: JavaScript Interop Issue');
      log('Suggested Fix: Update Firebase packages or implement web-specific handling');
    }
  } else {
    log('Platform: ${defaultTargetPlatform.name}');
  }
  
  // Error categorization
  if (errorString.contains('firebase') || errorString.contains('firestore')) {
    log('Error Category: Firebase/Firestore');
  } else if (errorString.contains('network') || errorString.contains('socket')) {
    log('Error Category: Network');
  } else if (errorString.contains('permission') || errorString.contains('auth')) {
    log('Error Category: Authentication/Permission');
  } else {
    log('Error Category: General Application');
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
  bool _showSplashScreen = true;
  bool _hasBeenTimeoutOrInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.startInitialization) {
      _startSplashTimeout();
      _startInitialization();
    }
  }
  
  void _startSplashTimeout() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _showSplashScreen && !_hasBeenTimeoutOrInitialized) {
        setState(() {
          _showSplashScreen = false;
          _hasBeenTimeoutOrInitialized = true;
        });
      }
    });
  }
  
  void _startInitialization() {
    // Start Firebase initialization (non-blocking)
    log('Starting Firebase initialization...');
    
    FirebaseService.instance.initializeFirebase().then((_) {
      log('Firebase initialization completed, initializing services...');
      // Initialize RSS service
      return RSSService.initialize();
    }).then((_) {
      log('RSS service initialized, initializing repositories...');
      // Initialize repositories after services
      return RepositoryProvider.instance.initialize();
    }).then((_) {
      log('All initialization completed successfully');
    }).catchError((error) {
      _logErrorDetails(error, StackTrace.current, 'Initialization Error');
      
      // Enhanced error handling with specific recovery strategies
      if (kIsWeb) {
        log('Web platform detected - analyzing error for recovery options');
        
        // Check for JavaScript interop errors
        if (SafeJsonConverter.hasWebCompatibilityIssue(error)) {
          log('Web compatibility issue detected - switching to offline mode automatically');
          RepositoryProvider.instance.switchToOfflineMode().then((_) {
            log('Successfully switched to offline mode due to web compatibility issue');
          }).catchError((offlineError) {
            log('Failed to switch to offline mode: $offlineError');
          });
        } else if (error.toString().contains('firebase') || error.toString().contains('config')) {
          log('Firebase configuration issue on web - attempting offline mode');
          RepositoryProvider.instance.switchToOfflineMode().catchError((offlineError) {
            log('Failed to switch to offline mode due to config issue: $offlineError');
          });
        } else {
          log('General web platform error - attempting offline mode fallback');
          RepositoryProvider.instance.switchToOfflineMode().catchError((offlineError) {
            log('Failed general offline mode fallback: $offlineError');
          });
        }
      } else {
        // Native platform error handling
        log('Native platform error - checking error type');
        final errorString = error.toString().toLowerCase();
        
        if (errorString.contains('network') || errorString.contains('connection')) {
          log('Network error detected - switching to offline mode');
          RepositoryProvider.instance.switchToOfflineMode().catchError((offlineError) {
            log('Failed to switch to offline mode due to network error: $offlineError');
          });
        } else if (errorString.contains('permission') || errorString.contains('auth')) {
          log('Permission/auth error - initialization will retry');
          // Let the user handle auth issues through the UI
        } else {
          log('Unknown native platform error - will show error screen');
          // Let error screen handle the specific error
        }
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      context: 'ModernDashboardApp',
      displayMode: ErrorDisplayMode.detailed,
      child: MultiProvider(
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
                debugPrint('StreamBuilder snapshot: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, data: ${snapshot.data}');
                
                final status = snapshot.data;
                
                // Show SplashScreen when status is null (before initialization starts)
                if (status == null && _showSplashScreen) {
                  return SplashScreen(
                    initializationStream: FirebaseService.instance.initializationStatusStream,
                    onTimeout: () {
                      if (mounted && !_hasBeenTimeoutOrInitialized) {
                        setState(() {
                          _showSplashScreen = false;
                          _hasBeenTimeoutOrInitialized = true;
                        });
                      }
                    },
                  );
                }
                
                // Transition from splash screen when initialization begins
                if (status != null && _showSplashScreen && !_hasBeenTimeoutOrInitialized) {
                  setState(() {
                    _showSplashScreen = false;
                    _hasBeenTimeoutOrInitialized = true;
                  });
                }
                
                // Handle connection states and null status after splash
                if (status == null || (snapshot.hasData && status.isInProgress)) {
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
                  color: Colors.red.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
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
                  color: Colors.blue.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
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
