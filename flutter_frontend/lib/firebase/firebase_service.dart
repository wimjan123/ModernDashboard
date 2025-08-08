import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../firebase_options.dart';
import '../core/exceptions/initialization_exception.dart';
import 'firebase_config_validator.dart';

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();
  static final Logger _logger = Logger();

  FirebaseService._();

  FirebaseApp? _app;
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  User? _currentUser;
  bool _anonymousAuthEnabled = true;

  bool get isInitialized => _app != null;
  bool get isAnonymousAuthEnabled => _anonymousAuthEnabled;
  User? get currentUser => _currentUser;
  FirebaseFirestore get firestore => _firestore!;
  FirebaseAuth get auth => _auth!;

  /// Check network connectivity before Firebase operations
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final dynamic connectivityResult = await Connectivity().checkConnectivity();
      // Handle both single result and list result for different versions
      late List<ConnectivityResult> results;
      if (connectivityResult is List<ConnectivityResult>) {
        results = connectivityResult;
      } else {
        results = [connectivityResult as ConnectivityResult];
      }
      
      final isConnected = results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      _logger.d('Network connectivity check: $isConnected');
      return isConnected;
    } catch (e) {
      _logger.w('Failed to check network connectivity: $e');
      return false;
    }
  }

  /// Validate Firebase configuration options
  void _validateFirebaseOptions(FirebaseOptions options) {
    final platform = defaultTargetPlatform;
    final result = FirebaseConfigValidator.validateFirebaseOptions(options, platform);
    
    if (!result.isValid) {
      _logger.e('Firebase configuration validation failed: ${result.getErrorSummary()}');
      for (final entry in result.fieldErrors.entries) {
        _logger.e('${entry.key}: ${entry.value}');
      }
      throw InitializationException(
        'invalid-config',
        'Firebase configuration validation failed: ${result.errors.join(', ')}',
        result.fieldErrors.toString(),
      );
    }
    
    if (result.hasWarnings) {
      _logger.w('Firebase configuration warnings: ${result.warnings.join(', ')}');
      for (final entry in result.fieldErrors.entries) {
        if (result.warnings.any((w) => w.contains(entry.key))) {
          _logger.w('${entry.key}: ${entry.value}');
        }
      }
    }
    
    _logger.i('Firebase configuration validation passed');
  }
  
  /// Validate platform-specific configuration
  void _validatePlatformSpecificConfig() {
    final platform = defaultTargetPlatform;
    
    if (!FirebaseConfigValidator.isPlatformSupported(platform)) {
      _logger.e('Platform $platform is not supported by Firebase configuration');
      throw InitializationException(
        'unsupported-platform',
        'Platform ${platform.name} is not supported. ${FirebaseConfigValidator.getPlatformConfigRequirements(platform)}',
        'Supported platforms: ${FirebaseConfigValidator.getSupportedPlatforms().join(', ')}',
      );
    }
    
    _logger.d('Platform ${platform.name} is supported by Firebase configuration');
  }


  /// Initialize Firebase with default configuration
  Future<void> initializeFirebase({bool enableAnonymousAuth = true}) async {
    // Validate platform-specific configuration first
    _validatePlatformSpecificConfig();
    
    // Validate Firebase configuration options
    _validateFirebaseOptions(DefaultFirebaseOptions.currentPlatform);
    
    // Check network connectivity
    if (!await _checkNetworkConnectivity()) {
      _logger.e('No internet connection available');
      throw const InitializationException(
        'no-network',
        'No internet connection available',
      );
    }

    try {
      _logger.i('Starting Firebase initialization');
      _anonymousAuthEnabled = enableAnonymousAuth;
      
      // Initialize Firebase app
      _app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize Auth
      _auth = FirebaseAuth.instance;

      // Initialize Firestore with offline persistence
      _firestore = FirebaseFirestore.instance;

      // Enable offline persistence using the new settings approach
      _firestore!.settings = const Settings(persistenceEnabled: true);

      // Listen to authentication state changes
      _auth!.authStateChanges().listen((User? user) {
        _currentUser = user;
      });

      // Sign in anonymously if no user exists and auth is enabled
      if (_auth!.currentUser == null && enableAnonymousAuth) {
        try {
          await signInAnonymously();
        } on FirebaseException catch (e) {
          if (e.code == 'operation-not-allowed') {
            _logger.w('Anonymous authentication is disabled in Firebase console. Continuing without authentication.');
            _anonymousAuthEnabled = false;
          } else {
            rethrow;
          }
        }
      } else if (_auth!.currentUser != null) {
        _currentUser = _auth!.currentUser;
      } else {
        _logger.i('Anonymous authentication disabled, continuing without authentication');
        _anonymousAuthEnabled = false;
      }
      
      _logger.i('Firebase initialization completed successfully');
    } on FirebaseException catch (e) {
      _logger.e('Firebase initialization failed', error: e, stackTrace: StackTrace.current);
      throw InitializationException(
        e.code,
        e.message ?? 'Unknown Firebase error',
        e.toString(),
      );
    } catch (e) {
      _logger.e('Unexpected error during Firebase initialization', error: e, stackTrace: StackTrace.current);
      throw InitializationException(
        'unknown-error',
        'Unexpected initialization error',
        e.toString(),
      );
    }
  }

  /// Sign in anonymously for immediate app access
  Future<User?> signInAnonymously() async {
    try {
      _logger.d('Attempting anonymous sign-in');
      final credential = await _auth!.signInAnonymously();
      _currentUser = credential.user;
      _logger.i('Anonymous sign-in successful');
      return _currentUser;
    } on FirebaseException catch (e) {
      _logger.e('Firebase anonymous sign-in failed', error: e, stackTrace: StackTrace.current);
      throw InitializationException(
        e.code,
        e.message ?? 'Unknown Firebase authentication error',
        e.toString(),
      );
    } catch (e) {
      _logger.e('Unexpected error during anonymous sign-in', error: e, stackTrace: StackTrace.current);
      throw InitializationException(
        'unknown-error',
        'Unexpected authentication error',
        e.toString(),
      );
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _auth!.signOut();
      _currentUser = null;
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  /// Get current user's ID for data scoping
  String? getUserId() {
    return _currentUser?.uid;
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _currentUser != null;
  }

  /// Check if current user is anonymous
  bool isAnonymousUser() {
    return _currentUser?.isAnonymous ?? false;
  }

  /// Retry Firebase initialization with exponential backoff
  Future<void> retryInitialization({int maxRetries = 3, bool enableAnonymousAuth = true}) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        _logger.i('Retry attempt ${retryCount + 1} of $maxRetries');
        await initializeFirebase(enableAnonymousAuth: enableAnonymousAuth);
        _logger.i('Firebase initialization retry successful');
        return;
      } on InitializationException catch (e) {
        // Skip retries for configuration validation errors that won't resolve with retries
        if (e.code == 'invalid-config' || e.code == 'unsupported-platform') {
          _logger.e('Skipping retries for configuration error: ${e.code}');
          rethrow;
        }
        rethrow;
      } catch (e) {
        retryCount++;
        _logger.w('Retry attempt $retryCount failed: $e');
        
        if (retryCount >= maxRetries) {
          _logger.e('All retry attempts exhausted');
          throw InitializationException(
            'retry-failed',
            'Failed to initialize Firebase after $maxRetries attempts',
            e.toString(),
          );
        }

        // Exponential backoff: wait 2^retryCount seconds
        final delay = Duration(seconds: (2 << retryCount));
        _logger.d('Waiting ${delay.inSeconds} seconds before retry');
        await Future.delayed(delay);
      }
    }
  }

  /// Get Firestore collection reference scoped to current user
  CollectionReference getUserCollection(String collection) {
    final userId = getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore!.collection('users').doc(userId).collection(collection);
  }

  /// Get user document reference
  DocumentReference getUserDocument() {
    final userId = getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore!.collection('users').doc(userId);
  }
}
